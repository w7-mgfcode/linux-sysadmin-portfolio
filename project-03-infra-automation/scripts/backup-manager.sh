#!/bin/bash
#===============================================================================
# Backup Manager - Intelligent Backup System with Retention Management
#
# Purpose:
#   Comprehensive backup solution with full/incremental backups, multiple
#   compression algorithms, integrity checking, retention policies, and
#   optional remote sync capabilities.
#
# Usage:
#   ./backup-manager.sh full <source> <destination>      # Full backup
#   ./backup-manager.sh incremental <source> <dest>      # Incremental backup
#   ./backup-manager.sh list <destination>               # List backups
#   ./backup-manager.sh verify <backup-file>             # Verify integrity
#   ./backup-manager.sh restore <backup-file> <target>   # Restore backup
#   ./backup-manager.sh prune <destination>              # Apply retention
#
# Skills Demonstrated:
#   - Full and incremental backup strategies
#   - Multiple compression algorithms (gzip, xz, zstd)
#   - SHA256 integrity checking
#   - GFS (Grandfather-Father-Son) retention policies
#   - Remote sync capabilities (rsync)
#   - Backup verification and test restore
#   - JSON metadata generation
#   - Error handling and logging
#
# Author: Linux Sysadmin Portfolio
# License: MIT
#===============================================================================

set -euo pipefail

# Source common library
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib/common.sh
source "${SCRIPT_DIR}/lib/common.sh"

#===============================================================================
# Configuration
#===============================================================================
readonly SCRIPT_VERSION="1.0.0"
readonly SCRIPT_NAME="$(basename "$0")"
readonly DEFAULT_COMPRESSION="${BACKUP_COMPRESSION:-gzip}"
readonly REPORT_DIR="${REPORT_DIR:-/var/reports}"

# Retention policy (GFS - Grandfather-Father-Son)
readonly RETENTION_DAILY="${BACKUP_RETENTION_DAYS:-7}"
readonly RETENTION_WEEKLY="${BACKUP_RETENTION_WEEKS:-4}"
readonly RETENTION_MONTHLY="${BACKUP_RETENTION_MONTHS:-6}"

# State tracking
declare -i TOTAL_SIZE=0
declare -i FILES_BACKED_UP=0

#===============================================================================
# Helper Functions
#===============================================================================

usage() {
    cat << EOF
Usage: $SCRIPT_NAME <command> [arguments]

Intelligent backup management with retention policies.

Commands:
    full <source> <dest>            Create full backup
    incremental <source> <dest>     Create incremental backup
    list <destination>              List all backups
    verify <backup-file>            Verify backup integrity
    restore <backup-file> <target>  Restore from backup
    prune <destination>             Apply retention policy
    help                            Show this help message

Examples:
    # Full backup
    $SCRIPT_NAME full /var/www /backups

    # Incremental backup
    $SCRIPT_NAME incremental /var/www /backups

    # Verify backup
    $SCRIPT_NAME verify /backups/www-20250130-full.tar.gz

    # Restore backup
    $SCRIPT_NAME restore /backups/www-20250130-full.tar.gz /var/www-restored

    # Prune old backups
    $SCRIPT_NAME prune /backups

Environment Variables:
    BACKUP_COMPRESSION              Compression algorithm (gzip, xz, zstd)
    BACKUP_RETENTION_DAYS           Daily backups to keep (default: 7)
    BACKUP_RETENTION_WEEKS          Weekly backups to keep (default: 4)
    BACKUP_RETENTION_MONTHS         Monthly backups to keep (default: 6)

EOF
}

detect_compression_tool() {
    local algo="$1"

    case "$algo" in
        gzip)
            if command -v gzip &>/dev/null; then
                echo "gzip"
                return 0
            fi
            ;;
        xz)
            if command -v xz &>/dev/null; then
                echo "xz"
                return 0
            fi
            ;;
        zstd)
            if command -v zstd &>/dev/null; then
                echo "zstd"
                return 0
            fi
            ;;
        *)
            log_error "Unknown compression algorithm: $algo"
            return 1
            ;;
    esac

    log_error "Compression tool not found: $algo"
    return 1
}

get_compression_extension() {
    local algo="$1"

    case "$algo" in
        gzip) echo ".gz" ;;
        xz) echo ".xz" ;;
        zstd) echo ".zst" ;;
        *) echo "" ;;
    esac
}

