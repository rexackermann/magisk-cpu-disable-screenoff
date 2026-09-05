# CPU Screen Off

> Disables CPU cores when your screen turns off.  
> Zero polling — purely event-driven via logcat.  
> Catches **every** screen off trigger: power button, double tap, timeout.

**Author:** Rex Ackermann — [github.com/rexackermann](https://github.com/rexackermann)

---

## How it works

Listens to `PowerManagerService` via `logcat` — a blocking read that consumes
zero CPU while idle. When the screen goes off, configurable cores are disabled.
When the screen comes back on, they are restored. No polling, no timers, no
Tasker required.

---

## Requirements

- Rooted Android (Magisk or KernelSU)
- Kernel with CPU hotplug support (`/sys/devices/system/cpu/cpuN/online`)

---

## Installation

1. Flash `cpu-screenoff-v2.0.zip` via Magisk Manager
2. Reboot
3. Edit `/data/adb/modules/cpu-screenoff/config.sh` for your device
4. Reboot again to apply config

---

## Configuration

All options are in `config.sh`:

| Option | Default | Description |
|---|---|---|
| `CORES_OFF` | `2 3 4 5 6 7` | Core indices to disable on screen off |
| `TRIGGER_OFF` | `Dozing...` | Logcat string that means screen off |
| `TRIGGER_ON` | `Screen on took` | Logcat string that means screen on |
| `BOOT_DELAY` | `30` | Seconds to wait after boot before starting |
| `LOGGING` | `1` | Enable/disable logging |
| `LOG_FILE` | `/data/adb/cpu_screenoff.log` | Log output path |
| `VERBOSE` | `1` | Log every logcat line matched (useful for debugging) |
| `VERIFY` | `1` | Verify core state after each change |

### Finding your LITTLE cores

```sh
for cpu in /sys/devices/system/cpu/cpu[0-9]; do
    echo "$(basename $cpu): cluster=$(cat $cpu/topology/physical_package_id 2>/dev/null) maxfreq=$(cat $cpu/cpufreq/cpuinfo_max_freq 2>/dev/null)"
done
```

Lower max frequency = LITTLE (efficiency) cores. Keep at least one online.

### Common core layouts

| Setup | Active during screen off | `CORES_OFF` |
|---|---|---|
| 8-core, 1 LITTLE core | cpu0 | `1 2 3 4 5 6 7` |
| 8-core, 2 LITTLE cores | cpu0–1 | `2 3 4 5 6 7` |
| 6-core, 2 LITTLE cores | cpu0–1 | `2 3 4 5` |

### Finding your logcat triggers

If the defaults don't work on your device:

```sh
logcat -s PowerManagerService:I
```

Then toggle screen off and on — note the exact lines that appear and update
`TRIGGER_OFF` and `TRIGGER_ON` in `config.sh`.

---

## Monitoring

```sh
# Watch log live
tail -f /data/adb/cpu_screenoff.log

# Check currently online cores (kernel confirmed)
cat /sys/devices/system/cpu/online

# Count active processors
grep -c processor /proc/cpuinfo
```

---

## Testing without reboot (Termux/root terminal)

```sh
sh /data/adb/modules/cpu-screenoff/service.sh
```

Output will appear directly in the terminal via tee.

---

## Disabling

Toggle off in Magisk Manager or:

```sh
rm -rf /data/adb/modules/cpu-screenoff
```

Reboot — all cores return to normal automatically.

---

## License

MIT
