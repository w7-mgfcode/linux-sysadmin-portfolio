#!/bin/bash
#===============================================================================
# Backup System - Automated Mailbox and Database Backup
#
# Purpose:
#   Comprehensive backup solution for mail server data including mailboxes,
#   MySQL database, and configurations with retention policy management.
#
# Usage:
#   ./backup.sh --type full             # Full backup (default)
#   ./backup.sh --type incremental      # Incremental backup
#   ./backup.sh --mysql-only            # Database only
#   ./backup.sh --type full --sync      # Full backup + remote sync
#
# Skills Demonstrated:
#   - tar with compression (gzip)
#   - Incremental backup strategy
#   - Retention policy implementation
#   - Checksum verification (sha256sum)
#   - Remote sync capability (rsync)
#   - Backup rotation logic
#   - JSON manifest generation
#
# Author: Linux Sysadmin Portfolio
# License: MIT
#===============================================================================

set -euo pipefail

#===============================================================================
# Configuration
#===============================================================================
readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Source common library
# shellcheck source=./lib/common.sh
source "${SCRIPT_DIR}/lib/common.sh"

readonly BACKUP_DIR="${BACKUP_DIR:-/backups}"
readonly MAILDIR_BASE="${MAILDIR_BASE:-/var/mail/vhosts}"
readonly CONFIG_DIRS="${CONFIG_DIRS:-/etc/postfix /etc/dovecot}"
readonly RETENTION_DAYS="${RETENTION_DAYS:-30}"
readonly KEEP_LAST_FULL="${KEEP_LAST_FULL:-3}"
readonly COMPRESSION="${COMPRESSION:-gzip}"
readonly MYSQL_HOST="${MYSQL_HOST:-mysql}"
readonly MYSQL_DATABASE="${MYSQL_DATABASE:-mailserver}"
readonly MYSQL_USER="${MYSQL_USER:-root}"
readonly MYSQL_PASSWORD="${MYSQL_ROOT_PASSWORD:-}"
readonly REMOTE_SYNC_ENABLED="${REMOTE_SYNC:-false}"
readonly REMOTE_DEST="${REMOTE_DEST:-}"

# Backup metadata
readonly BACKUP_TIMESTAMP=$(timestamp_filename)
readonly BACKUP_DATE=$(date +%Y%m%d)

#===============================================================================
# Backup Functions
#===============================================================================

backup_mysql() {
    log_info "Backing up MySQL database..."

    local output_file="${BACKUP_DIR}/mysql_${BACKUP_TIMESTAMP}.sql.gz"

    docker exec mail-mysql mysqldump \
        -u "$MYSQL_USER" \
        -p"$MYSQL_PASSWORD" \
        --single-transaction \
        --routines \
        --triggers \
        --events \
        "$MYSQL_DATABASE" | gzip > "$output_file"

    log_success "MySQL backup completed: $(basename "$output_file")"
    echo "$output_file"
}

backup_maildirs() {
    local backup_type="${1:-full}"
    log_info "Backing up mailboxes ($backup_type)..."

    local output_file="${BACKUP_DIR}/maildirs_${backup_type}_${BACKUP_TIMESTAMP}.tar.gz"
    local snapshot_file="${BACKUP_DIR}/.maildirs_snapshot.snar"

    if [[ "$backup_type" == "full" ]]; then
        # Full backup - remove old snapshot
        rm -f "$snapshot_file"
    fi

    # Create tar backup
    if [[ -d "$MAILDIR_BASE" ]]; then
        docker exec mail-postfix tar \
            --listed-incremental="$snapshot_file" \
            -czf - "$MAILDIR_BASE" > "$output_file"

        log_success "Maildir backup completed: $(basename "$output_file")"
        echo "$output_file"
    else
        log_warning "Maildir base not found: $MAILDIR_BASE"
        echo ""
    fi
}

backup_configs() {
    log_info "Backing up configurations..."

    local output_file="${BACKUP_DIR}/configs_${BACKUP_TIMESTAMP}.tar.gz"

    # Backup configuration files (run from host)
    tar -czf "$output_file" \
        -C "$(dirname "$SCRIPT_DIR")" \
        postfix dovecot spamassassin 2>/dev/null || true

    log_success "Config backup completed: $(basename "$output_file")"
    echo "$output_file"
}

verify_backup() {
    local backup_file="$1"

    log_info "Verifying backup: $(basename "$backup_file")"

    # Test gzip integrity
    if ! gzip -t "$backup_file" 2>/dev/null; then
        log_error "Backup verification failed: corrupted archive"
        return 1
    fi

    # Calculate checksum
    local checksum
    checksum=$(sha256sum "$backup_file" | awk '{print $1}')

    log_success "Backup verified (SHA256: ${checksum:0:16}...)"
    echo "$checksum"
}

#===============================================================================
# Retention Management
#===============================================================================

