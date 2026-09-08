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
echo "  ⚡ CPU Screen Off v2.9"
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

# Screen state from status JSON
if [ -f "$STATUS_FILE" ]; then
    state=$(grep '"state"' "$STATUS_FILE" | tr -d ' ",' | cut -d: -f2)
    uptime=$(grep '"uptime"' "$STATUS_FILE" | tr -d ' ",' | cut -d: -f2-)
    active=$(grep '"active_cores"' "$STATUS_FILE" | tr -d ' ,' | cut -d: -f2)
    total=$(grep '"total_cores"' "$STATUS_FILE" | tr -d ' ,' | cut -d: -f2)
    echo "  Screen  : $state"
    echo "  Cores   : ${active}/${total} active"
    echo "  Uptime  : $uptime"
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