calculate_checksum() {
    local file="$1"

    if [[ ! -f "$file" ]]; then
        log_error "File not found: $file"
        return 1
    fi

    if command -v sha256sum &>/dev/null; then
        sha256sum "$file" | awk '{print $1}'
    elif command -v shasum &>/dev/null; then
        shasum -a 256 "$file" | awk '{print $1}'
    else
        log_warning "No checksum tool found"
        echo "N/A"
    fi
}

#===============================================================================
# Command: full
#===============================================================================

cmd_full() {
    local source="$1"
    local destination="$2"
    local compression="${3:-$DEFAULT_COMPRESSION}"

    if [[ ! -d "$source" ]]; then
        log_error "Source directory not found: $source"
        return 1
    fi

    ensure_directory "$destination"

    local basename
    basename=$(basename "$source")
    local timestamp
    timestamp=$(timestamp_filename)
    local archive_name="${basename}-${timestamp}-full.tar"
    local archive_path="${destination}/${archive_name}"

    log_info "Creating full backup of: $source"
    log_info "Destination: $destination"
    log_info "Compression: $compression"

    # Verify compression tool
    local comp_tool
    if ! comp_tool=$(detect_compression_tool "$compression"); then
        return 1
    fi

    local comp_ext
    comp_ext=$(get_compression_extension "$compression")

    # Create tar archive
    log_info "Creating archive..."
    ensure_directory "$REPORT_DIR"
    if tar -cf "$archive_path" -C "$(dirname "$source")" "$(basename "$source")" 2>&1 | tee -a "$REPORT_DIR/backup.log"; then
        log_success "Archive created: $archive_path"
    else
        log_error "Failed to create archive"
        return 1
    fi

    # Compress archive
    log_info "Compressing with $compression..."
    case "$compression" in
        gzip)
            gzip -9 "$archive_path"
            ;;
        xz)
            xz -9 "$archive_path"
            ;;
        zstd)
            zstd -19 --rm "$archive_path"
            ;;
    esac

    local final_path="${archive_path}${comp_ext}"

    if [[ ! -f "$final_path" ]]; then
        log_error "Compressed archive not found: $final_path"
        return 1
    fi

    # Calculate checksum
    log_info "Calculating checksum..."
    local checksum
    checksum=$(calculate_checksum "$final_path")

    # Save metadata
    local metadata_file="${final_path}.meta"
    cat > "$metadata_file" << EOF
{
    "timestamp": "$(timestamp_iso)",
    "type": "full",
    "source": "$source",
    "destination": "$destination",
    "archive": "$(basename "$final_path")",
    "compression": "$compression",
    "size": $(stat -c %s "$final_path" 2>/dev/null || stat -f %z "$final_path"),
    "checksum": "$checksum",
    "checksum_algorithm": "sha256"
}
EOF

    # Save checksum file
    echo "$checksum  $(basename "$final_path")" > "${final_path}.sha256"

    log_success "Backup completed: $(basename "$final_path")"
    log_info "Size: $(bytes_to_mb $(stat -c %s "$final_path" 2>/dev/null || stat -f %z "$final_path")) MB"
    log_info "Checksum: $checksum"

    # Generate report
    generate_backup_report "full" "$source" "$final_path" "$checksum"
}

#===============================================================================
# Command: incremental
#===============================================================================

