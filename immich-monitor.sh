#!/bin/bash

# Immich keeps database disk running 24/7
# This script pauses immich containers ($CONTAINERS) when there is no $PORT activity
# and unpauses Immich when any activity is detected.
# Uses tcpdump and saves logs in $LOGFILE
# can be installed as system service - see immich-monitor.readme and immich-monitor.service

# --- Configuration ---
PORT=2283
INTERFACE="any"
CONTAINERS=("immich_server" "immich_machine_learning" "immich_postgres" "immich_redis") #conatiners to monitor
TIMEOUT=5               # minutes of inactivity to pause or stay active before checking again
LOGFILE="/var/log/immich/immich-monitor.log"
LOG_MAX_SIZE=1          # max log size in MB
LOG_TRIM_PERCENT=50     # % of logfile to trim when size over LOG_MAX_SIZE


# --- Dependency Check ---
        # 1. check if logfile exists
if [ ! -f "$LOGFILE" ]; then
    # Create logfile
    mkdir -p "$(dirname "$LOGFILE")"
    touch "$LOGFILE"
fi
        # 2. check for root
if [[ $EUID -ne 0 ]]; then
    echo "This script must be run as root (use sudo)."
    echo "This script must be run as root (use sudo)." >> "$LOGFILE"
    exit 1
fi
        # 3. check tcpdump installed
if ! command -v tcpdump &> /dev/null; then
    echo "Error: tcpdump is not installed. Install it using: sudo apt install tcpdump"
    echo "Error: tcpdump is not installed. Install it using: sudo apt install tcpdump" >> "$LOGFILE"
    exit 1
fi


# --- Smart Trimming Logging Function ---
log_message() {
    local msg="$*"
    local timestamp
    timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    local formatted_msg="[$timestamp] $msg"

    # 1. Append the new log entry
    echo "$formatted_msg" >> "$LOGFILE"
#   echo "$formatted_msg"  # Mirror to console

    # 2. Check if log file exceeds 1MB and if so trim by LOG_TRIM_PERCENT
    if [ -f "$LOGFILE" ] && [ "$(stat -c%s "$LOGFILE")" -ge $((LOG_MAX_SIZE * 1024 * 1024)) ]; then
        # Take the % of the logfile.
        # 'sed 1d' drops the very first line of that slice, which is usually cut in half.
        tail -c $((LOG_TRIM_PERCENT * LOG_MAX_SIZE * 1024 * 1024 / 100)) "$LOGFILE" | sed '1d' >> "${LOGFILE}.tmp"

        # Overwrite the original log with the trimmed version
        mv "${LOGFILE}.tmp" "$LOGFILE"

        # Insert a marker indicating a trim occurred
        echo >> "$LOGFILE"
        echo "============================================================================================================" >> "$LOGFILE"
        echo "[$timestamp] --- [SYSTEM] Oldest entries purged. Log trimmed to $LOG_TRIM_PERCENT% original size---" >> "$LOGFILE"
        echo "============================================================================================================" >> "$LOGFILE"
        echo >> "$LOGFILE"
        echo "Monitoring port $PORT for Immich traffic. Target: ${CONTAINERS[@]}" >> "$LOGFILE"
        echo >> "$LOGFILE"
    fi
}


# --- Dynamic Status of containers ---
are_all_running() {
    for container in "${CONTAINERS[@]}"; do
        if [ "$(docker inspect -f '{{.State.Paused}}' "$container" 2>/dev/null)" = "true" ]; then
            return 1 # At least one container is down
        fi
    done
    return 0 # All containers are verified running
}




# --- Main Logic (State Machine) ---
echo "============================================================================================================" >> "$LOGFILE"
log_message "Initializing immich-monitor on port $PORT..."
log_message "Managing containers: ${CONTAINERS[@]}"
echo "============================================================================================================" >> "$LOGFILE"

while true; do
    # Assess the actual environment state
    if are_all_running; then
        log_message "📈 All managed containers are running."
    else
        # ------------------------------------------------------------
        # STATE: ENVIRONMENT IS DOWN -> Wait for traffic
        # ------------------------------------------------------------
        log_message "🔍 System paused. Listening for connection attempts..."

        # -c 1 exits instantly when exactly ONE packet hits the port
        tcpdump -c 1 -i "$INTERFACE" "tcp[tcpflags] & (tcp-syn) != 0 and dst port $PORT" >/dev/null 2>&1

        log_message "⚡ Traffic detected! Unpausing containers..."
        # Unpause containers
        docker unpause "${CONTAINERS[@]}" >/dev/null 2>&1
        # Pause checking right after spin-up
        log_message "⏸️ Activity pmonitoring paused for $TIMEOUT minutes..."
        sleep $((TIMEOUT * 60))
    fi

    # ------------------------------------------------------------
    # STATE: ENVIRONMENT IS UP -> Monitor for inactivity
    # ------------------------------------------------------------
    while true; do
        log_message "🕵️ Monitoring for inactivity..."

        # Listen for up to 5 minutes for traffic
        timeout $((TIMEOUT * 60)) tcpdump -c 1 -i "$INTERFACE" "tcp[tcpflags] & (tcp-syn) != 0 and dst port $PORT" >/dev/null 2>&1
        STATUS=$?

        if [ $STATUS -eq 124 ]; then
            # Exit code 124 means 'timeout' killed tcpdump after 5 minutes of dead silence
            log_message "💤 $TIMEOUT minutes of inactivity reached. Pausing containers..."

            # Pause containers (e.g., app stops before database)
            docker pause "${CONTAINERS[@]}" >/dev/null 2>&1
            # Break the inner loop to re-evaluate state at the top of the main loop
            break
        else
            # Exit code 0 means traffic was captured before the timeout
            log_message "🔥 Ongoing activity detected. Pausing checks and extending uptime for $TIMEOUT minutes..."
            sleep $((TIMEOUT * 60))
        fi
    done
done