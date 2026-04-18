# playnite_shell

A lightweight Windows boot script that transforms your PC into a dedicated gaming platform by launching [Playnite](https://playnite.link) in fullscreen mode at logon, optionally playing a splash screen video while everything loads in the background.

Designed to be used alongside a Windows shell replacement setup, where `nite_loader.pyw` acts as the user shell, launching Playnite and Explorer seamlessly so the desktop never appears during boot.

---

## Why I made this

I wanted something similar to Heroic game launcher on Linux, for games that I can't play on my main linux system due to their Anti-Cheat, 
so when I found Playnite just a few days ago, I had the idea of utilising it as my main windows shell, I tried every solution I could find within the community 
but with dual monitors and higher expectations, this project was born.

---

## How It Works

```
Logon → Shell:nite_loader → Splash Screen → Playnite.FullscreenApp → Shell:explorer.exe
```

After setting `nite_loader.pyw` as the user shell, the next time we Logon, nite_loader will run in this order:

1. Launches the (optional) splash screen video via [mpv](https://mpv.io).
2. Starts Playnite in Fullscreen mode.
3. Starts the explorer shell.
4. Monitors Playnite's window — Pausing the splash screen if it hasn't loaded within a set time.
5. Resumes and finishes the splash screen once Playnite is confirmed ready.

---

## Folder Structure

The main folder name is not important, so feel free to name it whatever you want, but I would recommend placing this folder at the root level of your system i.e. `C:\playnite_shell`

```
playnite_shell\
├── scripts\
│   └── nite_loader.pyw
├── bin\
│   └── mpv\
│       └── mpv.exe
├── splashscreens\
│   └── your_video.mp4
├── logs\
│   └── nite_loader.log
└── icon.png
```

> For more information regarding MPV, check out this [README](https://github.com/UnknownWitcher/Kaer-Morhen/blob/main/Microslop/playnite_shell/bin/mpv/README.md)
>
> Splash screen videos can be obtained from [tedhinklater/playnitesplashintro](https://github.com/tedhinklater/playnitesplashintro) 
>
> `icon.png` is optional, and is only used as the notification icon. If missing, notifications will still work without it.
>
---

## Requirements

**Required**
- [Python 3.11+](https://www.python.org/downloads/) — install with "Add Python to PATH" ticked
- [mpv](https://mpv.io/installation/) — place `mpv.exe` in `\bin\mpv\`
- [Playnite](https://playnite.link) — installed as normal

**Optional but recommended**
```
pip install psutil winotify
```

- `psutil` enables accurate window detection. Without it, the script falls back to a basic process name check which is less reliable.
- `winotify` — enables Windows toast notifications for warnings and errors. Without it, issues are logged to file only.

> If Python is installed under `C:\Program Files`, run `pip install` in Terminal as Administrator, otherwise they'll install to the default APPDATA location.

---

## Configuration

All configuration is done at the bottom of `nite_loader.pyw`.

### Basic Setups

```python
# Launch Playnite without splash screen
playnite = Playnite()
playnite.launch()

# Launch Playnite with splash screen enabled
playnite = Playnite()
playnite.splash_settings(True)
playnite.launch()

# Launch Playnite with custom Playnite and splash settings
playnite = Playnite(disable_notify=True)
playnite.splash_settings(
    enabled=True,
    video="XBox360.mp4",
    pause_at=6,
    screen=0
)
playnite.launch()
```

---

### `Playnite(app_path, disable_notify, disable_explorer)`

The main class. Instantiate this first.

| Parameter | Type | Default | Description |
|---|---|---|---|
| `app_path` | `str \| Path \| None` | `None` | Path to the Playnite install folder. If `None`, defaults to `%LOCALAPPDATA%\Playnite`. Accepts environment variables and `~`. |
| `disable_notify` | `bool` | `False` | Disables all Windows toast notifications. Warnings and errors are still written to the log file. |
| `disable_explorer` | `bool` | `False` | Prevents `explorer.exe` from being launched after the splash. Useful if you're testing the script or you want to manage Explorer yourself.

**Examples**

```python
# Default — Playnite in %LOCALAPPDATA%\Playnite
playnite = Playnite()

# Custom Playnite path
playnite = Playnite(app_path=r"D:\Playnite")

# Disable notifications
playnite = Playnite(disable_notify=True)

# Disable Explorer (advanced)
playnite = Playnite(disable_explorer=True)

# Multiple inputs
##  Custom path, Disable notifications
playnite = Playnite(r"D:\Playnite",True)

##  Custom path, Disable notifications and Explorer
playnite = Playnite(
    app_path=r"D:\Playnite",
    disable_notify=True,
    disable_explorer=True
)
```

---

### `splash_settings(enabled, video, pause_at, screen)`

Configures the splash screen. Call this before `launch()`.

| Parameter | Type | Default | Description |
|---|---|---|---|
| `enabled` | `bool` | `False` | Enables the splash screen. If `False`, all other splash settings are ignored. |
| `video` | `str` | `"splash.mp4"` | Filename of the video inside the `splashscreens/` folder. |
| `pause_at` | `int` | `0` | Time in seconds at which the video pauses if Playnite has not yet loaded. Set to `0` to disable pausing — the video plays to the end regardless. |
| `screen` | `int` | `0` | Zero-based monitor index to display the splash on. `0` is your primary monitor, `1` is your second monitor, etc. |

> If the specified video file does not exist and `enabled` is `True`, a warning is logged, the splash is disabled, and Playnite launches without it.

**Examples**

```python
# Splash enabled, pause at 6s if Playnite isn't ready, primary monitor
playnite.splash_settings(True, "intro.mp4", 6, 0)

# Splash on second monitor, no pause
playnite.splash_settings(True, "intro.mp4", 0, 1)

# For better clarity
playnite.splash_settings(
    enabled=True,
    video="intro.mp4",
    pause_at=6,
    screen=0
)
```

>Removing or setting `playnite.splash_settings()` will disable the splash screen.

---

### `launch(delay_playnite)`

Starts the boot sequence.

| Parameter | Type | Default | Description |
|---|---|---|---|
| `delay_playnite` | `int \| None` | `None` | Delays Playnite launch by this many seconds. Useful for testing the pause behaviour — set a value higher than `pause_at` to simulate a slow Playnite load. |

**Examples**

```python
# Normal launch
playnite.launch()

# Delay Playnite by 10 seconds (for testing)
playnite.launch(delay_playnite=10)
```

---

## Logging

All warnings and errors are written to `logs/nite_loader.log` in the root folder, regardless of notification settings.

```
[YYYY-MM-DD 09:12:01] [WARN ] Missing Splash video: 'C:\playnite_shell\splashscreens\splash.mp4'.
[YYYY-MM-DD 09:12:04] [ERROR] Missing Playnite launcher: 'C:\...\Playnite.FullscreenApp.exe'
```

---

## Shell Replacement Setup

>**Recovery:** If something goes wrong and explorer doesn't load, follow the [Troubleshooting](#troubleshooting) steps.

To have Windows boot directly into Playnite instead of the normal desktop:

1. Open `regedit` and navigate to:
   ```
   HKEY_CURRENT_USER\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Winlogon
   ```
2. Create a new **String Value** named `Shell`
3. Set its value to:
   ```
   "C:\Program Files\Python313\pythonw.exe" C:\playnite_shell\scripts\nite_loader.pyw
   ```
4. Ensure `HKEY_LOCAL_MACHINE\...\Winlogon` has `Shell` set to `explorer.exe` as the system fallback

On next logon, `nite_loader.pyw` runs as the shell, plays the splash, launches Playnite, and starts Explorer — with no desktop or taskbar visible during the process.

---

## Troubleshooting

<details>
  <summary style="cursor: pointer; align-items: center;">
    <span id="explorer-not-loading" style="font-size: 2rem; font-weight: 600;">Explorer not loading?</span>
  </summary>
  <p style="margin-left:20px;">Launch Task Manager (<code>Ctrl+Shift+Esc</code>) → File → Run new task → type <code>explorer.exe</code></p>
</details>

<details>
  <summary style="cursor: pointer; align-items: center;">
    <span id="file-explorer-opens" style="font-size: 2rem; font-weight: 600;">File explorer opens?</span>
  </summary>
<p style="margin-left:20px;">
    <b><i>If explorer is already running:</i></b><br/>
    Assuming you didn't replace the user shell and didn't disable explorer within <code>nite_loader.pyw</code>. Then this behavior is expected.
</p>
<p style="margin-left:20px;">
    <b><i>If explorer isn't running</i></b><br/>
    You've most likely removed or replaced explorer under <code>HKEY_LOCAL_MACHINE\...\Winlogon</code>.<br/><br/>
    You'll need to launch Task Manager (<code>Ctrl+Shift+Esc</code>) → File → Run new task → type <code>regedit</code>, make sure <code>explorer.exe</code> is set for the shell under <code>HKEY_LOCAL_MACHINE\...\Winlogon</code>.<br/><br/>
    Now reload <code>explorer.exe</code>
</p>
</details>

---

## Notes

- Splash videos of any length are supported. The `pause_at` value should be set a few seconds before the natural end of the video to leave room for the ending to play out after Playnite loads.
- mpv loops are not used — the video plays once and exits cleanly.
- The script has no impact on Playnite itself and is compatible with any Playnite theme or plugin setup.

---

## Road Map

- [ ] **Improve Error handling**: This script is still young, one might say early Alpha stages, and some edge cases still need tested to ensure I cover every possible issue correctly and safely.

- [ ] **Focus Guard**: I've noticed that focus can be lost during launch with the ubiquit theme I'm using, although I'm not sure if it's specific to the theme (doubt it), but since I do have other applications loading when explorer loads, I need a way to maintain focus during startup.
