# ================================================================
# CPU Screen Off — Configuration  v3.0
# Rex Ackermann · github.com/rexackermann/magisk-cpu-disable-screenoff
# ================================================================
# Hot-apply without reboot:
#   kill -HUP $(cat /data/adb/cpu_screenoff.pid)
# Or just use the WebUI — it does this automatically on Save.
# Log: /data/adb/cpu_screenoff.log
# ================================================================

# ----------------------------------------------------------------
# CORE PARKING
# ----------------------------------------------------------------
# Space-separated CPU indices to take OFFLINE when screen turns off.
# CPU 0 can never be disabled (kernel enforced).
# Check your layout: for c in /sys/devices/system/cpu/cpu[0-9];
#   do echo "$(basename $c): $(cat $c/cpufreq/cpuinfo_max_freq 2>/dev/null)"; done
#
CORES_OFF="2 3 4 5 6 7"

# Seconds to wait after screen-off before parking cores.
# Prevents a race with mtkpower/perfd writing 1 back on sleep.
SETTLE_DELAY=5

# Seconds to wait after SYSTEM BOOT before starting.
# Automatically skipped on manual service restarts (uptime > 180s).
BOOT_DELAY=30

# ----------------------------------------------------------------
# SCREEN-OFF GOVERNORS  (applied after cores are parked)
# ----------------------------------------------------------------
# Global fallback — applied to all online cores if per-core is empty.
# Empty string = don't touch the governor.
# Available governors: cat /sys/devices/system/cpu/cpu0/cpufreq/scaling_available_governors
#
# Note: service.sh defaults to empty (don't touch). This config overrides that
# to schedutil on new installs — a safe baseline on most kernels.
GOV_SCREEN_OFF="schedutil"

# Per-core overrides — takes priority over GOV_SCREEN_OFF.
# Only matters for cores that stay ONLINE (not in CORES_OFF).
# Empty = use GOV_SCREEN_OFF global value.
GOV_SCREEN_OFF_CPU0=""
GOV_SCREEN_OFF_CPU1=""
GOV_SCREEN_OFF_CPU2=""   # parked — ignored
GOV_SCREEN_OFF_CPU3=""   # parked — ignored
GOV_SCREEN_OFF_CPU4=""   # parked — ignored
GOV_SCREEN_OFF_CPU5=""   # parked — ignored
GOV_SCREEN_OFF_CPU6=""   # parked — ignored
GOV_SCREEN_OFF_CPU7=""   # parked — ignored

# ----------------------------------------------------------------
# SCREEN-ON GOVERNORS  (applied after cores are restored)
# ----------------------------------------------------------------
# Global fallback — applied to all online cores on wake.
# Empty = don't touch the governor.
#
# Note: service.sh defaults to empty. Config overrides to schedutil on new installs.
GOV_SCREEN_ON="schedutil"

# Per-core overrides — takes priority over GOV_SCREEN_ON.
# Empty = use GOV_SCREEN_ON global value.
GOV_SCREEN_ON_CPU0=""
GOV_SCREEN_ON_CPU1=""
GOV_SCREEN_ON_CPU2=""
GOV_SCREEN_ON_CPU3=""
GOV_SCREEN_ON_CPU4=""
GOV_SCREEN_ON_CPU5=""
GOV_SCREEN_ON_CPU6=""
GOV_SCREEN_ON_CPU7=""

# ----------------------------------------------------------------
# SCREEN-OFF FREQUENCY CAPS  (applied after parking + governor)
# ----------------------------------------------------------------
# Set # Note: service.sh defaults to 0 (disabled). This config enables caps on new installs
# based on test results: 4 cores / 500MHz → ~120mW average. Adjust or disable as needed.
FREQ_CAP_ENABLE=1 to activate. Per-core Hz caps.
# Empty = uncapped. Only affects online (non-parked) cores.
# Available freqs: cat /sys/devices/system/cpu/cpu0/cpufreq/scaling_available_frequencies
#
# Test results on this device:
#   Config F: 4 cores / 500MHz → avg load 16.88 ~120mW  ← WINNER
#   Config E: 6 cores / 500MHz → avg load 24.22 ~180mW
#
# Note: service.sh defaults to 0 (disabled). This config enables caps on new installs
# based on test results: 4 cores / 500MHz → ~120mW average. Adjust or disable as needed.
FREQ_CAP_ENABLE=1
FREQ_CAP_CPU0="500000"
FREQ_CAP_CPU1="500000"
FREQ_CAP_CPU2=""         # parked — ignored
FREQ_CAP_CPU3=""         # parked — ignored
FREQ_CAP_CPU4=""         # parked — ignored
FREQ_CAP_CPU5=""         # parked — ignored
FREQ_CAP_CPU6=""         # parked — ignored
FREQ_CAP_CPU7=""         # parked — ignored

# ----------------------------------------------------------------
# SCREEN-ON FREQUENCY TARGETS  (applied after cores come back)
# ----------------------------------------------------------------
# Target Hz to set when screen turns on. Empty = restore hardware max.
# Useful if you want to keep cores at a moderate freq after wake.
#
FREQ_ON_CPU0=""
FREQ_ON_CPU1=""
FREQ_ON_CPU2=""
FREQ_ON_CPU3=""
FREQ_ON_CPU4=""
FREQ_ON_CPU5=""
FREQ_ON_CPU6=""
FREQ_ON_CPU7=""

# ----------------------------------------------------------------
# LOGGING & DIAGNOSTICS
# ----------------------------------------------------------------
# VERIFY: read sysfs back after each write to confirm it took
# VERBOSE: log every logcat line seen (noisy but useful for debugging)
VERIFY=1
VERBOSE=1
