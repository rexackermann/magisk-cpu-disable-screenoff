#!/system/bin/sh
# ═══════════════════════════════════════════════════════════════════
#  CPU Screen Off — service.sh
#  v3.6  |  Rex Ackermann  |  github.com/rexackermann
# ═══════════════════════════════════════════════════════════════════

MODDIR="${0%/*}"
VERSION="3.6"

LOG="/data/adb/cpu_screenoff.log"
STATUS_FILE="/data/adb/cpu_screenoff.status"
BATTERY_LOG="/data/adb/cpu_screenoff_batt.log"
CONF="/data/adb/cpu_screenoff.conf"
PIDFILE="/data/adb/cpu_screenoff.pid"
LOGCAT_FIFO="/data/adb/cpu_screenoff.fifo"
LOGCAT_PID=""

# ─── Defaults ────────────────────────────────────────────────────────
CORES_OFF="2 3 4 5 6 7"
SETTLE_DELAY=5
BOOT_DELAY=30
VERIFY=1
VERBOSE=1
TRIGGER_OFF="Sleeping (uid"
TRIGGER_ON="Waking up from Asleep"
# Note: MTK devices may not emit these via PowerManagerService.
# Charger state is still captured at screen on/off via log_battery.
TRIGGER_PLUG="PLUGGED:true"
TRIGGER_UNPLUG="PLUGGED:false"

# Global governors (empty = don't touch)
GOV_SCREEN_OFF=""
GOV_SCREEN_ON=""

# Per-core governor overrides — fallback to global if empty
GOV_SCREEN_OFF_CPU0=""; GOV_SCREEN_OFF_CPU1=""; GOV_SCREEN_OFF_CPU2=""
GOV_SCREEN_OFF_CPU3=""; GOV_SCREEN_OFF_CPU4=""; GOV_SCREEN_OFF_CPU5=""
GOV_SCREEN_OFF_CPU6=""; GOV_SCREEN_OFF_CPU7=""

GOV_SCREEN_ON_CPU0=""; GOV_SCREEN_ON_CPU1=""; GOV_SCREEN_ON_CPU2=""
GOV_SCREEN_ON_CPU3=""; GOV_SCREEN_ON_CPU4=""; GOV_SCREEN_ON_CPU5=""
GOV_SCREEN_ON_CPU6=""; GOV_SCREEN_ON_CPU7=""

# Per-core screen-off freq caps (Hz, empty = uncapped)
FREQ_CAP_ENABLE=0
FREQ_CAP_CPU0=""; FREQ_CAP_CPU1=""; FREQ_CAP_CPU2=""
FREQ_CAP_CPU3=""; FREQ_CAP_CPU4=""; FREQ_CAP_CPU5=""
FREQ_CAP_CPU6=""; FREQ_CAP_CPU7=""

# Per-core screen-on freq targets (Hz, empty = restore hardware max)
FREQ_ON_CPU0=""; FREQ_ON_CPU1=""; FREQ_ON_CPU2=""
FREQ_ON_CPU3=""; FREQ_ON_CPU4=""; FREQ_ON_CPU5=""
FREQ_ON_CPU6=""; FREQ_ON_CPU7=""

load_config() { [ -f "$CONF" ] && . "$CONF"; }
load_config
CONF_MTIME=$(stat -c '%Y' "$CONF" 2>/dev/null || echo 0)

# Check if conf changed since last load — called at the top of each event handler
reload_config_if_changed() {
    local mtime
    mtime=$(stat -c '%Y' "$CONF" 2>/dev/null || echo 0)
    if [ "$mtime" != "$CONF_MTIME" ]; then
        CONF_MTIME="$mtime"
        load_config
        log "Config reloaded (mtime changed)"
    fi
}

log() { printf '[%s] %s\n' "$(date '+%H:%M:%S')" "$*" >> "$LOG"; }

# ─── Battery logging ──────────────────────────────────────────────
log_battery() {
    local event="$1" pct status
    pct=$(cat /sys/class/power_supply/battery/capacity 2>/dev/null || echo -1)
    status=$(cat /sys/class/power_supply/battery/status 2>/dev/null | tr -d ' ' || echo Unknown)
    printf '%s %s %s %s\n' "$(date '+%s')" "$event" "$pct" "$status" >> "$BATTERY_LOG"
}

# ─── Status JSON ──────────────────────────────────────────────────
START_TS=$(date '+%s')
STATE="on"

