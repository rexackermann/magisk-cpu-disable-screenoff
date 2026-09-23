# CPU Screen Off

**Park your big cores when the display goes dark. Wake them instantly when you need them.**

![Magisk](https://img.shields.io/badge/Magisk-20400%2B-5C4EFF?style=flat-square)
![KernelSU](https://img.shields.io/badge/KernelSU%20Next-Supported-EF233C?style=flat-square)
![Android](https://img.shields.io/badge/Android-8.0%2B-3DDC84?style=flat-square)
![License](https://img.shields.io/badge/License-MIT-blue?style=flat-square)

---

## What it does

Most Android devices keep all CPU cores spinning while the screen is off. CPU Screen Off watches for the system sleep event and takes your secondary cores offline immediately. They come back the instant the screen wakes. No polling, no performance penalty while the screen is on.

**Result:** fewer cores burning idle power during sleep, lower temperatures, longer standby battery life — and now with per-core governor and frequency control for even finer-grained tuning.

---

## How it works

The module opens a single `logcat` stream watching `PowerManagerService:I` (Info level) and reacts to four events:

| Trigger | Action |
|---|---|
| `Sleeping (uid` | Log battery, wait SETTLE_DELAY, park CORES_OFF, apply governors + freq caps |
| `Waking up from Asleep` | Log battery, restore CORES_OFF, restore governors + freq targets |
| `PLUGGED:true` | Log charger connect (battery boundary) |
| `PLUGGED:false` | Log charger disconnect (battery boundary) |

No polling, no timers, no extra processes — everything runs off the same logcat stream. Config changes are picked up automatically on the next screen event via mtime polling (no SIGHUP required).

> **MTK note:** Some MediaTek devices do not emit `Sleeping`/`Waking` via PowerManagerService. Charger state is still captured at screen on/off via `log_battery`. If your device doesn't respond, check `logcat -s PowerManagerService:I` while toggling the screen and adjust `TRIGGER_OFF` / `TRIGGER_ON` in your conf.

---

## Installation

### Magisk
1. **Magisk** → Modules → Install from storage → `cpu-screenoff-v3.6.zip`
2. Reboot

### KernelSU / KernelSU Next
1. **KernelSU** → Modules → Install → `cpu-screenoff-v3.6.zip`
2. Reboot

> Existing `postboot.sh` and `cpu_screenoff.conf` are preserved on update.

---

## WebUI

Open from the Magisk or KernelSU app module list → **WebUI**.

- **CPU Cores** — animated per-core bubbles: purple = fixed on, green = online, dark = parked
- **Battery Stats** — screen-off vs screen-on drain rate (%/hr), tabs for 24h / 7d / 30d / all time, charging sessions excluded automatically
- **Configuration** — all settings including governor and frequency controls, hot-apply badges, unsaved indicator, discard button
- **Controls** — restart service, enable/disable module, clear log
- **Live Log** — colour-coded, auto-scrolling

---

## Configuration

File: `/data/adb/cpu_screenoff.conf`

The WebUI writes this file using `base64` encoding to ensure real newlines. If editing manually, use a heredoc:

```sh
cat > /data/adb/cpu_screenoff.conf << 'EOF'
CORES_OFF="1 2 3 4 5 6 7"
SETTLE_DELAY=5
BOOT_DELAY=30
VERIFY=1
VERBOSE=1

# Governor control (v3.6+)
GOV_SCREEN_OFF="schedutil"
GOV_SCREEN_ON="schedutil"

# Frequency caps on screen-off (v3.6+)
FREQ_CAP_ENABLE=1
FREQ_CAP_CPU0="500000"
FREQ_CAP_CPU1="500000"
EOF
```

### Core settings

| Variable | Default | Description |
|---|---|---|
| `CORES_OFF` | `"2 3 4 5 6 7"` | Cores to park. CPU 0 must always stay online. CPU 1 can be included on most kernels — test with `echo 0 > /sys/devices/system/cpu/cpu1/online` first. |
| `SETTLE_DELAY` | `5` | Seconds after screen-off before parking. Prevents hotplug FAILED errors during kernel doze transition. Raise to 2–3 if errors persist. |
| `BOOT_DELAY` | `30` | Seconds after system boot before monitor starts. Automatically skipped on manual service restarts (uptime > 180s). |
| `VERIFY` | `1` | Read sysfs back after each change and log it. |
| `VERBOSE` | `1` | Log every logcat line seen. Disable to reduce log noise. |

### Governor control (v3.6+)

| Variable | Default | Description |
|---|---|---|
| `GOV_SCREEN_OFF` | `"schedutil"` | Global governor applied to all online cores on screen-off. Empty = don't touch. |
| `GOV_SCREEN_OFF_CPU0`…`CPU7` | `""` | Per-core override. Takes priority over `GOV_SCREEN_OFF`. Only applies to cores that stay online. |
| `GOV_SCREEN_ON` | `"schedutil"` | Global governor applied to all cores on screen-on. Empty = don't touch. |
| `GOV_SCREEN_ON_CPU0`…`CPU7` | `""` | Per-core override for wake. |

Find available governors:
```sh
cat /sys/devices/system/cpu/cpu0/cpufreq/scaling_available_governors
```

### Frequency caps (v3.6+)

| Variable | Default | Description |
|---|---|---|
| `FREQ_CAP_ENABLE` | `0` | Set to `1` to activate frequency caps on screen-off. |
| `FREQ_CAP_CPU0`…`CPU7` | `""` | Per-core Hz cap during screen-off. Only affects online (non-parked) cores. Empty = uncapped. |
| `FREQ_ON_CPU0`…`CPU7` | `""` | Per-core Hz target on screen-on. Empty = restore hardware max (`cpuinfo_max_freq`). |

Find available frequencies:
```sh
cat /sys/devices/system/cpu/cpu0/cpufreq/scaling_available_frequencies
```

### Hot-apply vs restart

| Setting | When it applies |
|---|---|
| CORES_OFF, SETTLE_DELAY, VERIFY, VERBOSE, GOV_*, FREQ_* | Automatically on next screen event (config mtime is polled) |
| BOOT_DELAY | Next service restart only |

Config is reloaded by mtime comparison at the start of each screen event handler — no manual SIGHUP needed. The WebUI Save button triggers this automatically.

---

## Battery stats

Battery is read at screen on/off and charger plug/unplug events only — no periodic polling.

Log format (`/data/adb/cpu_screenoff_batt.log`):
```
<unix_ts> <event> <pct> <status>
1700000000 start  85 Discharging
1700000060 off    84 Discharging
1700003660 on     81 Discharging
1700003700 off    81 Discharging
1700004000 plug   82 Charging
1700005800 unplug 91 Discharging
1700009400 on     88 Discharging
```

Sessions spanning a `plug` or `unplug` event are tainted and excluded from drain calculations. Sessions where battery ended higher than it started (`drain < 0`) are also excluded as a secondary guard.

---

## postboot.sh

`/data/adb/modules/cpu-screenoff/postboot.sh` runs once after the boot delay before the monitor loop. Use it for one-time governor or sysfs tuning. Never overwritten on update.

```sh
#!/system/bin/sh
# Example: powersave on parked cores, schedutil on always-on
for cpu in 1 2 3 4 5 6 7; do
    echo powersave > /sys/devices/system/cpu/cpu${cpu}/cpufreq/scaling_governor
done
echo schedutil > /sys/devices/system/cpu/cpu0/cpufreq/scaling_governor
```

---

## Files

```
/data/adb/
├── cpu_screenoff.conf          config (preserved on update)
├── cpu_screenoff.log           runtime log (rotates at 1 MB)
├── cpu_screenoff.status        JSON status for WebUI (single line)
├── cpu_screenoff.pid           running service PID
├── cpu_screenoff_batt.log      battery event log (rotates at 500 KB)
├── cpu_screenoff_orig_freqN    saved pre-cap freq per core (v3.6+)
├── cpu_screenoff.fifo          logcat FIFO pipe

/data/adb/modules/cpu-screenoff/
├── service.sh
├── postboot.sh
├── action.sh
├── config.sh
├── module.prop
└── webroot/index.html
```

---

## Troubleshooting

**FAILED (still 1) on screen off** — increase `SETTLE_DELAY` to 3–5. mtkpower/perfd may be writing cores back online during the doze transition.

**No screen events detected** — your device may use different PowerManagerService log strings. Run:
```bash
logcat -s PowerManagerService:I
```
Note: the module filters `PowerManagerService:I` (Info level). If your device emits sleep/wake events at a different log level, add the matching level to `TRIGGER_OFF` / `TRIGGER_ON` — or check `logcat -s PowerManagerService:*` for all levels.
Then toggle the screen off and on to find your device's strings. Set `TRIGGER_OFF` and `TRIGGER_ON` in your conf to match.

**WebUI stats show —** — service not running. Check:
```bash
cat /data/adb/cpu_screenoff.log | tail -20
```

**Config not applying** — verify file has real newlines:
```bash
cat -A /data/adb/cpu_screenoff.conf  # lines should end with $ not \n
```

**Duplicate instances:**
```bash
kill $(cat /data/adb/cpu_screenoff.pid)
```

**Freq caps not restoring on wake** — check `/data/adb/cpu_screenoff_orig_freqN` files exist. If the service crashed during screen-off, the restore may not have run. `FREQ_ON_CPUN` can set an explicit target as a fallback.

---

## Changelog

### v3.6 — Governor & Frequency Control
**Major feature release.** Full per-core CPU governor and frequency management on screen-off and screen-on.

- **Governor control** — `GOV_SCREEN_OFF` and `GOV_SCREEN_ON` set the cpufreq scaling governor for all online cores when the screen changes state. Per-core overrides (`GOV_SCREEN_OFF_CPU0`…`CPU7`, `GOV_SCREEN_ON_CPU0`…`CPU7`) take priority over the global value. Empty string = don't touch.
- **Frequency caps on screen-off** — `FREQ_CAP_ENABLE=1` activates per-core Hz caps applied after core parking and governor changes. Only affects cores that remain online. Original `scaling_max_freq` is saved to `/data/adb/cpu_screenoff_orig_freqN` and restored on wake.
- **Frequency targets on screen-on** — `FREQ_ON_CPUN` sets an explicit Hz target when the screen wakes. Empty = restore hardware max from `cpuinfo_max_freq` (or the saved pre-cap value as fallback).
- **Trigger strings updated** — `TRIGGER_OFF` changed from `Dozing...` to `Sleeping (uid` and `TRIGGER_ON` changed from `Waking up from Dozing` to `Waking up from Asleep`, matching current AOSP PowerManagerService output more reliably across Android 12–15.
- **Config reload via mtime polling** — replaced SIGHUP-based hot-reload with mtime comparison at the start of each event handler. Config changes are picked up on the next screen event without any signal. Eliminates the SIGHUP trap and simplifies the reload path.
- **Boot delay intelligence** — boot delay is now skipped automatically when system uptime exceeds 180s, so manual service restarts from the WebUI or action button are instant. Previously the full `BOOT_DELAY` wait was always observed.
- **Single-instance guard improved** — removed the `sleep 1` after killing old instances; PID file is written immediately after the kill loop.
- **Status JSON expanded** — `write_status` now includes `gov_screen_off`, `gov_screen_on`, and `freq_cap_enable` fields so the WebUI can display active power profile.
- **Cleanup handler extended** — EXIT trap now also kills the logcat background process and removes the FIFO pipe.
- **FIFO-based logcat pipe** — logcat is now piped through a named FIFO (`cpu_screenoff.fifo`) with logcat running as a background job (`LOGCAT_PID`), enabling the EXIT trap to kill it cleanly. `LOGCAT_FIFO` and `LOGCAT_PID` are declared at the top of the script so the EXIT trap is safe to reference them before the MAIN block runs. Previously used a pipeline subshell which could not be signalled.
- **action.sh display** — status summary now shows governor (off), freq cap state, and all new v3.6 fields. JSON parsing replaced with `sed`-based field extraction (no `jq` dependency) that correctly handles the single-line status JSON format. Previously used `grep | cut` which was brittle on the key-ordering of the JSON object.
- **config.sh v3.0** — fully restructured with sections for governors, freq caps, and freq restore targets. TRIGGER_OFF / TRIGGER_ON removed from config (internal defaults only). SETTLE_DELAY and BOOT_DELAY moved to the Core Parking section. Legacy `LOGGING` and `LOG_FILE` variables removed.
- **Startup log extended** — now logs `GOV_OFF`, `GOV_ON`, and `FREQ_CAP_ENABLE` alongside existing fields.

### v3.5
- **WebUI overhaul** — redesigned battery stats panel with cleaner drain rate cards, improved session boundary detection display, and responsive layout fixes for narrow screens.
- **WebUI config editor** — governor and frequency cap fields added to the configuration panel with inline help text and available-values hints.
- **Status JSON** — added `monitor` field indicating active detection method (logcat / inotify / dumpsys) for WebUI display. Later removed in v3.6 when the tiered monitor was reverted.

### v3.4
- **Freq cap restore hardening** — `apply_freq_on` falls back to `cpuinfo_max_freq` when the saved pre-cap file is missing, preventing cores from staying throttled after an unclean shutdown.
- **Per-core governor skip logic** — `apply_governors` now skips cores that are offline at call time, avoiding spurious sysfs write errors for parked cores.
- **Log noise reduction** — governor and freq writes are only logged when the value actually changes; no-op writes are silently skipped.

### v3.3
- **Frequency cap groundwork** — internal `apply_freq_caps` and `apply_freq_on` functions added. `FREQ_CAP_ENABLE` flag guards all writes. Not yet exposed in config or WebUI.
- **Per-core governor functions** — `apply_governors <phase>` introduced with global + per-core variable resolution.

### v3.2
- **Governor variable scaffolding** — `GOV_SCREEN_OFF`, `GOV_SCREEN_ON`, and all per-core variants added to service defaults. Not yet written to config or WebUI.
- **`do_screen_off` / `do_screen_on` extended** — `apply_governors` calls inserted after core state changes.

### v3.1
- **Removed `logcat` entirely** *(later reverted in v3.6)* — replaced with a tiered monitor: `inotifywait` on backlight sysfs node (event-driven, zero idle CPU) → `wakeup_count` + `dumpsys` → `dumpsys` poll every 2s as last resort.
- Charger plug/unplug detected via 30s sysfs poll on `/sys/class/power_supply/*/online` (was derived from logcat).
- Status JSON gains `monitor` field showing active detection method.
- `TRIGGER_OFF` / `TRIGGER_ON` variables removed (no longer applicable).

### v3.0
- **Architecture pivot** — internal refactor splitting governor, freq, and core control into dedicated functions in preparation for v3.x feature additions.
- `reload_config_if_changed()` function introduced (mtime-based, not yet wired to event handlers).
- Service startup log restructured for readability.

### v2.9
- Cores restore **immediately** on wake — `TRIGGER_ON` changed to `Waking up from Dozing` (fires during screen-on animation, ~300ms earlier than `Screen on took`).
- `SETTLE_DELAY` default raised from 1s to 5s — gives the system time to fully settle before parking. Configurable in WebUI.
- Fixed version strings in `action.sh` and `update-binary` which still reported v2.6.

### v2.8
- Config save now uses `btoa()` + `base64 -d` to write real newlines — fixes literal `\n` being written to conf file.
- CPU 1 now parkable on supported kernels (added to default `CORES_OFF` comment, tested safe on common big.LITTLE layouts).

### v2.7
- Charger-aware battery stats: plug/unplug events logged from existing logcat stream via `PLUGGED:true` / `PLUGGED:false`.
- Sessions spanning a charger boundary excluded from drain rate calculations.
- `log_battery plug` and `log_battery unplug` events added to battery log format.

### v2.6
- Battery discharge stats panel in WebUI (24h / 7d / 30d / all-time tabs).
- Screen-off vs screen-on drain rate comparison (%/hr).
- Zero extra CPU wake-ups — battery read only at screen and charger events, never polled.

### v2.5
- Config form no longer reverts to saved values after saving — form state preserved.
- Hot-apply / restart badges added to each config field.
- Discard button and unsaved indicator added.
- Toast and status-bar notification removed (was disruptive during screen-off transitions).

### v2.4
- Fixed `ksu.exec` returning only the last line on KernelSU Next — WebUI now reads status file and log via `base64` pipe.
- Status JSON written as a single line to ensure `ksu.exec` returns the full object.
- Multi-line log read via `base64` pipe to avoid line truncation.

### v2.3
- WebUI introduced: CPU core visualisation (animated per-core bubbles), config editor, live log panel.
- `postboot.sh` hook — runs after boot delay, before monitor loop. Never overwritten on update.
- SIGHUP hot-reload: WebUI sends SIGHUP after saving config.
- PID guard (`cpu_screenoff.pid`) and EXIT trap to clean up on service exit.

### v2.2
- Fixed hotplug FAILED race condition with `SETTLE_DELAY` — cores were being parked before mtkpower finished its own writes on sleep entry.

### v2.1
- Initial public release.
- `logcat -s PowerManagerService:I` monitor, CORES_OFF parking, basic log, module.prop.

---

## License

MIT © Rex Ackermann
