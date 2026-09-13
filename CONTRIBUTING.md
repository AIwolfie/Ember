<div align="center">

<br/>

# 🍂 &nbsp;Contributing to Ember

### *Crafting late-night desktop warmth together.*

<p align="center">
  <em>Warm lamplight &nbsp;·&nbsp; Thoughtful craft &nbsp;·&nbsp; Quiet excellence</em>
</p>

<p align="center">
  <img src="https://img.shields.io/badge/PRs-Welcome-f59e0b?style=for-the-badge&labelColor=17120e" alt="PRs Welcome"/>
  <img src="https://img.shields.io/badge/Code%20Style-Black%20%26%20Ruff-10b981?style=for-the-badge&labelColor=17120e" alt="Code Style"/>
  <img src="https://img.shields.io/badge/Tests-Pytest%20Passing-d97706?style=for-the-badge&labelColor=17120e" alt="Tests"/>
</p>

<br/>

</div>

---

<br/>

## 🕯️ &nbsp; The Philosophy

Thank you for considering contributing to **Ember**! 

Ember is not just another utility — it is an ambient, cozy desktop companion engineered to stay out of the user's way while writing code, studying, or winding down at night.

When proposing changes or writing code for Ember, keep our three core tenets in mind:

1. **Quiet Presence**: Ember never interrupts, nags with alerts, or steals keyboard focus. It stays lightweight, responsive, and discreet.
2. **Single Source of Truth**: All colors, fonts, margins, and geometry flow strictly from `Palette` and `config.py`. No hardcoded hex values in layouts.
3. **Thread Decoupling**: The audio player should never wait on the network. Stream resolution, lyrics fetching, and recommendation graphs run on isolated thread pools.

<br/>

---

<br/>

## ☕ &nbsp; Getting Started

Ember is built specifically for **Windows 10 & 11** with **Python 3.10 through 3.13**.

### 1. Clone & Set Up

```bat
# Clone your fork of Ember
git clone https://github.com/<your-username>/Ember.git
cd Ember

# Create and populate isolated virtual environment
python -m venv .venv
.venv\Scripts\python.exe -m pip install -r requirements.txt
```

### 2. Running Locally

- **Silent mode** (normal user experience):
  ```bat
  launch.bat
  ```

- **Debug mode** (terminal attached with live rotating logs):
  ```bat
  launch_debug.bat
  ```

<br/>

---

<br/>

## 🧪 &nbsp; Testing Standards

Before opening a pull request, verify that all existing tests pass and add unit tests for any new features or resilience fixes:

```bat
.venv\Scripts\python.exe -m pytest tests/ -v
```

### Test Organization:
- `tests/test_player.py` — Queue management, repeat modes, speed regulation, and auto-queue pruning.
- `tests/test_palette.py` — Palette tokens, runtime theme switching, and stylesheet compilation.
- `tests/test_storage.py` — SQLite database persistence (favorites, history, schema migrations).
- `tests/test_resilience.py` — Retry loops, backoff timers, and stream fallback mechanisms.
- `tests/test_features.py` — Spring physics, debouncing, and UI utilities.

<br/>

---

<br/>

## 🎨 &nbsp; Coding & Style Guidelines

### 1. UI & Visual Craft
- **Use the Palette**: Always reference `Palette.amber`, `Palette.void`, `Palette.line`, etc. If an opacity adjustment is required, use `rgba($amber_rgb, 0.18)` via `theme.py`.
- **Vector Icons Only**: Use vector icons provided by `icons.py` (FontAwesome 6). Never use static raw bitmaps or fragile Unicode glyphs for core interactive controls.
- **Smooth Painting**: Enable `QPainter.RenderHint.Antialiasing` and `QPainter.RenderHint.SmoothPixmapTransform` on all custom-painted widgets (`VinylDisc`, `SeekBar`, `VolumeDial`).

### 2. Network & Background Tasks
- All network interactions (`ytmusicapi`, `yt-dlp`, HTTP calls) **must** run off-thread via `QRunnable` jobs (`jobs.py`).
- Never freeze the main Qt GUI thread.
- Handle dropped connections and rate limits gracefully with retry backoff.

### 3. Clean Code
- Maintain modern type annotations (`from __future__ import annotations`).
- Keep code clean, readable, and well-commented where architecture is non-obvious.
- Preserve existing docstrings and licensing headers.

<br/>

---

<br/>

## 🌿 &nbsp; Pull Request Workflow

1. **Branch**: Create a descriptive feature branch from `main`:
   ```bat
   git checkout -b feature/your-feature-name
   ```
2. **Commit**: Write concise, conventional commit messages:
   - `feat(player): add gapless crossfade support`
   - `fix(seek): smooth handle position during buffer underflow`
   - `docs(readme): clarify hotkey customization`
3. **Verify**: Run `pytest` to make sure all 39+ tests pass without errors.
4. **Push & Open PR**: Push to your fork and submit a Pull Request with a clear description of your changes and any relevant screenshots or GIFs.

<br/>

---

<br/>

## 🫡 &nbsp; Recognition

Every contributor to Ember is valued and documented. Substantial contributions will be credited in [CREDITS.md](CREDITS.md) and on the project's [README.md](README.md).

Thank you for helping keep the warm light burning! 🔥
