"""
models.py
Data shapes shared across Ember.
"""

from __future__ import annotations

from dataclasses import asdict, dataclass
from typing import Any, Dict, Optional


@dataclass
class Song:
    """One playable track and the metadata needed to render and stream it."""

    video_id: str
    title: str
    artist: str
    duration: str = ""
    artwork_url: str = ""
    stream_url: Optional[str] = None

    @property
    def key(self) -> str:
        """Unique track identifier."""
        return self.video_id

    @property
    def byline(self) -> str:
        """Normalized artist display line."""
        return self.artist or "unknown artist"

    def is_same_as(self, other: Optional["Song"]) -> bool:
        """Compare identity across tracks."""
        return other is not None and other.video_id == self.video_id

    def to_dict(self) -> Dict[str, Any]:
        """Convert track to serializable dictionary."""
        return asdict(self)

    @classmethod
    def from_dict(cls, data: Dict[str, Any]) -> "Song":
        """Reconstruct a Song from a dictionary representation."""
        if not data:
            data = {}
        return cls(
            video_id=str(data.get("video_id", "")),
            title=str(data.get("title", "untitled")),
            artist=str(data.get("artist", "unknown artist")),
            duration=str(data.get("duration", "")),
            artwork_url=str(data.get("artwork_url", "")),
            stream_url=data.get("stream_url"),
        )

    def __str__(self) -> str:
        return f"{self.title} — {self.byline}"