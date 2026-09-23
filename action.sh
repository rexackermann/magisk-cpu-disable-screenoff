#!/system/bin/sh
# ═══════════════════════════════════════════════════════════════════
#  CPU Screen Off — action.sh
#  Called when the user taps the Action button in Magisk Manager.
#  Prints a quick status summary to the action output.
# ═══════════════════════════════════════════════════════════════════

STATUS_FILE="/data/adb/cpu_screenoff.status"
PIDFILE="/data/adb/cpu_screenoff.pid"
LOG="/data/adb/cpu_screenoff.log"

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  ⚡ CPU Screen Off v3.6"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

# Service status
if [ -f "$PIDFILE" ]; then
    pid=$(cat "$PIDFILE" 2>/dev/null)
    if kill -0 "$pid" 2>/dev/null; then
        echo "  Service : ● RUNNING (pid=$pid)"
    else
        echo "  Service : ✗ DEAD (stale pid=$pid)"
    fi
else
    echo "  Service : ✗ NOT STARTED"
fi

# Screen state from status JSON (single-line — use sed field extraction, not grep)
if [ -f "$STATUS_FILE" ]; then
    json=$(cat "$STATUS_FILE" 2>/dev/null)
    # Extract fields with sed — works on a single-line JSON regardless of jq availability
    state=$(printf '%s' "$json"   | sed 's/.*"state":"\([^"]*\)".*/\1/')
    uptime=$(printf '%s' "$json"  | sed 's/.*"uptime":"\([^"]*\)".*/\1/')
    active=$(printf '%s' "$json"  | sed 's/.*"active_cores":\([0-9]*\).*/\1/')
    total=$(printf '%s' "$json"   | sed 's/.*"total_cores":\([0-9]*\).*/\1/')
    gov_off=$(printf '%s' "$json" | sed 's/.*"gov_screen_off":"\([^"]*\)".*/\1/')
    freq_cap=$(printf '%s' "$json"| sed 's/.*"freq_cap_enable":\([0-9]*\).*/\1/')
    echo "  Screen  : $state"
    echo "  Cores   : ${active}/${total} active"
    echo "  Uptime  : $uptime"
    [ -n "$gov_off" ] && echo "  Gov(off): ${gov_off:-none}"
    echo "  FreqCap : $([ "$freq_cap" = "1" ] && echo enabled || echo disabled)"
fi

echo ""
echo "  Kernel online map:"
echo "  $(cat /sys/devices/system/cpu/online 2>/dev/null || echo 'unavailable')"

echo ""
echo "  Last 5 log lines:"
tail -n 5 "$LOG" 2>/dev/null | while IFS= read -r line; do
    echo "  $line"
done

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
