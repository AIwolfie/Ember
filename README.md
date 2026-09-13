<div align="center">

# 🎵 Ember 

**The cozy floating desktop music companion that refuses to get in your way.**

*Slim as a ribbon · Warm as lamplight · Endlessly yours*

<br/>

<img src="ember1.png" alt="Ember ribbon" width="440">

<br/>

<img src="ember2.png" alt="Ember expanded player" width="440">

</div>

---

## 🆙 What's New In This Fork (The Receipts)

No fluff, no cap — here is everything genuinely upgraded in this fork:

- 🎤 **Live Lyrics Tab & Asynchronous Lyrics Worker** (`catalog.py`, `jobs.py`, `panel.py`): Dedicated 4th library tab with background lyrics extraction via `ytmusicapi` watch playlist endpoints, complete with source attribution and text selection.
- 🌙 **Sleep Timer with 15-Second Volume Attenuation** (`panel.py` + `player.py`): 15m, 30m, 45m, and 60m countdown presets with live badge timer and smooth exponential fade-out to zero before pausing.
- 🔀 **Upcoming Queue Shuffle & Repeat Modes** (`player.py` + `panel.py`): Non-destructive upcoming track shuffle preserving listening history, plus cycleable repeat modes (`off` ➔ `all` ➔ `one` ➔ `off`).
- ⚡ **Variable Playback Speed Control** (`player.py` + `panel.py`): Cycle between `1.0x`, `1.25x`, `1.5x`, and `0.75x` via native `QMediaPlayer.setPlaybackRate()`.
- 🪟 **Desktop Glass Opacity Tuner** (`config.py` + `settings_dialog.py` + `panel.py`): Live 60%–100% window translucency slider in preferences with instant real-time feedback and persistent storage.
- 🌊 **Fluid Spring Equalizer Bars** (`panel.py`): Upgraded from stepped integer modulo ticks to a 4-bar spring-damper physics simulation (`SpringPhysics`) with harmonic wave oscillations and anti-aliased gradient fills.
- ⚡ **Zero-Latency Thread Pool Isolation** (`player.py` + `jobs.py`): Separated stream resolution into an isolated playback thread pool so audio decoding *never* queues behind heavy radio queries or multi-image artwork downloads. Audio plays the millisecond the stream URL is resolved.
- 🛡️ **Network Resilience & Retry Backoff** (`catalog.py` + `stream.py`): Wrapped `ytmusicapi` and `yt-dlp` in exponential backoff retry loops (`_with_retry`), robust format fallback sorting (prioritizing Windows Media Foundation-friendly M4A/AAC), and automatic dead-track auto-skipping.
- 💾 **SQLite Local Library & Playback History** (`storage.py`): Persistent local database (`ember.db` in AppData via Python's built-in `sqlite3` — zero external bloat). Pin favorite tracks with one click (`♡` / `♥`) and revisit your listening history anytime in dedicated tabs.
- 🎨 **Dynamic Multi-Theme Palette Engine** (`config.py` + `theme.py`): Extended `Palette` with 5 hand-crafted presets (`Amber`, `Emerald`, `Amethyst`, `Solar`, `Rose`) without breaking the single-source-of-truth architecture. Re-skins Qt stylesheets and all custom-painted widgets live at runtime.
- 🎛️ **Preferences & Settings Panel** (`settings_dialog.py`): Dedicated modal dialog (`⚙`) for volume normalization (softens loudness spikes across tracks), endless queue toggles, runtime theme selection, glass opacity, and desktop toast preferences.
- ⌨️ **Configurable Hotkeys with Conflict Detection** (`settings_dialog.py` + `app.py`): Customize your playback chords directly in the UI, complete with real-time detection flagging conflicts with default Windows shortcuts (`Ctrl+C`, `Alt+F4`, `Win+L`, etc.).
- 🔍 **Real-Time Search Debouncing** (`panel.py`): Smart 350ms input debounce on catalogue search so you can type freely without spamming network requests or stalling the UI.
- 🍞 **Ghost "Now Playing" Desktop Toast** (`toast.py`): Subtle floating toast that slides in with album art when a track starts, completely non-intrusive and never steals window or typing focus.
- 📜 **Rotating File Logging** (`app.py`): Standardized logging levels and upgraded to `RotatingFileHandler` (2 MB, 3 backups) so logs never balloon your disk.
- 🧪 **Automated Test Suite & GitHub Actions CI** (`tests/` + `.github/workflows/ci.yml`): Expanded to 37 comprehensive unit, resilience, and smoke tests covering models, themes, storage, lyrics jobs, queue pruning, repeat logic, spring physics, and retry resilience.

---

## ✨ What It Does

| Feature | The Vibe |
|:---|:---|
| 🔍 **Search or paste** | Type any song name or drop a YouTube/YT Music link straight into the field — debounced and instant |
| 🎤 **Live lyrics** | Sing along with auto-retrieved real-time lyrics directly in the 4th tab with source credits |
| 🌙 **Sleep timer** | Drifts off with 15m–60m presets and 15-second gentle volume fade-out before pausing |
| 🔀 **Shuffle & Repeat** | Non-destructive upcoming queue shuffle and cycleable repeat modes (off / all / one) |
| ⚡ **Speed control** | Seamless playback rate adjustment between 0.75x, 1.0x, 1.25x, and 1.5x |
| 🪟 **Glass opacity** | Window translucency tuner (60%–100%) to blend Ember cleanly over your desktop |
| ♾️ **Endless queue** | The recommendation graph feeds look-alike tracks in behind your seed so the room never goes quiet |
| 🪟 **Ribbon → panel** | Thin, discreet desk ribbon that blooms into an expanded player when you want to dig into the queue |
| 🎛️ **Hand-painted controls** | Rotating vinyl disc, spring-damper equalizer bars, and a cozy drag-to-set circular volume dial |
| 📌 **Always on top** | Floats cleanly over IDEs, browsers, and terminal windows without ever stealing keyboard focus |
| 🖥️ **Tray presence** | Play, pause, skip, or summon from the system tray — Windows and Linux desktops |
| ⌨️ **Hotkeys** | Global chords for every common action, fully customizable and conflict-checked |
| 💾 **Remembers everything** | Window position, volume, opacity, theme, favorites, and playback history persisted across reboots |

---

## 🚀 Get This Running (it's not that deep)

> [!NOTE]  
> **Platform Support**: Ember is built for **Windows** (Python 3.10 to 3.13) and runs natively on **Linux** — with **Arch Linux** fully documented below. The only Windows-exclusive call (`user32.SetWindowPos` topmost hardening) is platform-guarded via `sys.platform`, so on Arch the Qt `WindowStaysOnTopHint` quietly takes over. No fake shell scripts — just real, tested commands.

### The Fast Way (Automated)

```bat
install.bat
```
Creates an isolated `.venv` in the directory and installs pinned dependencies into it. Your system Python stays completely untouched.

```bat
launch.bat
```
Launches Ember smoothly in the background without keeping a pesky command prompt window open.

*(Want to see console logs in real time? Run `launch_debug.bat` instead.)*

### The Manual Way

```bat
python -m venv .venv
.venv\Scripts\python.exe -m pip install -r requirements.txt
.venv\Scripts\pythonw.exe -m ember
```

### Arch Linux (and friends)

Ember runs natively on Arch. Everything it touches — `PyQt6`, `qtawesome`, `ytmusicapi`, `yt-dlp` — is a cross-platform Python package, and the PyPI `PyQt6` wheel ships the FFmpeg multimedia backend for Linux, so audio plays out of the box.

**1. Install the system packages:**

```bash
sudo pacman -S --needed python python-pip ffmpeg git
```

> [!TIP]
> `ffmpeg` is what `yt-dlp` reaches for when a stream needs remuxing — not required for every track, but strongly recommended.

**2. Clone, build a venv, launch:**

```bash
git clone https://github.com/AIwolfie/Ember.git
cd Ember
python -m venv .venv
.venv/bin/python -m pip install -r requirements.txt
.venv/bin/python -m ember
```

**3. Run the test suite (the Arch way):**

```bash
.venv/bin/python -m pytest tests/ -v
```

> [!NOTE]
> **Tray icon on Linux**: works out of the box on KDE Plasma, Hyprland/sway (with a tray-capable bar like Waybar), and any panel implementing `StatusNotifierItem`. On GNOME you'll need an AppIndicator extension for the tray to appear — the floating ribbon itself is unaffected.

---

## ⌨️ Default Hotkeys

| Keys | Action |
|:---|:---|
| `Ctrl` + `Alt` + `Space` | Play / pause |
| `Ctrl` + `Alt` + `→` | Next track |
| `Ctrl` + `Alt` + `←` | Previous track (or restart song) |
| `Ctrl` + `Alt` + `E` | Toggle expanded panel |
| `Ctrl` + `Alt` + `↑` | Expand panel |
| `Ctrl` + `Alt` + `↓` | Collapse panel |
| `Ctrl` + `Alt` + `F` | Focus search field |

*(All chords can be customized from the `⚙` Preferences dialog inside the player).*

---

## 🗂️ Project Structure

```
Ember/
├── .github/workflows/
│   └── ci.yml          → multi-OS GitHub Actions test & lint pipeline
├── ember/
│   ├── __init__.py     → package metadata & version
│   ├── __main__.py     → python -m ember launcher
│   ├── app.py          → lifecycle, rotating logs, session restore, hotkeys
│   ├── catalog.py      → YouTube Music guest API with retry backoff
│   ├── config.py       → design tokens, theme presets, geometry & tunables
│   ├── jobs.py         → QRunnable tasks with isolated thread pools
│   ├── models.py       → Song dataclass & serialization
│   ├── panel.py        → the floating surface, tabs, search debounce, UI
│   ├── player.py       → audio core, queue engine, volume normalization
│   ├── settings_dialog.py → preferences modal, hotkeys, theme switcher
│   ├── storage.py      → SQLite favorites & playback history manager
│   ├── stream.py       → yt-dlp audio stream resolver with format fallback
│   ├── theme.py        → template stylesheets built dynamically from Palette
│   ├── toast.py        → non-focus-stealing desktop notification toast
│   ├── tray.py         → system tray presence & single-instance guard
│   └── utils.py        → clock, string elision, and helpers
├── tests/              → automated pytest suite (models, palette, storage, resilience)
├── install.bat         → one-click Windows venv & dependency installer
├── launch.bat          → silent desktop launcher
├── launch_debug.bat    → console-attached diagnostic launcher
├── requirements.txt    → pinned dependencies
├── CREDITS.md          → full project attribution
├── LICENSE             → MIT License (original copyright holder preserved)
└── README.md           → you are here 🔥
```

---

## 🎨 Design System

One palette. One source of truth.

> Espresso base, amber light, cream typography — built for a dark room, glowing monitors, and a long evening.

Every visual token lives in `Palette` in `ember/config.py`. `theme.py` compiles those tokens into Qt stylesheets using `string.Template`, and every custom-painted widget (`VinylDisc`, `EqualiserBars`, `VolumeDial`, `SeekBar`, `Hairline`, `QueueRow`) reads from that exact same class.

Switch to `Emerald`, `Amethyst`, `Solar`, or `Rose` from the settings menu and the entire player repaints in real time.

---

## ⚙️ How It Works (The Threading Architecture)

Stream resolution and recommendation generation run completely asynchronously on **isolated thread pools**:

1. **Playback Pool**: Dedicated exclusively to `LoadJob`. When you pick a track, the audio stream resolves and begins playing immediately.
2. **Background Pool**: Handles `RadioJob` (graph look-alikes), `ArtJob` (cover thumbnails), and `SearchJob`. Heavy background tasks never stall or delay audio playback.

```mermaid
flowchart TD
    A["Search Query or Link"] --> B["Queue Engine"]
    B -->|"Immediate (Dedicated Playback Pool)"| C["LoadJob: Resolve Audio Stream"]
    B -->|"Parallel (Background Pool)"| D["RadioJob: Expand Recommendation Graph"]
    C --> E["QMediaPlayer: Instant Playback"]
    D -->|"Append Fresh Tracks"| B
    C -->|"Track Change Event"| F["NowPlayingToast Notification"]
    C -->|"Log Playback"| G["SQLite History (ember.db)"]
```

---

## 🧪 Testing

Run the automated test suite locally:

```bat
.venv\Scripts\python.exe -m pytest tests/ -v
```

On Arch Linux:

```bash
.venv/bin/python -m pytest tests/ -v
```

---

## 🫡 Credits

### Creator & Maintainer

**Mayank Malaviya aka ([@AIwolfie](https://github.com/AIwolfie))**  
Original creator, architect, and maintainer of Ember.

### Contributors

**Muhammad Taezeem Tariq Matta** ([@taezeem14](https://github.com/taezeem14))  
Contributor — development improvements and project upgrades.

### License

Ember is distributed under the **MIT License**.  
See [LICENSE](LICENSE) for the complete license and copyright notice.

---

<div align="center">
<sub><strong>Ember</strong> — cozy listening, engineered to never drop a beat. 🔥</sub>
</div>
