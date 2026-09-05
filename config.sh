# ================================================================
# CPU Screen Off — Configuration
# Author : Rex Ackermann (github.com/rexackermann)
# Version: 2.0
# ================================================================
# Edit this file then reboot to apply changes.
# Log file: /data/adb/cpu_screenoff.log
# ================================================================

# ----------------------------------------------------------------
# CORE CONFIGURATION
# ----------------------------------------------------------------
# Space-separated list of CPU core indices to take OFFLINE when
# the screen turns off. Core 0 can never be disabled (kernel rule).
#
# To find your LITTLE vs big cores:
#   for cpu in /sys/devices/system/cpu/cpu[0-9]; do
#       echo "$(basename $cpu): cluster=$(cat $cpu/topology/physical_package_id 2>/dev/null) maxfreq=$(cat $cpu/cpufreq/cpuinfo_max_freq 2>/dev/null)"
#   done
#
# Lower max frequency = LITTLE (efficiency) cores.
# Keep at least one LITTLE core online at all times.
#
# Common layouts:
#   8-core big.LITTLE, keep 1 LITTLE:  CORES_OFF="1 2 3 4 5 6 7"
#   8-core big.LITTLE, keep 2 LITTLE:  CORES_OFF="2 3 4 5 6 7"
#   6-core big.LITTLE, keep 2 LITTLE:  CORES_OFF="2 3 4 5"
#
CORES_OFF="2 3 4 5 6 7"

# ----------------------------------------------------------------
# LOGCAT TRIGGERS
# ----------------------------------------------------------------
# These strings are matched against PowerManagerService logcat output.
# Change only if your device uses different log messages.
# To find the right strings for your device:
#   logcat -s PowerManagerService:I
# Then toggle screen off and on and look at what appears.
#
TRIGGER_OFF="Dozing..."
TRIGGER_ON="Screen on took"

# ----------------------------------------------------------------
# BOOT DELAY
# ----------------------------------------------------------------
# Seconds to wait after boot before starting the listener.
# Increase if the module fires before the system is fully ready.
# Minimum recommended: 30
#
BOOT_DELAY=30

# ----------------------------------------------------------------
# LOGGING
# ----------------------------------------------------------------
# LOGGING  : 1 = enabled, 0 = disabled
# LOG_FILE : path to the log file
# VERBOSE  : 1 = log every logcat trigger line in full
#            0 = log only the state change summary
#
LOGGING=1
LOG_FILE="/data/adb/cpu_screenoff.log"
VERBOSE=1

# ----------------------------------------------------------------
# VERIFICATION
# ----------------------------------------------------------------
# After each core change, read back the kernel's confirmed online
# CPU range and active processor count to verify the change took
# effect. Recommended to keep enabled.
#
VERIFY=1
