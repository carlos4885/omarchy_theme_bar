# Night Run bar

Run `./install.sh`. It copies the modules and the sound, backs up `shell.json`
(`shell.json.bak-nightrun`) and edits the layout. Running it again is safe.

| Module | What it is | Data | Click |
|---|---|---|---|
| `nfs-ignition` | Ignition key, plays an engine start on left click | – | menu / terminal |
| `nfs-gears` | Workspaces as a gearbox | Hyprland | switch workspace |
| `nfs-radio` | Police scanner ticker | – | next message |
| `nfs-mirror` | Rear-view mirror clock | – | long date |
| `nfs-dash` | WiFi / Bluetooth / mic warning lights | sysfs, bluetoothctl, wpctl | open panel / mute mic |
| `nfs-heat` | Five wanted-level stars | hottest sensor, falls back to load | – |
| `nfs-tacho` | CPU tachometer, redline from 90 % | /proc/stat | btop |
| `Panel.qml` + `nfs-fuel` | Battery gauge: `Panel.qml` patches Omarchy's own power widget (icon replaced, panel kept); `nfs-fuel` is only the fallback, police lights under 15 % | /sys/class/power_supply | – |
| `nfs-odometer` | Uptime odometer, 1 min = 1 km | /proc/uptime | – |

Optional per-module settings (the install script adds the entries without any):

- `nfs-ignition`: `sound: false` for a silent start
- `nfs-tacho`: `redline` (90), `maxRpm` (8000)
- `nfs-fuel`: `low` (15), `showPercent` (false)
- `nfs-heat`: `source` ("auto" | "temp" | "load"), `thresholds` (five numbers)
- `nfs-odometer`: `kmPerMinute` (1)

The engine sound is generated, not recorded: edit `tools/make_engine_sound.py`
and run it to change it, or drop your own WAV at
`~/.config/omarchy/bar/sounds/nfs-engine-start.wav`.
