# server/spotify_handler.py
import json
import os
import time
import threading
import webbrowser
from pathlib import Path
from urllib.parse import urlencode, urlparse, parse_qs
import requests

SPOTIFY_API_BASE = "https://api.spotify.com/v1"
SPOTIFY_AUTH_URL = "https://accounts.spotify.com/authorize"
SPOTIFY_TOKEN_URL = "https://accounts.spotify.com/api/token"
SCOPES = "user-read-currently-playing user-read-playback-state"

FRIDAY_DIR = Path.home() / ".friday"
CREDS_FILE = FRIDAY_DIR / "spotify_credentials.json"
TOKEN_FILE = FRIDAY_DIR / "spotify_token.json"


class SpotifyHandler:
    def __init__(self, redirect_uri: str = "http://localhost:41263/api/spotify/callback"):
        self._redirect_uri = redirect_uri
        self._creds = self._load_credentials()
        self._token_data = self._load_token()
        self._cached_track = {"playing": False}
        self._lock = threading.Lock()
        self._poll_thread = None
        self._running = False

    # ── Credential loading ──────────────────────────────────────────────────

    def _load_credentials(self):
        """Load client_id + client_secret from file or env vars."""
        client_id = os.environ.get("SPOTIFY_CLIENT_ID")
        client_secret = os.environ.get("SPOTIFY_CLIENT_SECRET")
        if client_id and client_secret:
            return {"client_id": client_id, "client_secret": client_secret}
        if CREDS_FILE.exists():
            try:
                return json.loads(CREDS_FILE.read_text())
            except Exception:
                pass
        return {}

    def _load_token(self):
        if TOKEN_FILE.exists():
            try:
                return json.loads(TOKEN_FILE.read_text())
            except Exception:
                pass
        return {}

    def _save_token(self, data: dict):
        FRIDAY_DIR.mkdir(parents=True, exist_ok=True)
        data["expires_at"] = time.time() + data.get("expires_in", 3600) - 60
        TOKEN_FILE.write_text(json.dumps(data, indent=2))
        self._token_data = data

    # ── OAuth flow ──────────────────────────────────────────────────────────

    def is_configured(self) -> bool:
        return bool(self._creds.get("client_id") and self._creds.get("client_secret"))

    def is_authenticated(self) -> bool:
        return bool(self._token_data.get("access_token"))

    def get_auth_url(self) -> str:
        if not self.is_configured():
            return ""
        params = {
            "client_id": self._creds["client_id"],
            "response_type": "code",
            "redirect_uri": self._redirect_uri,
            "scope": SCOPES,
        }
        return f"{SPOTIFY_AUTH_URL}?{urlencode(params)}"

    def handle_callback(self, code: str) -> bool:
        """Exchange auth code for tokens. Returns True on success."""
        try:
            resp = requests.post(
                SPOTIFY_TOKEN_URL,
                data={
                    "grant_type": "authorization_code",
                    "code": code,
                    "redirect_uri": self._redirect_uri,
                },
                auth=(self._creds["client_id"], self._creds["client_secret"]),
                timeout=10,
            )
            if resp.status_code == 200:
                self._save_token(resp.json())
                return True
        except Exception as e:
            print(f"[Spotify] Token exchange error: {e}")
        return False

    def _refresh_token(self) -> bool:
        refresh_token = self._token_data.get("refresh_token")
        if not refresh_token:
            return False
        try:
            resp = requests.post(
                SPOTIFY_TOKEN_URL,
                data={
                    "grant_type": "refresh_token",
                    "refresh_token": refresh_token,
                },
                auth=(self._creds["client_id"], self._creds["client_secret"]),
                timeout=10,
            )
            if resp.status_code == 200:
                data = resp.json()
                # Preserve refresh_token if not returned in response
                if "refresh_token" not in data:
                    data["refresh_token"] = refresh_token
                self._save_token(data)
                return True
        except Exception as e:
            print(f"[Spotify] Refresh error: {e}")
        return False

    def _get_access_token(self):
        """Return valid access token, refreshing if needed."""
        if not self._token_data:
            return None
        expires_at = self._token_data.get("expires_at", 0)
        if time.time() >= expires_at:
            if not self._refresh_token():
                return None
        return self._token_data.get("access_token")

    # ── Polling ─────────────────────────────────────────────────────────────

    def _poll_once(self):
        token = self._get_access_token()
        if not token:
            return
        try:
            resp = requests.get(
                f"{SPOTIFY_API_BASE}/me/player/currently-playing",
                headers={"Authorization": f"Bearer {token}"},
                timeout=5,
            )
            if resp.status_code == 204 or resp.status_code == 200 and not resp.text.strip():
                # Nothing playing
                with self._lock:
                    self._cached_track = {"playing": False}
                return
            if resp.status_code == 200:
                data = resp.json()
                item = data.get("item")
                if not item:
                    with self._lock:
                        self._cached_track = {"playing": False}
                    return
                images = item.get("album", {}).get("images", [])
                art_url = images[0]["url"] if images else None
                artists = ", ".join(a["name"] for a in item.get("artists", []))
                track = {
                    "playing": True,
                    "title": item.get("name", ""),
                    "artist": artists,
                    "album": item.get("album", {}).get("name", ""),
                    "albumArtUrl": art_url,
                    "progressMs": data.get("progress_ms", 0),
                    "durationMs": item.get("duration_ms", 1),
                    "isPlaying": data.get("is_playing", False),
                }
                with self._lock:
                    self._cached_track = track
        except Exception as e:
            print(f"[Spotify] Poll error: {e}")

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
        print("[Spotify] Polling started")

    def stop_polling(self):
        self._running = False

    def get_now_playing(self) -> dict:
        with self._lock:
            return dict(self._cached_track)
