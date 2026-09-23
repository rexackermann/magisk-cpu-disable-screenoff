## v3.6 — Governor & Frequency Control

Full per-core CPU governor and frequency management on screen-off and screen-on.

### What's new
- **Governor control** — set cpufreq scaling governor for online cores on screen-off/on (`GOV_SCREEN_OFF`, `GOV_SCREEN_ON`, per-core `CPU0–7` overrides)
- **Frequency caps on screen-off** — per-core Hz caps after core parking (`FREQ_CAP_ENABLE`, `FREQ_CAP_CPUn`); original max freq saved and restored on wake
- **Frequency targets on screen-on** — explicit Hz target per core on wake (`FREQ_ON_CPUn`); falls back to hardware max
- **Updated logcat triggers** — `Sleeping (uid` / `Waking up from Asleep` for better AOSP 12–15 compatibility
- **Config hot-reload via mtime** — no SIGHUP needed; changes picked up on next screen event automatically
- **Smart boot delay** — skipped on manual restarts (uptime > 180s), only observed on actual system boot
- **FIFO-based logcat pipe** — named FIFO + background job enables clean EXIT trap teardown
- **action.sh** — status output now shows governor and freq cap state; JSON parsing hardened with `sed`

### Installation
Flash `CPU-Screen-Off-v3.6.zip` via Magisk Manager or KernelSU. Existing `postboot.sh` and `cpu_screenoff.conf` are preserved on update.

### Configuration
See [README](https://github.com/rexackermann/magisk-cpu-disable-screenoff/blob/main/README.md) for full reference tables, hot-apply matrix, and troubleshooting.

### Full changelog
See [README — Changelog](https://github.com/rexackermann/magisk-cpu-disable-screenoff/blob/main/README.md#changelog).