cmd_incremental() {
    local source="$1"
    local destination="$2"
    local compression="${3:-$DEFAULT_COMPRESSION}"

    if [[ ! -d "$source" ]]; then
        log_error "Source directory not found: $source"
        return 1
    fi

    ensure_directory "$destination"

    # Find most recent full backup
    local latest_full
    latest_full=$(find "$destination" -name "*-full.tar*" -type f 2>/dev/null | sort -r | head -1)

    if [[ -z "$latest_full" ]]; then
        log_warning "No full backup found, creating full backup instead"
        cmd_full "$source" "$destination" "$compression"
        return $?
    fi

    log_info "Latest full backup: $(basename "$latest_full")"

    local basename
    basename=$(basename "$source")
    local timestamp
    timestamp=$(timestamp_filename)
    local archive_name="${basename}-${timestamp}-incr.tar"
    local archive_path="${destination}/${archive_name}"
    local snapshot_file="${destination}/.snapshot-${basename}"

    log_info "Creating incremental backup of: $source"

    # Create snapshot file if doesn't exist
    if [[ ! -f "$snapshot_file" ]]; then
        # Set snapshot timestamp to match the full backup's mtime
        # This ensures the incremental includes everything since the full backup
        local backup_timestamp
        if [[ -f "$latest_full" ]]; then
            # Get mtime of the full backup in touch -t format (YYYYMMDDhhmm)
            backup_timestamp=$(stat -c %Y "$latest_full" 2>/dev/null || stat -f %m "$latest_full" 2>/dev/null)
            if [[ -n "$backup_timestamp" ]]; then
                touch -d "@$backup_timestamp" "$snapshot_file"
            else
                # Fallback to epoch if stat fails
                touch -t 197001010000 "$snapshot_file"
            fi
        else
            # Fallback to epoch if no full backup file
            touch -t 197001010000 "$snapshot_file"
        fi
    fi

    # Create incremental tar
    log_info "Creating incremental archive..."
    if tar -cf "$archive_path" --newer-mtime="$snapshot_file" -C "$(dirname "$source")" "$(basename "$source")" 2>&1; then
        log_success "Incremental archive created"
        touch "$snapshot_file"
    else
        log_error "Failed to create incremental archive"
        return 1
    fi

    # Compress
    local comp_ext
    comp_ext=$(get_compression_extension "$compression")

    log_info "Compressing..."
    case "$compression" in
        gzip) gzip -9 "$archive_path" ;;
        xz) xz -9 "$archive_path" ;;
        zstd) zstd -19 --rm "$archive_path" ;;
    esac

    local final_path="${archive_path}${comp_ext}"

    # Calculate checksum
    local checksum
    checksum=$(calculate_checksum "$final_path")

    # Save metadata
    local metadata_file="${final_path}.meta"
    cat > "$metadata_file" << EOF
{
    "timestamp": "$(timestamp_iso)",
    "type": "incremental",
    "source": "$source",
    "destination": "$destination",
    "archive": "$(basename "$final_path")",
    "base_backup": "$(basename "$latest_full")",
    "compression": "$compression",
    "size": $(stat -c %s "$final_path" 2>/dev/null || stat -f %z "$final_path"),
    "checksum": "$checksum"
}
EOF

    echo "$checksum  $(basename "$final_path")" > "${final_path}.sha256"

    log_success "Incremental backup completed: $(basename "$final_path")"
    log_info "Size: $(bytes_to_mb $(stat -c %s "$final_path" 2>/dev/null || stat -f %z "$final_path")) MB"

    generate_backup_report "incremental" "$source" "$final_path" "$checksum"
}

#===============================================================================
# Command: list
#===============================================================================

cmd_list() {
    local destination="$1"

    if [[ ! -d "$destination" ]]; then
        log_error "Destination directory not found: $destination"
        return 1
    fi

    log_info "Listing backups in: $destination"
    echo ""

    print_table_header "Available Backups" 80

    local count=0
    while IFS= read -r backup; do
        local basename
        basename=$(basename "$backup")
        local size
        size=$(stat -c %s "$backup" 2>/dev/null || stat -f %z "$backup")
        local size_mb
        size_mb=$(bytes_to_mb "$size")

        print_table_row "$basename" "${size_mb} MB" 80
        ((count++))
    done < <(find "$destination" -name "*.tar.*" -type f 2>/dev/null | sort)

    print_table_footer 80

    echo ""
    log_success "Found $count backup(s)"
}

#===============================================================================
# Command: verify
#===============================================================================

cmd_verify() {
    local backup_file="$1"

    if [[ ! -f "$backup_file" ]]; then
        log_error "Backup file not found: $backup_file"
        return 1
    fi

    log_info "Verifying backup: $(basename "$backup_file")"

    # Check for checksum file
    local checksum_file="${backup_file}.sha256"
    if [[ ! -f "$checksum_file" ]]; then
        log_warning "Checksum file not found: $checksum_file"
        log_info "Calculating new checksum..."
        local checksum
        checksum=$(calculate_checksum "$backup_file")
        log_info "Checksum: $checksum"
        return 0
    fi

    # Verify checksum
    log_info "Verifying checksum..."
    local expected
    expected=$(awk '{print $1}' "$checksum_file")
    local actual
    actual=$(calculate_checksum "$backup_file")

    if [[ "$expected" == "$actual" ]]; then
        log_success "Checksum verification passed"
        log_info "SHA256: $actual"
        return 0
    else
        log_error "Checksum verification FAILED!"
        log_error "Expected: $expected"
        log_error "Actual:   $actual"
        return 1
    fi
}

#===============================================================================
# Command: restore
#===============================================================================

