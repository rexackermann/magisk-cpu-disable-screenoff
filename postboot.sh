#!/system/bin/sh
# ═══════════════════════════════════════════════════════════════════
#  CPU Screen Off — postboot.sh
#
#  This script is executed ONCE after the boot delay, right before
#  the screen-off monitor loop starts. Use it for any one-time
#  kernel or CPU tuning you want applied at boot.
#
#  It runs as root. stdout/stderr goes to the main log.
#  Edit freely — service.sh will not overwrite this file on update.
# ═══════════════════════════════════════════════════════════════════

# ─── Examples — uncomment what you want ─────────────────────────────

# Set schedutil governor on always-on cores
# for cpu in 0 1; do
#     echo schedutil > /sys/devices/system/cpu/cpu${cpu}/cpufreq/scaling_governor
# done

# Pre-set powersave governor on cores that will be parked
# for cpu in 2 3 4 5 6 7; do
#     echo powersave > /sys/devices/system/cpu/cpu${cpu}/cpufreq/scaling_governor
# done

# Clamp max freq on big cores while screen is on (optional)
# echo 1804800 > /sys/devices/system/cpu/cpu6/cpufreq/scaling_max_freq
# echo 1804800 > /sys/devices/system/cpu/cpu7/cpufreq/scaling_max_freq

# Tweak scheduler tunables
# echo 1 > /proc/sys/kernel/sched_autogroup_enabled
# echo 0 > /proc/sys/kernel/sched_child_runs_first

# Custom sysfs writes
# echo 0 > /sys/module/lpm_levels/parameters/sleep_disabled

# ─── Add your commands below ────────────────────────────────────────
