"""
doctor.py
Environment diagnostics for bug reports.

For a yt-dlp-backed player, "which yt-dlp version" is the first question in
every report, and "how old is it" is usually the answer. This prints both.
"""

from __future__ import annotations

import platform
import shutil
import sys
from pathlib import Path
from typing import List

from .config import APP_NAME, STREAM_CACHE_TTL_S, YTDLP_MAX_AGE_DAYS
from .stream import BASE_OPTIONS, ytdlp_age_days, ytdlp_version

LOG_FILENAME = "ember.log"


def log_path() -> str:
    """Where the rotating log lives, matching what app.main() configures."""
    try:
        from PyQt6.QtCore import QStandardPaths

        base = QStandardPaths.writableLocation(
            QStandardPaths.StandardLocation.AppDataLocation
        )
    except Exception:  # noqa: BLE001 - Qt missing is itself a diagnosis
        base = ""
    return str(Path(base or ".") / LOG_FILENAME)


def _qt_version() -> str:
    try:
        from PyQt6.QtCore import PYQT_VERSION_STR, QT_VERSION_STR
    except Exception:  # noqa: BLE001
        return "PyQt6 not importable"
    return f"Qt {QT_VERSION_STR} / PyQt {PYQT_VERSION_STR}"


def _ffmpeg_version() -> str:
    exe = shutil.which("ffmpeg")
    if not exe:
        return "not found on PATH"
    return exe


def collect() -> List[str]:
    """Diagnostic lines, in the order a bug report needs them."""
    version = ytdlp_version()
    age = ytdlp_age_days(version)
    if age is None:
        age_line = "age unknown"
    else:
        age_line = f"{age} days old"
        if age > YTDLP_MAX_AGE_DAYS:
            age_line += (
                f"  <-- past the {YTDLP_MAX_AGE_DAYS}-day budget; "
                "run: python -m pip install -U yt-dlp"
            )

    return [
        f"{APP_NAME} doctor",
        f"python       : {sys.version.split()[0]} ({platform.machine()})",
        f"os           : {platform.system()} {platform.release()} ({platform.version()})",
        f"qt           : {_qt_version()}",
        f"yt-dlp       : {version} ({age_line})",
        f"audio format : {BASE_OPTIONS['format']}",
        f"stream cache : {STREAM_CACHE_TTL_S}s TTL",
        f"ffmpeg       : {_ffmpeg_version()}",
        f"log          : {log_path()}",
    ]


def main() -> int:
    """Print diagnostics and exit."""
    for line in collect():
        print(line)
    return 0