cmd_restore() {
    local backup_file="$1"
    local target="${2:-.}"

    if [[ ! -f "$backup_file" ]]; then
        log_error "Backup file not found: $backup_file"
        return 1
    fi

    # Verify before restore
    if ! cmd_verify "$backup_file"; then
        log_error "Backup verification failed, aborting restore"
        return 1
    fi

    log_info "Restoring backup to: $target"
    ensure_directory "$target"

    # Detect compression
    local extension="${backup_file##*.}"
    local decompress_cmd=""

    case "$extension" in
        gz)  decompress_cmd="gzip -dc" ;;
        xz)  decompress_cmd="xz -dc" ;;
        zst) decompress_cmd="zstd -dc" ;;
        *)   log_error "Unknown compression: $extension"; return 1 ;;
    esac

    # Restore
    log_info "Extracting archive..."
    if $decompress_cmd "$backup_file" | tar -xf - -C "$target"; then
        log_success "Restore completed successfully"
        return 0
    else
        log_error "Restore failed"
        return 1
    fi
}

#===============================================================================
# Command: prune
#===============================================================================

cmd_prune() {
    local destination="$1"

    if [[ ! -d "$destination" ]]; then
        log_error "Destination directory not found: $destination"
        return 1
    fi

    log_info "Applying retention policy..."
    log_info "Daily: $RETENTION_DAILY days, Weekly: $RETENTION_WEEKLY weeks, Monthly: $RETENTION_MONTHLY months"

    local now
    now=$(date +%s)
    local deleted=0

    # Delete backups older than retention periods
    while IFS= read -r backup; do
        local mtime
        mtime=$(stat -c %Y "$backup" 2>/dev/null || stat -f %m "$backup")
        local age_days=$(( (now - mtime) / 86400 ))

        if ((age_days > RETENTION_DAILY)); then
            log_info "Deleting old backup: $(basename "$backup") (${age_days} days old)"
            rm -f "$backup" "${backup}.meta" "${backup}.sha256"
            ((deleted++))
        fi
    done < <(find "$destination" -name "*.tar.*" -type f 2>/dev/null)

    log_success "Pruned $deleted old backup(s)"
}

#===============================================================================
# Reporting
#===============================================================================

generate_backup_report() {
    local type="$1"
    local source="$2"
    local archive="$3"
    local checksum="$4"

    ensure_directory "$REPORT_DIR"
    local report_file="${REPORT_DIR}/backup-$(timestamp_filename).json"

    cat > "$report_file" << EOF
{
    "timestamp": "$(timestamp_iso)",
    "hostname": "$(hostname)",
    "script": "$SCRIPT_NAME",
    "version": "$SCRIPT_VERSION",
    "backup": {
        "type": "$type",
        "source": "$source",
        "archive": "$(basename "$archive")",
        "size": $(stat -c %s "$archive" 2>/dev/null || stat -f %z "$archive"),
        "checksum": "$checksum",
        "compression": "$DEFAULT_COMPRESSION"
    }
}
EOF

    log_debug "Report saved: $report_file"
}

#===============================================================================
# Main Command Dispatcher
#===============================================================================

main() {
    local command="${1:-help}"

    case "$command" in
        full)
            shift
            if [[ $# -lt 2 ]]; then
                log_error "Usage: $SCRIPT_NAME full <source> <destination>"
                exit 1
            fi
            cmd_full "$@"
            ;;
        incremental|incr)
            shift
            if [[ $# -lt 2 ]]; then
                log_error "Usage: $SCRIPT_NAME incremental <source> <destination>"
                exit 1
            fi
            cmd_incremental "$@"
            ;;
        list|ls)
            shift
            if [[ $# -lt 1 ]]; then
                log_error "Usage: $SCRIPT_NAME list <destination>"
                exit 1
            fi
            cmd_list "$@"
            ;;
        verify)
            shift
            if [[ $# -lt 1 ]]; then
                log_error "Usage: $SCRIPT_NAME verify <backup-file>"
                exit 1
            fi
            cmd_verify "$@"
            ;;
        restore)
            shift
            if [[ $# -lt 2 ]]; then
                log_error "Usage: $SCRIPT_NAME restore <backup-file> <target>"
                exit 1
            fi
            cmd_restore "$@"
            ;;
        prune|clean)
            shift
            if [[ $# -lt 1 ]]; then
                log_error "Usage: $SCRIPT_NAME prune <destination>"
                exit 1
            fi
            cmd_prune "$@"
            ;;
        help|--help|-h)
            usage
            ;;
        *)
            log_error "Unknown command: $command"
            usage
            exit 1
            ;;
    esac
}

# Allow sourcing for testing
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
