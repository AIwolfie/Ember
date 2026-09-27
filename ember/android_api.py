import json
try:
    from ember.catalog import CatalogSource
    from ember.stream import StreamResolver
except ImportError:
    from catalog import CatalogSource
    from stream import StreamResolver

_catalog = CatalogSource()
_resolver = StreamResolver()

def search(query, filter_type=None):
    if filter_type == "all" or not filter_type:
        filter_type = None
    try:
        results = _catalog.search(query, filter_type=filter_type)
        mapped = [
            {
                "videoId": r.video_id,
                "title": r.title,
                "artist": r.artist,
                "duration": r.duration,
                "artworkUrl": r.artwork_url,
                "type": getattr(r, "type", "song")
            }
            for r in results
        ]

        if filter_type is None:
            artists = [m for m in mapped if m["type"] == "artist"]
            non_artists = [m for m in mapped if m["type"] != "artist"]
            exact_artists = [a for a in artists if a["title"].lower() == query.lower()]
            other_artists = [a for a in artists if a not in exact_artists]
            
            if exact_artists:
                mapped = exact_artists + other_artists + non_artists
            elif artists and any(q.lower() in a["title"].lower() for q in query.split() for a in artists):
                mapped = artists + non_artists

        return mapped
    except Exception as e:
        return [{"videoId": "error", "title": "Failed to search", "artist": str(e), "type": "error"}]

def similar(seed_id):
    results = _catalog.similar(seed_id)
    return [
        {
            "videoId": r.video_id,
            "title": r.title,
            "artist": r.artist,
            "duration": r.duration,
            "artworkUrl": r.artwork_url,
            "type": getattr(r, "type", "song")
        }
        for r in results
    ]

def get_stream_url(video_id):
    url, error, permanent = _resolver.resolve(video_id)
    return {
        "url": url,
        "error": str(error) if error else "",
        "permanent": permanent
    }

def get_home(recent_ids_str=""):
    recent_ids = recent_ids_str.split(",") if recent_ids_str else []
    mapped_sections = []

    # 1. Personalized Shelf
    if recent_ids:
        for seed_id in recent_ids[:1]:
            if not seed_id: continue
            try:
                similar_tracks = _catalog.similar(seed_id, limit=8)
                if similar_tracks:
                    mapped_sections.append({
                        "title": "Because you listened recently",
                        "tracks": [
                            {
                                "videoId": r.video_id,
                                "title": r.title,
                                "artist": r.artist,
                                "duration": r.duration,
                                "artworkUrl": r.artwork_url,
                                "type": getattr(r, "type", "song")
                            }
                            for r in similar_tracks
                        ]
                    })
                    break
            except Exception:
                pass # Fail silently, continue to the next block

    # 2. Trending Artists
    try:
        artists = _catalog.top_artists()
        if artists:
            mapped_sections.append({
                "title": "Popular Artists",
                "tracks": [
                    {
                        "videoId": r.video_id,
                        "title": r.title,
                        "artist": r.artist,
                        "duration": r.duration,
                        "artworkUrl": r.artwork_url,
                        "type": getattr(r, "type", "artist")
                    }
                    for r in artists
                ]
            })
    except Exception:
        pass

    # 3. YTM Generic Home
    try:
        sections = _catalog.home(limit=6)
        for sec in sections:
            mapped_tracks = [
                {
                    "videoId": r.video_id,
                    "title": r.title,
                    "artist": r.artist,
                    "duration": r.duration,
                    "artworkUrl": r.artwork_url,
                    "type": getattr(r, "type", "song")
                }
                for r in sec["tracks"]
            ]
            if mapped_tracks:
                mapped_sections.append({
                    "title": sec["title"],
                    "tracks": mapped_tracks
                })
    except Exception:
        pass

    # If completely empty due to full API outage, fallback to basic search
    if not mapped_sections:
        try:
            top = _catalog.search("top songs", limit=10)
            if top:
                mapped_sections.append({
                    "title": "Top Songs",
                    "tracks": [{"videoId": r.video_id, "title": r.title, "artist": r.artist, "duration": r.duration, "artworkUrl": r.artwork_url, "type": getattr(r, "type", "song")} for r in top]
                })
        except Exception:
            pass
            
        try:
            artists = _catalog.search("popular artists", limit=10)
            if artists:
                mapped_sections.append({
                    "title": "Suggested Artists",
                    "tracks": [{"videoId": r.video_id, "title": r.title, "artist": r.artist, "duration": r.duration, "artworkUrl": r.artwork_url, "type": getattr(r, "type", "artist")} for r in artists]
                })
        except Exception:
            pass

    # If completely empty still, return safe visual error structure
    if not mapped_sections:
         return json.dumps([{"title": "Offline or Failed to connect", "tracks": [], "error": "Could not connect to YT Music"}])

    return json.dumps(mapped_sections)

def get_artist_details(browse_id):
    details = _catalog.artist_details(browse_id)
    if not details: return "{}"
    def _map_list(songs_list, force_type="song"):
        return [
            {
                "videoId": r.video_id,
                "title": r.title,
                "artist": r.artist,
                "duration": r.duration,
                "artworkUrl": r.artwork_url,
                "type": getattr(r, "type", force_type)
            } for r in songs_list
        ]
    details["songs"] = _map_list(details.get("songs") or [], "song")
    details["albums"] = _map_list(details.get("albums") or [], "album")
    details["singles"] = _map_list(details.get("singles") or [], "album")
    return json.dumps(details)

def lyrics(video_id, title="", artist=""):
    return _catalog.lyrics(video_id, title=title, artist=artist)

def import_playlist(identifier):
    data = _catalog.import_playlist(identifier)
    data["tracks"] = [
        {
            "videoId": r.video_id,
            "title": r.title,
            "artist": r.artist,
            "duration": r.duration,
            "artworkUrl": r.artwork_url,
            "type": getattr(r, "type", "song")
        } for r in data["tracks"]
    ]
    return json.dumps(data)
