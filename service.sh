#!/system/bin/sh
# ================================================================
# CPU Screen Off — Service
# Author : Rex Ackermann (github.com/rexackermann)
# Version: 2.0
# https://github.com/rexackermann
# ================================================================
# HOW IT WORKS
#   Listens to PowerManagerService via logcat — a blocking read
#   that consumes zero CPU while idle. Fires on any screen off
#   trigger: power button, double tap, screen timeout, anything.
#
#   On screen OFF: disables cores listed in CORES_OFF (config.sh)
#   On screen ON : restores all those cores
#
# MONITORING
#   tail -f /data/adb/cpu_screenoff.log
#
# CONFIGURATION
#   Edit /data/adb/modules/cpu-screenoff/config.sh then reboot.
# ================================================================

# ----------------------------------------------------------------
# Load config
# ----------------------------------------------------------------
MODDIR="${0%/*}"
. "$MODDIR/config.sh"

# ----------------------------------------------------------------
# Logging
# ----------------------------------------------------------------
log() {
    [ "$LOGGING" = "1" ] || return
    local msg="[$(date '+%H:%M:%S')] $1"
    echo "$msg" >> "$LOG_FILE"
    # Also print to stdout so tee works when run manually in Termux
    echo "$msg"
}

log_section() {
    log "------------------------------------------------"
    log "$1"
    log "------------------------------------------------"
}

# ----------------------------------------------------------------
# Core verification — reads back from kernel, not just sysfs write
# ----------------------------------------------------------------
verify_cores() {
    [ "$VERIFY" = "1" ] || return
    local online
    local count
    online=$(cat /sys/devices/system/cpu/online)
    count=$(grep -c processor /proc/cpuinfo)
    log "  [verify] kernel online range : $online"
    log "  [verify] active processor cnt: $count"
}

# ----------------------------------------------------------------
# Core control
# ----------------------------------------------------------------
cores_off() {
    log_section "SCREEN OFF"
    log "Disabling cores: $CORES_OFF"
    local failed=""
    for cpu in $CORES_OFF; do
        local node="/sys/devices/system/cpu/cpu$cpu/online"
        if [ ! -f "$node" ]; then
            log "  cpu$cpu -> SKIP (no sysfs node)"
            continue
        fi
        echo 0 > "$node"
        local result
        result=$(cat "$node")
        if [ "$result" = "0" ]; then
            log "  cpu$cpu -> offline [OK]"
        else
            log "  cpu$cpu -> FAILED (still $result)"
            failed="$failed cpu$cpu"
        fi
    done
    [ -n "$failed" ] && log "  WARNING: failed to offline:$failed"
    verify_cores
}

cores_on() {
    log_section "SCREEN ON"
    log "Restoring cores: $CORES_OFF"
    local failed=""
    for cpu in $CORES_OFF; do
        local node="/sys/devices/system/cpu/cpu$cpu/online"
        if [ ! -f "$node" ]; then
            log "  cpu$cpu -> SKIP (no sysfs node)"
            continue
        fi
        echo 1 > "$node"
        local result
        result=$(cat "$node")
        if [ "$result" = "1" ]; then
            log "  cpu$cpu -> online [OK]"
        else
            log "  cpu$cpu -> FAILED (still $result)"
            failed="$failed cpu$cpu"
        fi
    done
    [ -n "$failed" ] && log "  WARNING: failed to online:$failed"
    verify_cores
}

# ----------------------------------------------------------------
# Startup
# ----------------------------------------------------------------
[ "$LOGGING" = "1" ] && > "$LOG_FILE"

log_section "CPU Screen Off v2.0 — Starting"
log "Author  : Rex Ackermann (github.com/rexackermann)"
log "Config  :"
log "  CORES_OFF   = $CORES_OFF"
log "  TRIGGER_OFF = $TRIGGER_OFF"
log "  TRIGGER_ON  = $TRIGGER_ON"
log "  BOOT_DELAY  = ${BOOT_DELAY}s"
log "  VERIFY      = $VERIFY"
log "  VERBOSE     = $VERBOSE"

log "Waiting ${BOOT_DELAY}s for system to settle..."
sleep "$BOOT_DELAY"
log "Boot wait done. Listening via logcat..."

# ----------------------------------------------------------------
# Main event loop — zero CPU, purely logcat-driven
# ----------------------------------------------------------------
logcat -s PowerManagerService:I | while IFS= read -r line; do

    # Optional: log every matched line for debugging
    [ "$VERBOSE" = "1" ] && log "[logcat] $line"

    case "$line" in
        *"$TRIGGER_OFF"*)
            cores_off
            ;;
        *"$TRIGGER_ON"*)
            cores_on
            ;;
    esac

done

# Should never reach here
log "ERROR: logcat exited unexpectedly — service stopped"
