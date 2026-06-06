#!/bin/bash
#================================================
# backup_manager.sh - Backup and Restore Manager
# Author: haris-mustafa
# Version: 1.0
# Usage: ./backup_manager.sh [--backup|--restore|--list|--verify]
#================================================

# Configuration — change these to match your setup
BACKUP_DIR="/var/backups/devops"      # Where backups are stored
SOURCE_DIR="/opt/projects"             # What we are backing up
RETENTION_DAYS=7                       # Delete backups older than 7 days
LOG_FILE="/var/log/backup_manager.log" # Log file location
DATE=$(date '+%Y%m%d_%H%M%S')         # Timestamp for backup name

# Create backup directory if it doesn't exist
mkdir -p "$BACKUP_DIR"

# Logging function — every action gets logged with timestamp
log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a "$LOG_FILE"
}

# Show help
show_help() {
    echo "Usage: $0 [OPTION]"
    echo "Options:"
    echo "  --backup    Perform full or incremental backup"
    echo "  --restore   Restore from a backup"
    echo "  --list      List all available backups"
    echo "  --verify    Verify backup integrity"
    echo ""
    echo "Examples:"
    echo "  $0 --backup"
    echo "  $0 --list"
    echo "  $0 --restore"
    echo "  $0 --verify"
}

# Full backup — compresses entire source directory
full_backup() {
    log "Starting FULL backup of $SOURCE_DIR"
    BACKUP_FILE="$BACKUP_DIR/full_backup_$DATE.tar.gz"

    # tar = create archive, -czf = compress with gzip
    tar -czf "$BACKUP_FILE" "$SOURCE_DIR" 2>/dev/null

    # $? checks if last command succeeded (0=success)
    if [ $? -eq 0 ]; then
        SIZE=$(du -sh "$BACKUP_FILE" | cut -f1)
        log "SUCCESS: Full backup created: $BACKUP_FILE (Size: $SIZE)"
        # Save timestamp of last full backup for incremental reference
        echo "$DATE" > "$BACKUP_DIR/.last_full_backup"
    else
        log "ERROR: Full backup failed!"
        exit 1
    fi
}

# Incremental backup — only backs up files changed since last backup
incremental_backup() {
    # Check if full backup exists first
    if [ ! -f "$BACKUP_DIR/.last_full_backup" ]; then
        log "No previous full backup found. Running full backup first."
        full_backup
        return
    fi

    LAST_BACKUP=$(cat "$BACKUP_DIR/.last_full_backup")
    log "Starting INCREMENTAL backup — changes since $LAST_BACKUP"
    BACKUP_FILE="$BACKUP_DIR/incremental_backup_$DATE.tar.gz"

    # rsync finds only changed files, tar compresses them
    # --newer-mt = only files newer than the reference file
    tar -czf "$BACKUP_FILE" \
        --newer-mt="$BACKUP_DIR/.last_full_backup" \
        "$SOURCE_DIR" 2>/dev/null

    if [ $? -eq 0 ]; then
        SIZE=$(du -sh "$BACKUP_FILE" | cut -f1)
        log "SUCCESS: Incremental backup created: $BACKUP_FILE (Size: $SIZE)"
    else
        log "ERROR: Incremental backup failed!"
        exit 1
    fi
}

# Main backup function — asks user which type
perform_backup() {
    echo "Backup type:"
    echo "1) Full backup"
    echo "2) Incremental backup"
    read -p "Choose (1 or 2): " choice

    case $choice in
        1) full_backup ;;
        2) incremental_backup ;;
        *) log "Invalid choice"; exit 1 ;;
    esac

    # Cleanup old backups after new one created
    cleanup_old_backups
}

# Delete backups older than RETENTION_DAYS
cleanup_old_backups() {
    log "Cleaning up backups older than $RETENTION_DAYS days"
    # find = search, -mtime = modified time, -delete = remove
    find "$BACKUP_DIR" -name "*.tar.gz" -mtime +$RETENTION_DAYS -delete
    log "Cleanup complete"
}

# List all available backups
list_backups() {
    echo "========================================="
    echo "Available backups in $BACKUP_DIR:"
    echo "========================================="

    # Check if any backups exist
    if ls "$BACKUP_DIR"/*.tar.gz 2>/dev/null; then
        echo ""
        echo "Backup details:"
        # Loop through each backup file and show details
        for backup in "$BACKUP_DIR"/*.tar.gz; do
            SIZE=$(du -sh "$backup" | cut -f1)
            DATE_CREATED=$(stat -c %y "$backup" | cut -d. -f1)
            echo "File: $(basename $backup)"
            echo "Size: $SIZE | Created: $DATE_CREATED"
            echo "-----------------------------------------"
        done
    else
        echo "No backups found."
    fi
}

# Restore from a backup
restore_backup() {
    list_backups
    echo ""
    read -p "Enter backup filename to restore (just the name, not full path): " BACKUP_NAME
    BACKUP_FILE="$BACKUP_DIR/$BACKUP_NAME"

    # Check if file exists
    if [ ! -f "$BACKUP_FILE" ]; then
        log "ERROR: Backup file not found: $BACKUP_FILE"
        exit 1
    fi

    log "Starting restore from $BACKUP_FILE"
    read -p "Restore to directory (default: /): " RESTORE_DIR
    RESTORE_DIR=${RESTORE_DIR:-/}  # Default to / if empty

    # Extract the backup
    tar -xzf "$BACKUP_FILE" -C "$RESTORE_DIR" 2>/dev/null

    if [ $? -eq 0 ]; then
        log "SUCCESS: Restored from $BACKUP_FILE to $RESTORE_DIR"
    else
        log "ERROR: Restore failed!"
        exit 1
    fi
}

# Verify backup integrity — checks if tar file is not corrupted
verify_backup() {
    list_backups
    echo ""
    read -p "Enter backup filename to verify: " BACKUP_NAME
    BACKUP_FILE="$BACKUP_DIR/$BACKUP_NAME"

    if [ ! -f "$BACKUP_FILE" ]; then
        log "ERROR: File not found: $BACKUP_FILE"
        exit 1
    fi

    log "Verifying integrity of $BACKUP_FILE"

    # -t = test archive without extracting
    tar -tzf "$BACKUP_FILE" > /dev/null 2>&1

    if [ $? -eq 0 ]; then
        log "SUCCESS: Backup $BACKUP_NAME is valid and not corrupted"
    else
        log "ERROR: Backup $BACKUP_NAME is CORRUPTED!"
        exit 1
    fi
}

# Parse arguments — $1 is first argument passed to script
case "$1" in
    --backup)  perform_backup ;;
    --restore) restore_backup ;;
    --list)    list_backups ;;
    --verify)  verify_backup ;;
    *)         show_help ;;
esac
