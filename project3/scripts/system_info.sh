#!/bin/bash
#================================================
# system_info.sh - System Information Gatherer
# Author: haris-mustafa
# Version: 1.0
# Usage: ./system_info.sh [-j] [-h] [-v]
#   -j = JSON output
#   -h = help
#   -v = verbose
#================================================

# Colors for pretty output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Help function — shows usage when -h is passed
show_help() {
    echo "Usage: $0 [OPTIONS]"
    echo "Options:"
    echo "  -j    Output in JSON format"
    echo "  -v    Verbose output"
    echo "  -h    Show this help"
    exit 0
}

# Gather all system information into variables
gather_info() {
    # Hostname of the machine
    HOSTNAME=$(hostname)

    # How long system has been running
    UPTIME=$(uptime -p)

    # Linux kernel version
    KERNEL=$(uname -r)

    # Number of CPU cores
    CPU_CORES=$(nproc)

    # CPU model name
    CPU_MODEL=$(cat /proc/cpuinfo | grep "model name" | head -1 | cut -d: -f2 | xargs)

    # Current CPU load average (1min, 5min, 15min)
    CPU_LOAD=$(uptime | awk -F'load average:' '{print $2}' | xargs)

    # Total RAM in MB
    MEM_TOTAL=$(free -m | grep Mem | awk '{print $2}')

    # Used RAM in MB
    MEM_USED=$(free -m | grep Mem | awk '{print $3}')

    # Available RAM in MB
    MEM_AVAILABLE=$(free -m | grep Mem | awk '{print $7}')

    # Swap usage
    SWAP_USED=$(free -m | grep Swap | awk '{print $3}')

    # Disk usage of root partition
    DISK_TOTAL=$(df -h / | tail -1 | awk '{print $2}')
    DISK_USED=$(df -h / | tail -1 | awk '{print $3}')
    DISK_PERCENT=$(df / | tail -1 | awk '{print $5}' | tr -d '%')

    # Network interfaces and their IPs
    NETWORK=$(ip -4 addr show | grep inet | awk '{print $2}' | tr '\n' ' ')

    # Count of running services
    SERVICES_COUNT=$(systemctl list-units --type=service --state=running | grep running | wc -l)

    # Last 10 logged in users
    LAST_USERS=$(last -n 10 | head -10 | awk '{print $1}' | tr '\n' ' ')
}

# Human readable output — normal mode
human_output() {
    echo -e "${GREEN}========================================${NC}"
    echo -e "${GREEN}     SYSTEM INFORMATION REPORT${NC}"
    echo -e "${GREEN}========================================${NC}"
    echo -e "${YELLOW}Date:${NC} $(date '+%Y-%m-%d %H:%M:%S')"
    echo ""
    echo -e "${YELLOW}--- SYSTEM ---${NC}"
    echo "Hostname:     $HOSTNAME"
    echo "Uptime:       $UPTIME"
    echo "Kernel:       $KERNEL"
    echo ""
    echo -e "${YELLOW}--- CPU ---${NC}"
    echo "Model:        $CPU_MODEL"
    echo "Cores:        $CPU_CORES"
    echo "Load Average: $CPU_LOAD"
    echo ""
    echo -e "${YELLOW}--- MEMORY ---${NC}"
    echo "Total:        ${MEM_TOTAL}MB"
    echo "Used:         ${MEM_USED}MB"
    echo "Available:    ${MEM_AVAILABLE}MB"
    echo "Swap Used:    ${SWAP_USED}MB"
    echo ""
    echo -e "${YELLOW}--- DISK ---${NC}"
    echo "Total:        $DISK_TOTAL"
    echo "Used:         $DISK_USED"
    echo "Usage:        ${DISK_PERCENT}%"

    # Alert if disk is getting full
    if [ "$DISK_PERCENT" -gt 80 ]; then
        echo -e "${RED}WARNING: Disk usage above 80%!${NC}"
    fi

    echo ""
    echo -e "${YELLOW}--- NETWORK ---${NC}"
    echo "Interfaces:   $NETWORK"
    echo ""
    echo -e "${YELLOW}--- SERVICES ---${NC}"
    echo "Running:      $SERVICES_COUNT services"
    echo ""
    echo -e "${YELLOW}--- LAST USERS ---${NC}"
    echo "Users:        $LAST_USERS"
    echo -e "${GREEN}========================================${NC}"
}

# JSON output — for when machines read the output
json_output() {
    echo "{"
    echo "  \"timestamp\": \"$(date '+%Y-%m-%d %H:%M:%S')\","
    echo "  \"hostname\": \"$HOSTNAME\","
    echo "  \"uptime\": \"$UPTIME\","
    echo "  \"kernel\": \"$KERNEL\","
    echo "  \"cpu\": {"
    echo "    \"model\": \"$CPU_MODEL\","
    echo "    \"cores\": $CPU_CORES,"
    echo "    \"load_average\": \"$CPU_LOAD\""
    echo "  },"
    echo "  \"memory\": {"
    echo "    \"total_mb\": $MEM_TOTAL,"
    echo "    \"used_mb\": $MEM_USED,"
    echo "    \"available_mb\": $MEM_AVAILABLE,"
    echo "    \"swap_used_mb\": $SWAP_USED"
    echo "  },"
    echo "  \"disk\": {"
    echo "    \"total\": \"$DISK_TOTAL\","
    echo "    \"used\": \"$DISK_USED\","
    echo "    \"percent\": $DISK_PERCENT"
    echo "  },"
    echo "  \"network\": \"$NETWORK\","
    echo "  \"running_services\": $SERVICES_COUNT,"
    echo "  \"last_users\": \"$LAST_USERS\""
    echo "}"
}

# Verbose output — shows extra detail
verbose_output() {
    human_output
    echo ""
    echo -e "${YELLOW}--- VERBOSE: ALL MOUNTED FILESYSTEMS ---${NC}"
    df -h
    echo ""
    echo -e "${YELLOW}--- VERBOSE: ALL NETWORK INTERFACES ---${NC}"
    ip addr
    echo ""
    echo -e "${YELLOW}--- VERBOSE: TOP 5 CPU PROCESSES ---${NC}"
    ps aux --sort=-%cpu | head -6
    echo ""
    echo -e "${YELLOW}--- VERBOSE: TOP 5 MEMORY PROCESSES ---${NC}"
    ps aux --sort=-%mem | head -6
}

# Parse command line arguments
# $@ means all arguments passed to script
JSON=false
VERBOSE=false

while getopts "jvh" opt; do
    case $opt in
        j) JSON=true ;;      # -j flag sets JSON=true
        v) VERBOSE=true ;;   # -v flag sets VERBOSE=true
        h) show_help ;;      # -h shows help and exits
        *) show_help ;;      # anything else shows help
    esac
done

# Main execution — gather info first then output
gather_info

if [ "$JSON" = true ]; then
    json_output
elif [ "$VERBOSE" = true ]; then
    verbose_output
else
    human_output
fi
