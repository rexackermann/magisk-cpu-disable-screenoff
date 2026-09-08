#!/system/bin/sh
# ═══════════════════════════════════════════════════════════════════
#  CPU Screen Off — service.sh
#  v2.6  |  Rex Ackermann  |  github.com/rexackermann
# ═══════════════════════════════════════════════════════════════════

MODDIR="${0%/*}"
VERSION="2.9"

LOG="/data/adb/cpu_screenoff.log"
STATUS_FILE="/data/adb/cpu_screenoff.status"
BATTERY_LOG="/data/adb/cpu_screenoff_batt.log"
CONF="/data/adb/cpu_screenoff.conf"
PIDFILE="/data/adb/cpu_screenoff.pid"

# ─── Defaults (overridden by conf file) ─────────────────────────────
CORES_OFF="2 3 4 5 6 7"
TRIGGER_OFF="Dozing..."
TRIGGER_ON="Waking up from Dozing"
TRIGGER_PLUG="PLUGGED:true"
TRIGGER_UNPLUG="PLUGGED:false"
BOOT_DELAY=30
SETTLE_DELAY=5
VERIFY=1
VERBOSE=1

load_config() { [ -f "$CONF" ] && . "$CONF"; }
load_config

# SIGHUP = hot-reload config (sent by WebUI on save)
trap 'load_config; log "Config reloaded (SIGHUP)"' HUP

log() { printf '[%s] %s\n' "$(date '+%H:%M:%S')" "$*" >> "$LOG"; }

# ─── Battery logging ─────────────────────────────────────────────────
# Called only at screen on/off events — no extra CPU wake-ups.
# Format: <unix_ts> <event> <pct> <status>
# event: start | off | on
# status: Discharging | Charging | Full | Not charging | Unknown
log_battery() {
    local event="$1" pct status
    pct=$(cat /sys/class/power_supply/battery/capacity 2>/dev/null || echo -1)
    status=$(cat /sys/class/power_supply/battery/status 2>/dev/null || echo Unknown)
    # Strip spaces from status for clean single-word field
    status=$(printf '%s' "$status" | tr -d ' ')
    printf '%s %s %s %s\n' "$(date '+%s')" "$event" "$pct" "$status" >> "$BATTERY_LOG"
}

# ─── Status JSON (single line — ksu.exec returns only last line) ─────
START_TS=$(date '+%s')
STATE="on"

write_status() {
    local now up uptime_fmt states cpu s active total tmp
    now=$(date '+%s')
    up=$(( now - START_TS ))
    uptime_fmt=$(printf '%02d:%02d:%02d' $(( up/3600 )) $(( (up%3600)/60 )) $(( up%60 )))
    states=""; cpu=0
    while [ -d "/sys/devices/system/cpu/cpu${cpu}" ]; do
        if [ "$cpu" = "0" ]; then s=1
        else s=$(cat "/sys/devices/system/cpu/cpu${cpu}/online" 2>/dev/null || echo 0)
        fi
        states="${states}${states:+,}${s}"
        cpu=$(( cpu + 1 ))
    done
    active=$(nproc 2>/dev/null || echo "?")
    total="$cpu"
    tmp="${STATUS_FILE}.tmp"
    printf '{"version":"%s","pid":%s,"state":"%s","last_ts":"%s","uptime":"%s","active_cores":%s,"total_cores":%s,"core_states":[%s],"cores_off":"%s","settle_delay":%s,"boot_delay":%s,"verify":%s,"verbose":%s}\n' \
        "$VERSION" "$$" "$STATE" "$(date '+%H:%M:%S')" "$uptime_fmt" \
        "$active" "$total" "$states" "$CORES_OFF" \
        "$SETTLE_DELAY" "$BOOT_DELAY" "$VERIFY" "$VERBOSE" \
        > "$tmp" && mv "$tmp" "$STATUS_FILE"
}

# ─── Single-instance guard ──────────────────────────────────────────
kill_old_instances() {
    local old
    for pid in $(pgrep -f "cpu-screenoff/service.sh" 2>/dev/null); do
        [ "$pid" = "$$" ] && continue; kill "$pid" 2>/dev/null
    done
    if [ -f "$PIDFILE" ]; then
        old=$(cat "$PIDFILE" 2>/dev/null)
        [ -n "$old" ] && [ "$old" != "$$" ] && kill "$old" 2>/dev/null
    fi
    sleep 1
    echo $$ > "$PIDFILE"
}

# ─── Core control ───────────────────────────────────────────────────
FAILED_CORES=""

