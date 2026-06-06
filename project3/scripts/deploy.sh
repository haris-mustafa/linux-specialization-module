#!/bin/bash
#================================================
# deploy.sh - Deployment Automation Script
# Author: haris-mustafa
# Version: 1.0
# Usage: ./deploy.sh [dev|test|prod] [repo_url]
#================================================

# Configuration
DEPLOY_BASE="/opt/deployments"
BACKUP_BASE="/opt/deployments/backups"
LOG_FILE="/var/log/deploy.log"
TIMESTAMP=$(date '+%Y%m%d_%H%M%S')

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Logging
log() {
    echo -e "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a "$LOG_FILE"
}

# Show help
show_help() {
    echo "Usage: $0 [ENVIRONMENT] [REPO_URL]"
    echo "Environments: dev, test, prod"
    echo ""
    echo "Examples:"
    echo "  $0 dev https://github.com/user/myapp"
    echo "  $0 test https://github.com/user/myapp"
    echo "  $0 prod https://github.com/user/myapp"
    exit 0
}

# Validate arguments
if [ "$1" = "-h" ] || [ "$1" = "--help" ]; then
    show_help
fi

# Environment and repo from arguments
ENVIRONMENT=${1:-dev}    # Default to dev if not specified
REPO_URL=${2:-""}

# Set deploy directory based on environment
case "$ENVIRONMENT" in
    dev)  DEPLOY_DIR="$DEPLOY_BASE/development" ;;
    test) DEPLOY_DIR="$DEPLOY_BASE/testing" ;;
    prod) DEPLOY_DIR="$DEPLOY_BASE/production" ;;
    *)
        log "ERROR: Invalid environment. Use dev, test, or prod"
        exit 1
        ;;
esac

# Create directories
mkdir -p "$DEPLOY_DIR" "$BACKUP_BASE"

# Step 1: Pre-deployment backup
pre_deploy_backup() {
    log "${YELLOW}[STEP 1/5] Pre-deployment backup...${NC}"

    if [ -d "$DEPLOY_DIR" ] && [ "$(ls -A $DEPLOY_DIR)" ]; then
        BACKUP_FILE="$BACKUP_BASE/${ENVIRONMENT}_backup_$TIMESTAMP.tar.gz"
        tar -czf "$BACKUP_FILE" "$DEPLOY_DIR" 2>/dev/null
        log "${GREEN}Backup created: $BACKUP_FILE${NC}"
    else
        log "No existing deployment to backup — fresh deploy"
    fi
}

# Step 2: Pull code from GitHub
pull_code() {
    log "${YELLOW}[STEP 2/5] Pulling latest code...${NC}"

    if [ -z "$REPO_URL" ]; then
        log "No repo URL provided — using existing code"
        return
    fi

    # If repo already cloned — pull latest changes
    if [ -d "$DEPLOY_DIR/.git" ]; then
        cd "$DEPLOY_DIR"
        git pull origin main 2>&1 | tee -a "$LOG_FILE"
        if [ $? -ne 0 ]; then
            log "${RED}ERROR: Git pull failed!${NC}"
            rollback
        fi
    else
        # Fresh clone
        git clone "$REPO_URL" "$DEPLOY_DIR" 2>&1 | tee -a "$LOG_FILE"
        if [ $? -ne 0 ]; then
            log "${RED}ERROR: Git clone failed!${NC}"
            exit 1
        fi
    fi

    log "${GREEN}Code pulled successfully${NC}"
}

# Step 3: Install dependencies (if package.json or requirements.txt exists)
install_dependencies() {
    log "${YELLOW}[STEP 3/5] Installing dependencies...${NC}"
    cd "$DEPLOY_DIR"

    # Node.js project
    if [ -f "package.json" ]; then
        log "Found package.json — running npm install"
        npm install 2>&1 | tee -a "$LOG_FILE"

    # Python project
    elif [ -f "requirements.txt" ]; then
        log "Found requirements.txt — running pip install"
        pip install -r requirements.txt 2>&1 | tee -a "$LOG_FILE"

    else
        log "No dependency file found — skipping"
    fi

    log "${GREEN}Dependencies ready${NC}"
}

# Step 4: Restart service
restart_service() {
    log "${YELLOW}[STEP 4/5] Restarting service...${NC}"

    # For this project we restart nginx as example
    # In real project this would be your app service
    systemctl restart nginx 2>/dev/null

    if [ $? -eq 0 ]; then
        log "${GREEN}Service restarted successfully${NC}"
    else
        log "${RED}ERROR: Service restart failed!${NC}"
        rollback
    fi
}

# Step 5: Health check — verify deployment worked
health_check() {
    log "${YELLOW}[STEP 5/5] Running health checks...${NC}"

    # Wait a moment for service to fully start
    sleep 3

    # Check nginx is running
    systemctl is-active --quiet nginx
    if [ $? -ne 0 ]; then
        log "${RED}HEALTH CHECK FAILED: nginx not running!${NC}"
        rollback
    fi

    # Check port 80 is responding
    curl -s -o /dev/null -w "%{http_code}" http://localhost | grep -q "200\|301\|302"
    if [ $? -ne 0 ]; then
        log "${RED}HEALTH CHECK FAILED: Port 80 not responding!${NC}"
        rollback
    fi

    log "${GREEN}All health checks passed!${NC}"
}

# Rollback — restore previous version if deployment fails
rollback() {
    log "${RED}DEPLOYMENT FAILED — Starting rollback...${NC}"

    # Find most recent backup
    LATEST_BACKUP=$(ls -t "$BACKUP_BASE/${ENVIRONMENT}_backup_"*.tar.gz 2>/dev/null | head -1)

    if [ -z "$LATEST_BACKUP" ]; then
        log "${RED}No backup found — cannot rollback!${NC}"
        exit 1
    fi

    log "Restoring from: $LATEST_BACKUP"
    rm -rf "$DEPLOY_DIR"
    tar -xzf "$LATEST_BACKUP" -C / 2>/dev/null

    # Restart service with old code
    systemctl restart nginx 2>/dev/null

    log "${YELLOW}Rollback complete — previous version restored${NC}"
    exit 1
}

# Generate deployment report
generate_report() {
    REPORT="$LOG_FILE.report_$TIMESTAMP.txt"
    echo "=================================" > "$REPORT"
    echo "DEPLOYMENT REPORT" >> "$REPORT"
    echo "=================================" >> "$REPORT"
    echo "Date:        $(date)" >> "$REPORT"
    echo "Environment: $ENVIRONMENT" >> "$REPORT"
    echo "Repo:        ${REPO_URL:-local}" >> "$REPORT"
    echo "Deploy Dir:  $DEPLOY_DIR" >> "$REPORT"
    echo "Status:      SUCCESS" >> "$REPORT"
    echo "=================================" >> "$REPORT"
    cat "$REPORT"
    log "Report saved: $REPORT"
}

# Main deployment pipeline — runs all steps in order
log "${BLUE}========================================${NC}"
log "${BLUE}Starting deployment to $ENVIRONMENT${NC}"
log "${BLUE}========================================${NC}"

pre_deploy_backup    # Step 1
pull_code           # Step 2
install_dependencies # Step 3
restart_service     # Step 4
health_check        # Step 5
generate_report     # Final report

log "${GREEN}========================================${NC}"
log "${GREEN}DEPLOYMENT SUCCESSFUL!${NC}"
log "${GREEN}========================================${NC}"
