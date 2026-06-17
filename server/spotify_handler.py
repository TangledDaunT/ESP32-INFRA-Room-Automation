# server/spotify_handler.py
# Uses Last.fm API instead of Spotify — no OAuth needed, just an API key.
# Last.fm scrobbles from Spotify iOS automatically when connected in Spotify settings.
import threading
import time
import requests

LASTFM_API_BASE = "https://ws.audioscrobbler.com/2.0/"
LASTFM_API_KEY = "b274480a8ca566ecf0b898c66f2193ef"
LASTFM_USER = "shreyanshiscool"


class SpotifyHandler:
    """Polls Last.fm for the currently scrobbling track and exposes it
    via get_now_playing() in the same JSON schema the Flutter app expects."""

    def __init__(self):
        self._cached_track = {"playing": False}
        self._lock = threading.Lock()
        self._poll_thread = None
        self._running = False

    # ── Polling ─────────────────────────────────────────────────────────────

    def _poll_once(self):
        try:
            resp = requests.get(
                LASTFM_API_BASE,
                params={
                    "method": "user.getRecentTracks",
                    "user": LASTFM_USER,
                    "api_key": LASTFM_API_KEY,
                    "format": "json",
                    "limit": 1,
                },
                timeout=5,
            )
            if resp.status_code != 200:
                return

            data = resp.json()
            tracks = data.get("recenttracks", {}).get("track", [])
            if not tracks:
                with self._lock:
                    self._cached_track = {"playing": False}
                return

            track = tracks[0] if isinstance(tracks, list) else tracks
            # Last.fm marks currently-playing track with @attr.nowplaying == "true"
            now_playing = track.get("@attr", {}).get("nowplaying") == "true"

            if not now_playing:
                with self._lock:
                    self._cached_track = {"playing": False}
                return

            # Pick largest album art image (last in the list)
            images = track.get("image", [])
            art_url = None
            for img in reversed(images):
                url = img.get("#text", "")
                if url:
                    art_url = url
                    break

            result = {
                "playing": True,
                "title": track.get("name", ""),
                "artist": track.get("artist", {}).get("#text", ""),
                "album": track.get("album", {}).get("#text", ""),
                "albumArtUrl": art_url,
                # Last.fm doesn't expose progress — Flutter shows indeterminate bar
                "progressMs": 0,
                "durationMs": 0,
                "isPlaying": True,
            }
            with self._lock:
                self._cached_track = result

        except Exception as e:
            print(f"[LastFM] Poll error: {e}")

    def _poll_loop(self):
        while self._running:
            self._poll_once()
            time.sleep(3)

    def start_polling(self):
        if self._poll_thread and self._poll_thread.is_alive():
            return
        self._running = True
        self._poll_thread = threading.Thread(target=self._poll_loop, daemon=True)
        self._poll_thread.start()
        print(f"[LastFM] Polling started for user '{LASTFM_USER}'")

    def stop_polling(self):
        self._running = False

    def get_now_playing(self) -> dict:
        with self._lock:
            return dict(self._cached_track)

    # ── Stubs kept so friday_integration_server.py routes don't break ───────

    def is_configured(self) -> bool:
        return True

    def is_authenticated(self) -> bool:
        return True

    def get_auth_url(self) -> str:
        return ""

    def handle_callback(self, code: str) -> bool:
        return False