write_status() {
    local now up uptime_fmt states cpu s active total tmp
    now=$(date '+%s'); up=$(( now - START_TS ))
    uptime_fmt=$(printf '%02d:%02d:%02d' $(( up/3600 )) $(( (up%3600)/60 )) $(( up%60 )))
    states=""; cpu=0
    while [ -d "/sys/devices/system/cpu/cpu${cpu}" ]; do
        if [ "$cpu" = "0" ]; then s=1
        else s=$(cat "/sys/devices/system/cpu/cpu${cpu}/online" 2>/dev/null || echo 0); fi
        states="${states}${states:+,}${s}"; cpu=$(( cpu + 1 ))
    done
    active=$(nproc 2>/dev/null || echo "?"); total="$cpu"
    tmp="${STATUS_FILE}.tmp"
    printf '{"version":"%s","pid":%s,"state":"%s","last_ts":"%s","uptime":"%s","active_cores":%s,"total_cores":%s,"core_states":[%s],"cores_off":"%s","settle_delay":%s,"boot_delay":%s,"verify":%s,"verbose":%s,"gov_screen_off":"%s","gov_screen_on":"%s","freq_cap_enable":%s}\n' \
        "$VERSION" "$$" "$STATE" "$(date '+%H:%M:%S')" "$uptime_fmt" \
        "$active" "$total" "$states" "$CORES_OFF" \
        "${SETTLE_DELAY:-5}" "${BOOT_DELAY:-30}" "${VERIFY:-1}" "${VERBOSE:-1}" \
        "${GOV_SCREEN_OFF:-}" "${GOV_SCREEN_ON:-}" "${FREQ_CAP_ENABLE:-0}" \
        > "$tmp" && mv "$tmp" "$STATUS_FILE"
}

# ─── Single-instance guard ────────────────────────────────────────
kill_old_instances() {
    local old
    for pid in $(pgrep -f "cpu-screenoff/service.sh" 2>/dev/null); do
        [ "$pid" = "$$" ] && continue; kill "$pid" 2>/dev/null
    done
    if [ -f "$PIDFILE" ]; then
        old=$(cat "$PIDFILE" 2>/dev/null)
        [ -n "$old" ] && [ "$old" != "$$" ] && kill "$old" 2>/dev/null
    fi
    echo $$ > "$PIDFILE"
}

# ─── Governor control ─────────────────────────────────────────────
# apply_governors <phase>  where phase = off | on
apply_governors() {
    local phase="$1" cpu node gov global_gov
    [ "$phase" = "off" ] && global_gov="$GOV_SCREEN_OFF" || global_gov="$GOV_SCREEN_ON"
    for cpu in 0 1 2 3 4 5 6 7; do
        [ "$(cat /sys/devices/system/cpu/cpu${cpu}/online 2>/dev/null || echo 1)" = "0" ] && continue
        node="/sys/devices/system/cpu/cpu${cpu}/cpufreq/scaling_governor"
        [ -f "$node" ] || continue
        if [ "$phase" = "off" ]; then
            eval "gov=\$GOV_SCREEN_OFF_CPU${cpu}"
        else
            eval "gov=\$GOV_SCREEN_ON_CPU${cpu}"
        fi
        [ -z "$gov" ] && gov="$global_gov"
        [ -z "$gov" ] && continue
        echo "$gov" > "$node" 2>/dev/null
        log "  cpu${cpu} gov(${phase}) -> ${gov} [$(cat $node 2>/dev/null)]"
    done
}

# ─── Frequency control ────────────────────────────────────────────
apply_freq_caps() {
    [ "$FREQ_CAP_ENABLE" = "1" ] || return
    local cpu cap max_node
    for cpu in 0 1 2 3 4 5 6 7; do
        eval "cap=\$FREQ_CAP_CPU${cpu}"
        [ -z "$cap" ] && continue
        max_node="/sys/devices/system/cpu/cpu${cpu}/cpufreq/scaling_max_freq"
        [ -f "$max_node" ] || continue
        cat "$max_node" 2>/dev/null > "/data/adb/cpu_screenoff_orig_freq${cpu}"
        echo "$cap" > "$max_node" 2>/dev/null
        log "  cpu${cpu} freq(off) -> ${cap}Hz [$(cat $max_node 2>/dev/null)]"
    done
}

apply_freq_on() {
    local cpu max_node target
    for cpu in 0 1 2 3 4 5 6 7; do
        [ "$(cat /sys/devices/system/cpu/cpu${cpu}/online 2>/dev/null || echo 1)" = "0" ] && continue
        max_node="/sys/devices/system/cpu/cpu${cpu}/cpufreq/scaling_max_freq"
        [ -f "$max_node" ] || continue
        eval "target=\$FREQ_ON_CPU${cpu}"
        if [ -z "$target" ]; then
            # No explicit target — restore hardware max
            target=$(cat "/sys/devices/system/cpu/cpu${cpu}/cpufreq/cpuinfo_max_freq" 2>/dev/null)
            [ -z "$target" ] && target=$(cat "/data/adb/cpu_screenoff_orig_freq${cpu}" 2>/dev/null)
        fi
        [ -z "$target" ] && continue
        echo "$target" > "$max_node" 2>/dev/null
        log "  cpu${cpu} freq(on) -> ${target}Hz [$(cat $max_node 2>/dev/null)]"
    done
}

# ─── Core control ─────────────────────────────────────────────────
FAILED_CORES=""