set_core() {
    local cpu=$1 state=$2 label=$3
    local node="/sys/devices/system/cpu/cpu${cpu}/online"
    [ -f "$node" ] || { log "  cpu${cpu} -> SKIP (no sysfs node)"; return; }
    echo "$state" > "$node" 2>/dev/null
    local actual; actual=$(cat "$node" 2>/dev/null)
    if [ "$actual" = "$state" ]; then log "  cpu${cpu} -> ${label} [OK]"
    else log "  cpu${cpu} -> FAILED (still $actual)"; FAILED_CORES="$FAILED_CORES cpu${cpu}"
    fi
}

verify_state() {
    log "  [verify] online:$(cat /sys/devices/system/cpu/online 2>/dev/null) active:$(nproc 2>/dev/null)"
}

# ─── Screen off ─────────────────────────────────────────────────────
do_screen_off() {
    load_config
    STATE="off"
    log "------------------------------------------------"
    log "SCREEN OFF"
    log "------------------------------------------------"
    log_battery off
    if [ "${SETTLE_DELAY:-0}" -gt 0 ] 2>/dev/null; then
        log "  Settle: ${SETTLE_DELAY}s"; sleep "$SETTLE_DELAY"
    fi
    FAILED_CORES=""
    log "Disabling cores: $CORES_OFF"
    for cpu in $CORES_OFF; do set_core "$cpu" 0 "offline"; done
    [ -n "$FAILED_CORES" ] && log "  WARNING: failed to offline:$FAILED_CORES"
    [ "$VERIFY" = "1" ] && verify_state
    write_status
}

# ─── Screen on ──────────────────────────────────────────────────────
do_screen_on() {
    load_config
    STATE="on"
    log "------------------------------------------------"
    log "SCREEN ON"
    log "------------------------------------------------"
    log_battery on
    FAILED_CORES=""
    log "Restoring cores: $CORES_OFF"
    for cpu in $CORES_OFF; do set_core "$cpu" 1 "online"; done
    [ -n "$FAILED_CORES" ] && log "  WARNING: failed to online:$FAILED_CORES"
    [ "$VERIFY" = "1" ] && verify_state
    write_status
}

# ─── Cleanup ────────────────────────────────────────────────────────
cleanup() {
    log "Service exiting — restoring all cores"
    for cpu in $CORES_OFF; do
        echo 1 > /sys/devices/system/cpu/cpu${cpu}/online 2>/dev/null
    done
    rm -f "$PIDFILE"; STATE="stopped"; write_status
}
trap cleanup EXIT INT TERM

# ═══════════════════════════════════════════════════════════════════
#  MAIN
# ═══════════════════════════════════════════════════════════════════

# Log rotation
[ -f "$LOG" ]         && [ "$(wc -c < "$LOG"         2>/dev/null||echo 0)" -gt 1048576 ] && mv "$LOG"         "${LOG}.1"
[ -f "$BATTERY_LOG" ] && [ "$(wc -c < "$BATTERY_LOG" 2>/dev/null||echo 0)" -gt 524288  ] && mv "$BATTERY_LOG" "${BATTERY_LOG}.1"

log "================================================"
log "  CPU Screen Off v${VERSION} — Starting"
log "================================================"
log "Running as: $(id)"
log "  CORES_OFF=$CORES_OFF BOOT=${BOOT_DELAY}s SETTLE=${SETTLE_DELAY}s"
log "  VERIFY=$VERIFY VERBOSE=$VERBOSE"
log "================================================"
log "Waiting ${BOOT_DELAY}s..."
sleep "$BOOT_DELAY"

kill_old_instances

POSTBOOT="$MODDIR/postboot.sh"
if [ -f "$POSTBOOT" ] && [ -x "$POSTBOOT" ]; then
    log "--- postboot.sh ---"; sh "$POSTBOOT" >> "$LOG" 2>&1; log "--- postboot done ---"
fi

write_status
log_battery start
log "Entering monitor loop..."

logcat -v time -s PowerManagerService:I | while IFS= read -r line; do
    [ "$VERBOSE" = "1" ] && log "[logcat] $line"
    case "$line" in
        *"$TRIGGER_OFF"*) [ "$STATE" != "off" ] && do_screen_off ;;
        *"$TRIGGER_ON"*)  [ "$STATE" != "on"  ] && do_screen_on  ;;
        *"$TRIGGER_PLUG"*)  log_battery plug   ;;
        *"$TRIGGER_UNPLUG"*) log_battery unplug ;;
    esac
done
