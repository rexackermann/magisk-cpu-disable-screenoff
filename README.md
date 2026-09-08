# CPU Screen Off

**Park your big cores when the display goes dark. Wake them instantly when you need them.**

![Magisk](https://img.shields.io/badge/Magisk-20400%2B-5C4EFF?style=flat-square)
![KernelSU](https://img.shields.io/badge/KernelSU%20Next-Supported-EF233C?style=flat-square)
![Android](https://img.shields.io/badge/Android-8.0%2B-3DDC84?style=flat-square)
![License](https://img.shields.io/badge/License-MIT-blue?style=flat-square)

---

## What it does

Most Android devices keep all CPU cores spinning while the screen is off. CPU Screen Off watches for the system "Dozing" event and takes your secondary cores offline immediately. They come back the instant the screen wakes. No polling, no performance penalty while the screen is on.

**Result:** fewer cores burning idle power during sleep, lower temperatures, longer standby battery life.

---

## How it works

The module opens a single `logcat` stream watching `PowerManagerService` and reacts to four events:

| Trigger | Action |
|---|---|
| `Dozing...` | Log battery, wait SETTLE_DELAY, park CORES_OFF |
| `Screen on took` | Log battery, restore CORES_OFF |
| `PLUGGED:true` | Log charger connect (battery boundary) |
| `PLUGGED:false` | Log charger disconnect (battery boundary) |

No polling, no timers, no extra processes — everything runs off the same logcat stream.

---

## Installation

### Magisk
1. **Magisk** → Modules → Install from storage → `cpu-screenoff-v2.8.zip`
2. Reboot

### KernelSU / KernelSU Next
1. **KernelSU** → Modules → Install → `cpu-screenoff-v2.8.zip`
2. Reboot

> Existing `postboot.sh` and `cpu_screenoff.conf` are preserved on update.

---

## WebUI

Open from the Magisk or KernelSU app module list → **WebUI**.

- **CPU Cores** — animated per-core bubbles: purple = fixed on, green = online, dark = parked
- **Battery Stats** — screen-off vs screen-on drain rate (%/hr), tabs for 24h / 7d / 30d / all time, charging sessions excluded automatically
- **Configuration** — all settings, hot-apply badges, unsaved indicator, discard button
- **Controls** — restart service, enable/disable module, clear log
- **Live Log** — colour-coded, auto-scrolling

---

## Configuration

File: `/data/adb/cpu_screenoff.conf`

The WebUI writes this file using `base64` encoding to ensure real newlines. If editing manually, use a heredoc:

```sh
cat > /data/adb/cpu_screenoff.conf << 'EOF'
CORES_OFF="1 2 3 4 5 6 7"
SETTLE_DELAY=1
BOOT_DELAY=30
VERIFY=1
VERBOSE=1
EOF
```

| Variable | Default | Description |
|---|---|---|
| `CORES_OFF` | `"2 3 4 5 6 7"` | Cores to park. CPU 0 must always stay online. CPU 1 can be included on most kernels — test with `echo 0 > /sys/devices/system/cpu/cpu1/online` first. |
| `SETTLE_DELAY` | `1` | Seconds after screen-off before parking. Prevents hotplug FAILED errors during kernel doze transition. Raise to 2–3 if errors persist. |
| `BOOT_DELAY` | `30` | Seconds after boot before monitor starts. |
| `VERIFY` | `1` | Read sysfs back after each change and log it. |
| `VERBOSE` | `1` | Log every logcat line seen. Disable to reduce log noise. |

### Hot-apply vs restart

| Setting | When it applies |
|---|---|
| CORES_OFF, SETTLE_DELAY, VERIFY, VERBOSE | Immediately on next screen event (SIGHUP sent by WebUI) |
| BOOT_DELAY | Next service restart only |

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
├── cpu_screenoff.conf        config
├── cpu_screenoff.log         runtime log (rotates at 1 MB)
├── cpu_screenoff.status      JSON status for WebUI (single line)
├── cpu_screenoff.pid         running service PID
├── cpu_screenoff_batt.log    battery event log (rotates at 500 KB)

/data/adb/modules/cpu-screenoff/
├── service.sh
├── postboot.sh
├── action.sh
├── module.prop
└── webroot/index.html
```

---

## Troubleshooting

**FAILED (still 1) on screen off** — increase `SETTLE_DELAY` to 2 or 3.

**WebUI stats show —** — service not running. Check:
```bash
cat /data/adb/cpu_screenoff.log | tail -20
```

**Config not applying** — verify file has real newlines:
```bash
cat -A /data/adb/cpu_screenoff.conf  # should end lines with $ not \n
```

**Duplicate instances:**
```bash
kill $(cat /data/adb/cpu_screenoff.pid)
```

---

## Changelog

### v2.9
- Cores restore **immediately** on wake — TRIGGER_ON changed to `Waking up from Dozing` (fires during screen-on animation, ~300ms earlier than before)
- SETTLE_DELAY default raised from 1s to 5s — gives system time to fully settle before parking, configurable in WebUI
- Fixed version strings in `action.sh` and `update-binary`

### v2.8
- Config save now uses `btoa()` + `base64 -d` to write real newlines — fixes literal `\n` bug
- CPU 1 parkable on supported kernels

### v2.7
- Charger-aware battery stats: plug/unplug logged from existing logcat stream
- Sessions spanning a charger boundary excluded from drain rate calculations

### v2.6
- Battery discharge stats panel (24h / 7d / 30d / all)
- Screen-off vs screen-on drain rate comparison
- Zero extra CPU wake-ups — reads only at screen events

### v2.5
- Config form no longer reverts after save
- Hot-apply / restart badges, discard button, unsaved indicator
- Toast and status-bar notification removed

### v2.4
- Fixed `ksu.exec` returning only last line on KernelSU Next
- Status JSON written as single line
- Multi-line log read via base64 pipe

### v2.3
- WebUI with CPU core visualisation, config editor, live log
- postboot.sh hook, SIGHUP reload, PID guard, EXIT trap

### v2.2
- Fixed hotplug FAILED race with SETTLE_DELAY

### v2.1
- Initial release

---

## License

MIT © Rex Ackermann