set_core() {
    local cpu=$1 state=$2 label=$3
    local node="/sys/devices/system/cpu/cpu${cpu}/online"
    [ -f "$node" ] || { log "  cpu${cpu} -> SKIP (no sysfs node)"; return; }
    echo "$state" > "$node" 2>/dev/null
    local actual; actual=$(cat "$node" 2>/dev/null)
    if [ "$actual" = "$state" ]; then log "  cpu${cpu} -> ${label} [OK]"
    else log "  cpu${cpu} -> FAILED (still $actual)"; FAILED_CORES="$FAILED_CORES cpu${cpu}"; fi
}

verify_state() {
    log "  [verify] online:$(cat /sys/devices/system/cpu/online 2>/dev/null) active:$(nproc 2>/dev/null)"
}

# ─── Screen off ───────────────────────────────────────────────────
do_screen_off() {
    reload_config_if_changed
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
    apply_governors off
    apply_freq_caps
    [ "$VERIFY" = "1" ] && verify_state
    write_status
}

# ─── Screen on ────────────────────────────────────────────────────
do_screen_on() {
    reload_config_if_changed
    STATE="on"
    log "------------------------------------------------"
    log "SCREEN ON"
    log "------------------------------------------------"
    log_battery on
    FAILED_CORES=""
    log "Restoring cores: $CORES_OFF"
    for cpu in $CORES_OFF; do set_core "$cpu" 1 "online"; done
    [ -n "$FAILED_CORES" ] && log "  WARNING: failed to online:$FAILED_CORES"
    apply_freq_on
    apply_governors on
    [ "$VERIFY" = "1" ] && verify_state
    write_status
}

# ─── Cleanup ──────────────────────────────────────────────────────
cleanup() {
    log "Service exiting — restoring all cores"
    kill "$LOGCAT_PID" 2>/dev/null
    rm -f "$LOGCAT_FIFO"
    for cpu in $CORES_OFF; do
        echo 1 > /sys/devices/system/cpu/cpu${cpu}/online 2>/dev/null
    done
    rm -f "$PIDFILE"; STATE="stopped"; write_status
}
trap cleanup EXIT INT TERM

# No heartbeat — WebUI polls status file directly. write_status runs on
# startup and on every screen/charger event only.

# ═══════════════════════════════════════════════════════════════════
#  MAIN
# ═══════════════════════════════════════════════════════════════════

[ -f "$LOG" ]         && [ "$(wc -c < "$LOG"         2>/dev/null||echo 0)" -gt 1048576 ] && mv "$LOG"         "${LOG}.1"
[ -f "$BATTERY_LOG" ] && [ "$(wc -c < "$BATTERY_LOG" 2>/dev/null||echo 0)" -gt 524288  ] && mv "$BATTERY_LOG" "${BATTERY_LOG}.1"

log "================================================"
log "  CPU Screen Off v${VERSION} — Starting"
log "================================================"
log "Running as: $(id)"
log "  CORES_OFF=$CORES_OFF SETTLE=${SETTLE_DELAY}s"
log "  GOV_OFF=${GOV_SCREEN_OFF:-none} GOV_ON=${GOV_SCREEN_ON:-none}"
log "  FREQ_CAP_ENABLE=$FREQ_CAP_ENABLE VERIFY=$VERIFY VERBOSE=$VERBOSE"
log "================================================"

# Boot delay: only on actual system boot, skip on manual restarts
uptime_s=$(awk '{print int($1)}' /proc/uptime 2>/dev/null || echo 9999)
if [ "${BOOT_DELAY:-0}" -gt 0 ] && [ "$uptime_s" -lt 180 ]; then
    log "Boot detected (uptime ${uptime_s}s) — waiting ${BOOT_DELAY}s..."
    sleep "$BOOT_DELAY"
else
    log "Manual restart or uptime ${uptime_s}s — skipping boot delay"
fi

kill_old_instances

POSTBOOT="$MODDIR/postboot.sh"
if [ -f "$POSTBOOT" ] && [ -x "$POSTBOOT" ]; then
    log "--- postboot.sh ---"; sh "$POSTBOOT" >> "$LOG" 2>&1; log "--- postboot done ---"
fi

write_status
log_battery start
log "Entering monitor loop..."

rm -f "$LOGCAT_FIFO"; mkfifo "$LOGCAT_FIFO"
logcat -v time -s PowerManagerService:I > "$LOGCAT_FIFO" &
LOGCAT_PID=$!
while IFS= read -r line; do
    [ "$VERBOSE" = "1" ] && log "[logcat] $line"
    case "$line" in
        *"$TRIGGER_OFF"*)    [ "$STATE" != "off" ] && do_screen_off ;;
        *"$TRIGGER_ON"*)     [ "$STATE" != "on"  ] && do_screen_on  ;;
        *"$TRIGGER_PLUG"*)   log_battery plug   ;;
        *"$TRIGGER_UNPLUG"*) log_battery unplug ;;
    esac
done < "$LOGCAT_FIFO"
