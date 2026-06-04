#!/bin/bash
# System Health Monitor Script
# Author: haris2001
# Runs every 5 minutes via cron
# Logs results to /var/log/system_health.log

LOG="/var/log/system_health.log"
DATE=$(date '+%Y-%m-%d %H:%M:%S')

echo "========================================" >> $LOG
echo "$DATE - System Health Check" >> $LOG
echo "========================================" >> $LOG

# Check disk usage
DISK=$(df / | tail -1 | awk '{print $5}' | tr -d '%')
if [ $DISK -gt 80 ]; then
    echo "$DATE ALERT: Disk usage is ${DISK}% - CRITICAL" >> $LOG
else
    echo "$DATE OK: Disk usage is ${DISK}%" >> $LOG
fi

# Check memory usage
MEM=$(free | grep Mem | awk '{printf "%.0f", $3/$2 * 100}')
if [ $MEM -gt 85 ]; then
    echo "$DATE ALERT: Memory usage is ${MEM}% - CRITICAL" >> $LOG
else
    echo "$DATE OK: Memory usage is ${MEM}%" >> $LOG
fi

# Check CPU load
CPU=$(top -bn1 | grep "load average" | awk '{print $12}' | tr -d ',')
echo "$DATE INFO: CPU load average is ${CPU}" >> $LOG

# Check internet connectivity
ping -c 1 google.com > /dev/null 2>&1
if [ $? -ne 0 ]; then
    echo "$DATE ALERT: No internet connectivity - CRITICAL" >> $LOG
else
    echo "$DATE OK: Internet connectivity working" >> $LOG
fi

echo "" >> $LOG