cleanup_old_backups() {
    log_info "Cleaning up old backups (retention: $RETENTION_DAYS days)..."

    local deleted_count=0

    # Find and delete backups older than retention period
    while IFS= read -r old_backup; do
        log_info "Deleting old backup: $(basename "$old_backup")"
        rm -f "$old_backup"
        ((deleted_count++))
    done < <(find "$BACKUP_DIR" -name "*.tar.gz" -o -name "*.sql.gz" -mtime +"$RETENTION_DAYS" -type f 2>/dev/null)

    # Keep last N full backups regardless of age
    local full_backups
    full_backups=$(find "$BACKUP_DIR" -name "maildirs_full_*.tar.gz" -type f 2>/dev/null | sort -r)

    local keep_count=0
    while IFS= read -r backup; do
        ((keep_count++))
        if ((keep_count > KEEP_LAST_FULL)); then
            log_info "Removing old full backup: $(basename "$backup")"
            rm -f "$backup"
            ((deleted_count++))
        fi
    done <<< "$full_backups"

    log_success "Cleanup completed: $deleted_count files deleted"
}

#===============================================================================
# Remote Sync
#===============================================================================

sync_to_remote() {
    if [[ "$REMOTE_SYNC_ENABLED" != "true" ]]; then
        log_info "Remote sync disabled"
        return 0
    fi

    if [[ -z "$REMOTE_DEST" ]]; then
        log_warning "Remote destination not configured"
        return 1
    fi

    log_info "Syncing to remote: $REMOTE_DEST"

    # Use rsync for efficient synchronization
    if command -v rsync &>/dev/null; then
        rsync -avz --progress --delete \
            "$BACKUP_DIR/" \
            "$REMOTE_DEST" || {
            log_error "Remote sync failed"
            return 1
        }

        log_success "Remote sync completed"
    else
        log_warning "rsync not available, skipping remote sync"
    fi
}

#===============================================================================
# Manifest Generation
#===============================================================================

generate_manifest() {
    local manifest_file="${BACKUP_DIR}/backup_manifest_${BACKUP_DATE}.json"
    local total_size=0
    local backup_count=0

    log_info "Generating backup manifest..."

    # Start JSON
    cat > "$manifest_file" << EOF
{
    "timestamp": "$(timestamp_iso)",
    "hostname": "$(hostname)",
    "retention_days": $RETENTION_DAYS,
    "backups": [
EOF

    # List all backups from today
    local first=true
    while IFS= read -r backup_file; do
        if [[ "$first" == "true" ]]; then
            first=false
        else
            echo "," >> "$manifest_file"
        fi

        local size
        size=$(stat -f%z "$backup_file" 2>/dev/null || stat -c%s "$backup_file" 2>/dev/null)
        total_size=$((total_size + size))
        ((backup_count++))

        local checksum
        checksum=$(sha256sum "$backup_file" | awk '{print $1}')

        cat >> "$manifest_file" << EOF
        {
            "filename": "$(basename "$backup_file")",
            "size_bytes": $size,
            "size_mb": $(echo "scale=2; $size / 1048576" | bc),
            "checksum": "$checksum",
            "type": "$(echo "$backup_file" | grep -oP '(mysql|maildirs|configs)')"
        }
EOF
    done < <(find "$BACKUP_DIR" -name "*_${BACKUP_TIMESTAMP}*" -type f)

    # Close JSON
    cat >> "$manifest_file" << EOF

    ],
    "summary": {
        "total_backups": $backup_count,
        "total_size_mb": $(echo "scale=2; $total_size / 1048576" | bc)
    }
}
EOF

    log_success "Manifest generated: $(basename "$manifest_file")"
}

#===============================================================================
# Main Execution
#===============================================================================

main() {
    local backup_type="full"
    local mysql_only=false
    local sync=false

    # Parse arguments
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --type)
                backup_type="$2"
                shift 2
                ;;
            --mysql-only)
                mysql_only=true
                shift
                ;;
            --sync)
                sync=true
                shift
                ;;
            *)
                log_error "Unknown option: $1"
                exit 1
                ;;
        esac
    done

    log_info "=== Mail Server Backup ==="
    log_info "Type: $backup_type"
    log_info "Timestamp: $BACKUP_TIMESTAMP"

    # Create backup directory
    ensure_directory "$BACKUP_DIR"

    # Perform backups
    if [[ "$mysql_only" == "true" ]]; then
        backup_mysql
    else
        local mysql_backup
        local maildir_backup
        local config_backup

        mysql_backup=$(backup_mysql)
        maildir_backup=$(backup_maildirs "$backup_type")
        config_backup=$(backup_configs)

        # Verify backups
        [[ -n "$mysql_backup" ]] && verify_backup "$mysql_backup"
        [[ -n "$maildir_backup" ]] && verify_backup "$maildir_backup"
        [[ -n "$config_backup" ]] && verify_backup "$config_backup"

        # Generate manifest
        generate_manifest
    fi

    # Cleanup old backups
    cleanup_old_backups

    # Remote sync if requested
    if [[ "$sync" == "true" ]]; then
        sync_to_remote
    fi

    log_success "=== Backup Complete ==="
    log_info "Backup location: $BACKUP_DIR"
}

# Execute main
main "$@"
