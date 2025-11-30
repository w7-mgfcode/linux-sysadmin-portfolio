#!/bin/bash
#===============================================================================
# MySQL Backup Script - Automated Database Backup with Retention
#
# Purpose:
#   Creates compressed MySQL backups with retention policy, integrity checking,
#   and manifest generation.
#
# Skills Demonstrated:
#   - MySQL backup procedures
#   - File compression (gzip)
#   - Retention policy implementation
#   - Integrity verification (checksums)
#   - JSON manifest generation
#
# Author: Linux Sysadmin Portfolio
# License: MIT
#===============================================================================

set -euo pipefail

#===============================================================================
# Configuration
#===============================================================================

readonly SCRIPT_NAME=$(basename "$0")
readonly SCRIPT_VERSION="1.0.0"

# MySQL Configuration
readonly MYSQL_HOST="${MYSQL_HOST:-mysql}"
readonly MYSQL_DATABASE="${MYSQL_DATABASE:-lampdb}"
readonly MYSQL_USER="${MYSQL_USER:-root}"
readonly MYSQL_PASSWORD="${MYSQL_PASSWORD:-}"

# Backup Configuration
readonly BACKUP_DIR="${BACKUP_DIR:-/backups}"
readonly RETENTION_DAYS="${RETENTION_DAYS:-7}"
readonly TIMESTAMP=$(date +%Y%m%d_%H%M%S)
readonly BACKUP_FILE="${BACKUP_DIR}/${MYSQL_DATABASE}_${TIMESTAMP}.sql.gz"

#===============================================================================
# Colors & Logging
#===============================================================================

declare -A COLORS=(
    [RED]='\033[0;31m'
    [GREEN]='\033[0;32m'
    [YELLOW]='\033[1;33m'
    [BLUE]='\033[0;34m'
    [NC]='\033[0m'
)

log() {
    local level=$1
    shift
    echo -e "${COLORS[$level]}[$(date '+%Y-%m-%d %H:%M:%S')] [$level] $*${COLORS[NC]}"
}

#===============================================================================
# Backup Functions
#===============================================================================

check_mysql_connection() {
    log "BLUE" "Checking MySQL connection..."

    if mysqladmin ping -h"$MYSQL_HOST" -u"$MYSQL_USER" -p"$MYSQL_PASSWORD" >/dev/null 2>&1; then
        log "GREEN" "MySQL connection successful"
        return 0
    else
        log "RED" "Failed to connect to MySQL"
        return 1
    fi
}

create_backup() {
    log "BLUE" "Creating backup: $BACKUP_FILE"

    # Create backup directory
    mkdir -p "$BACKUP_DIR"

    # Perform backup
    if mysqldump -h"$MYSQL_HOST" \
        -u"$MYSQL_USER" \
        -p"$MYSQL_PASSWORD" \
        --single-transaction \
        --routines \
        --triggers \
        "$MYSQL_DATABASE" | gzip > "$BACKUP_FILE"; then

        log "GREEN" "Backup created successfully"
        return 0
    else
        log "RED" "Backup failed"
        return 1
    fi
}

verify_backup() {
    log "BLUE" "Verifying backup integrity..."

    if [[ ! -f "$BACKUP_FILE" ]]; then
        log "RED" "Backup file not found"
        return 1
    fi

    # Check if gzip file is valid
    if gzip -t "$BACKUP_FILE" 2>/dev/null; then
        log "GREEN" "Backup file integrity verified"

        # Calculate checksum
        local checksum
        checksum=$(sha256sum "$BACKUP_FILE" | awk '{print $1}')
        log "BLUE" "Checksum: $checksum"

        # Get file size
        local size
        size=$(du -h "$BACKUP_FILE" | awk '{print $1}')
        log "BLUE" "Size: $size"

        return 0
    else
        log "RED" "Backup file is corrupted"
        return 1
    fi
}

cleanup_old_backups() {
    log "BLUE" "Cleaning up backups older than $RETENTION_DAYS days..."

    local deleted=0
    while IFS= read -r -d '' file; do
        rm -f "$file"
        log "YELLOW" "Deleted: $(basename "$file")"
        ((deleted++))
    done < <(find "$BACKUP_DIR" -name "*.sql.gz" -type f -mtime +${RETENTION_DAYS} -print0)

    if [[ $deleted -gt 0 ]]; then
        log "GREEN" "Deleted $deleted old backup(s)"
    else
        log "GREEN" "No old backups to delete"
    fi
}

generate_manifest() {
    local manifest_file="${BACKUP_DIR}/backup_manifest.json"

    log "BLUE" "Generating backup manifest..."

    # Get all backups
    local backups
    backups=$(find "$BACKUP_DIR" -name "*.sql.gz" -type f -printf '%T@ %s %p\n' | sort -rn | \
        awk '{
            timestamp=strftime("%Y-%m-%dT%H:%M:%S", $1);
            size=$2;
            file=$3;
            gsub(/.*\//, "", file);
            printf "        {\n";
            printf "            \"filename\": \"%s\",\n", file;
            printf "            \"timestamp\": \"%s\",\n", timestamp;
            printf "            \"size_bytes\": %s\n", size;
            printf "        },\n";
        }' | sed '$ s/,$//')

    cat > "$manifest_file" << EOF
{
    "generated_at": "$(date -Iseconds)",
    "retention_days": $RETENTION_DAYS,
    "backup_directory": "$BACKUP_DIR",
    "backups": [
$backups
    ]
}
EOF

    log "GREEN" "Manifest generated: $manifest_file"
}

#===============================================================================
# Main Execution
#===============================================================================

main() {
    log "GREEN" "========================================="
    log "GREEN" "MySQL Backup Script v$SCRIPT_VERSION"
    log "GREEN" "========================================="

    # Check MySQL connection
    if ! check_mysql_connection; then
        exit 1
    fi

    # Create backup
    if ! create_backup; then
        exit 1
    fi

    # Verify backup
    if ! verify_backup; then
        exit 1
    fi

    # Cleanup old backups
    cleanup_old_backups

    # Generate manifest
    generate_manifest

    log "GREEN" "========================================="
    log "GREEN" "Backup completed successfully!"
    log "GREEN" "========================================="
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
