#!/bin/bash
#================================================
# service_monitor.sh - Service Health Monitor
# Author: haris-mustafa
# Version: 1.0
# Runs as daemon — monitors services continuously
#================================================

# Configuration
LOG_FILE="/var/log/service_monitor.log"
REPORT_FILE="/var/www/monitor.local/index.html"
CHECK_INTERVAL=30  # Check every 30 seconds
PID_FILE="/var/run/service_monitor.pid"

# Services to monitor — add or remove as needed
SERVICES=("nginx" "ssh" "cron" "fail2ban")

# Ports to check — format: "port description"
PORTS=("22 SSH" "80 HTTP" "443 HTTPS" "53 DNS")

# Websites to check
WEBSITES=("http://192.168.100.60" "https://192.168.100.60")

# Logging function
log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a "$LOG_FILE"
}

# Signal handling — what to do when script receives stop signal
# This runs cleanup before script exits gracefully
cleanup() {
    log "Service monitor stopping gracefully..."
    rm -f "$PID_FILE"  # Remove PID file on exit
    exit 0
}

# trap = catch signals and run function instead of just dying
# SIGTERM = kill command signal
# SIGINT = Ctrl+C signal
trap cleanup SIGTERM SIGINT

# Check if a systemd service is running
check_service() {
    SERVICE=$1
    # is-active returns 0 if running, non-zero if not
    systemctl is-active --quiet "$SERVICE"

    if [ $? -eq 0 ]; then
        log "OK: Service $SERVICE is running"
        echo "ok"
    else
        log "ALERT: Service $SERVICE is DOWN! Attempting restart..."
        # Try to restart automatically
        systemctl restart "$SERVICE" 2>/dev/null

        # Check if restart worked
        if systemctl is-active --quiet "$SERVICE"; then
            log "RECOVERED: Service $SERVICE restarted successfully"
            echo "recovered"
        else
            log "CRITICAL: Service $SERVICE failed to restart!"
            echo "critical"
        fi
    fi
}

# Check if a port is open and listening
check_port() {
    PORT=$1
    DESC=$2
    # ss = socket statistics, checks if port is listening
    ss -tlnp | grep ":$PORT " > /dev/null 2>&1

    if [ $? -eq 0 ]; then
        log "OK: Port $PORT ($DESC) is open"
        echo "ok"
    else
        log "ALERT: Port $PORT ($DESC) is NOT listening!"
        echo "alert"
    fi
}

# Check website response
check_website() {
    URL=$1
    # curl -s = silent, -o = output to /dev/null, -w = write response code
    # --max-time = timeout after 5 seconds
    RESPONSE=$(curl -sk -o /dev/null -w "%{http_code}" --max-time 5 "$URL")

    if [ "$RESPONSE" = "200" ] || [ "$RESPONSE" = "301" ] || [ "$RESPONSE" = "302" ]; then
        log "OK: Website $URL responded with $RESPONSE"
        echo "ok"
    else
        log "ALERT: Website $URL returned $RESPONSE or timed out!"
        echo "alert"
    fi
}

# Generate HTML dashboard — creates a webpage showing all status
generate_dashboard() {
    # Count ok and alert statuses
    OK_COUNT=$1
    ALERT_COUNT=$2

    cat > "$REPORT_FILE" << EOF
<!DOCTYPE html>
<html>
<head>
    <title>DevOps Monitor Dashboard</title>
    <meta http-equiv="refresh" content="30">
    <style>
        body { font-family: Arial; background: #1a1a2e; color: #eee; padding: 20px; }
        h1 { color: #00ff88; }
        .ok { color: #00ff88; }
        .alert { color: #ff4444; }
        .critical { color: #ff0000; font-weight: bold; }
        .recovered { color: #ffaa00; }
        table { width: 100%; border-collapse: collapse; margin-top: 20px; }
        th { background: #16213e; padding: 10px; text-align: left; }
        td { padding: 8px; border-bottom: 1px solid #333; }
        .summary { display: flex; gap: 20px; margin: 20px 0; }
        .box { background: #16213e; padding: 15px; border-radius: 8px; flex: 1; text-align: center; }
        .box h2 { margin: 0; font-size: 36px; }
    </style>
</head>
<body>
    <h1>🖥 DevOps Monitor Dashboard</h1>
    <p>Last updated: $(date '+%Y-%m-%d %H:%M:%S') | Auto-refreshes every 30 seconds</p>

    <div class="summary">
        <div class="box">
            <h2 class="ok">$OK_COUNT</h2>
            <p>Services OK</p>
        </div>
        <div class="box">
            <h2 class="alert">$ALERT_COUNT</h2>
            <p>Alerts</p>
        </div>
    </div>

    <h2>Service Status</h2>
    <table>
        <tr><th>Service</th><th>Status</th><th>Time</th></tr>
EOF

    # Add each service status to table
    for SERVICE in "${SERVICES[@]}"; do
        STATUS=$(systemctl is-active "$SERVICE" 2>/dev/null)
        if [ "$STATUS" = "active" ]; then
            COLOR="ok"
            ICON="✅"
        else
            COLOR="alert"
            ICON="❌"
        fi
        echo "<tr><td>$SERVICE</td><td class='$COLOR'>$ICON $STATUS</td><td>$(date '+%H:%M:%S')</td></tr>" >> "$REPORT_FILE"
    done

    cat >> "$REPORT_FILE" << EOF
    </table>
    <h2>Recent Logs</h2>
    <pre style="background:#16213e; padding:15px; border-radius:8px; overflow:auto; max-height:300px;">
$(tail -20 "$LOG_FILE")
    </pre>
</body>
</html>
EOF
    log "Dashboard updated at $REPORT_FILE"
}

# Save script's PID so you can kill it later with: kill $(cat /var/run/service_monitor.pid)
echo $$ > "$PID_FILE"
log "Service monitor started with PID $$"

# Main loop — runs forever until signal received
while true; do
    log "--- Starting health check cycle ---"

    OK=0
    ALERT=0

    # Check all services
    for SERVICE in "${SERVICES[@]}"; do
        RESULT=$(check_service "$SERVICE")
        if [ "$RESULT" = "ok" ] || [ "$RESULT" = "recovered" ]; then
            OK=$((OK + 1))
        else
            ALERT=$((ALERT + 1))
        fi
    done

    # Check all ports
    for PORT_INFO in "${PORTS[@]}"; do
        PORT=$(echo $PORT_INFO | cut -d' ' -f1)
        DESC=$(echo $PORT_INFO | cut -d' ' -f2)
        RESULT=$(check_port "$PORT" "$DESC")
        if [ "$RESULT" = "ok" ]; then
            OK=$((OK + 1))
        else
            ALERT=$((ALERT + 1))
        fi
    done

    # Check websites
    for URL in "${WEBSITES[@]}"; do
        RESULT=$(check_website "$URL")
        if [ "$RESULT" = "ok" ]; then
            OK=$((OK + 1))
        else
            ALERT=$((ALERT + 1))
        fi
    done

    # Generate fresh dashboard
    generate_dashboard $OK $ALERT

    log "Cycle complete: $OK OK, $ALERT Alerts. Next check in ${CHECK_INTERVAL}s"
    log "---"

    # Wait before next check — during sleep it can receive signals
    sleep $CHECK_INTERVAL
done
