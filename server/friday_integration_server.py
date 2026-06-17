#!/usr/bin/env python3
"""
Friday Integration Server - Combined HTTP server for all OpenClaw integrations

Routes:
    POST /hooks/voice        - Receive voice commands from phone
    POST /api/sleep          - Set laptop brightness to 0
    POST /api/wakeup          - Restore laptop brightness
    POST /api/alarm/trigger  - Play alarm on laptop (+ phone)
    POST /api/alarm/snooze   - Snooze alarm
    POST /api/alarm/dismiss  - Dismiss alarm
    POST /api/alarm/schedule - Schedule alarm notification
    GET  /health             - Health check

Usage:
    python3 friday_integration_server.py

Or as systemd service:
    systemctl --user enable ~/.config/systemd/user/friday-integration.service

Requires:
    - Python 3.8+
    - xrandr OR ddcutil (for brightness control)
    - paplay/aplay (for alarm sounds)
    - sherpa-onnx (optional, for transcription)
"""

import os
import sys
import json
import time
import base64
import subprocess
import threading
import logging
import webbrowser
from pathlib import Path
from http.server import HTTPServer, BaseHTTPRequestHandler
from urllib.parse import urlparse, parse_qs
from datetime import datetime
from typing import Optional
import argparse

from spotify_handler import SpotifyHandler

# ── Configuration ─────────────────────────────────────────────

PORT = int(os.environ.get('FRIDAY_PORT', 41263))
GATEWAY_PORT = int(os.environ.get('GATEWAY_PORT', 41262))
MAX_AUDIO_SIZE = 10 * 1024 * 1024
TOKEN_FILE = Path.home() / '.friday' / '.hook_token'


def load_hook_token() -> Optional[str]:
    """Load auth token from env or a local file; returns None in unauthenticated mode."""
    env_token = os.environ.get('OPENCLAW_HOOK_TOKEN', '').strip()
    if env_token:
        return env_token

    try:
        if TOKEN_FILE.exists():
            token = TOKEN_FILE.read_text(encoding='utf-8').strip()
            if token:
                return token
    except Exception as e:
        logging.warning(f"Could not read token file {TOKEN_FILE}: {e}")

    return None

# Directories
RECORDINGS_DIR = Path.home() / '.friday' / 'recordings'
LOGS_DIR = Path.home() / '.friday' / 'logs'
RECORDINGS_DIR.mkdir(parents=True, exist_ok=True)
LOGS_DIR.mkdir(parents=True, exist_ok=True)

# Default brightness
DEFAULT_BRIGHTNESS = 50
BRIGHTNESS_FILE = LOGS_DIR / 'last_brightness'

# Alarm
ALARM_SOUNDS = [
    "/usr/share/sounds/gnome/default/alerts/bark.ogg",
    "/usr/share/sounds/freedesktop/stereo/alarm-clock-elapsed.oga",
    "/usr/share/sounds/deepin/stereo/message.ogg",
]
ALARM_SOUND = None
for sound in ALARM_SOUNDS:
    if Path(sound).exists():
        ALARM_SOUND = sound
        break

# ── Logging Setup ────────────────────────────────────────────

log_file = LOGS_DIR / 'friday_server.log'
logging.basicConfig(
    level=logging.INFO,
    format='[%(asctime)s] %(levelname)s: %(message)s',
    datefmt='%Y-%m-%d %H:%M:%S',
    handlers=[
        logging.FileHandler(log_file),
        logging.StreamHandler(sys.stdout)
    ]
)
logger = logging.getLogger('friday')
HOOK_TOKEN = load_hook_token()
if HOOK_TOKEN is None:
    logging.warning("No auth token found — running in unauthenticated mode. "
                    "Set OPENCLAW_HOOK_TOKEN env var or create ~/.friday/.hook_token")

# ── Global State ─────────────────────────────────────────────

_current_alarm = None
_alarm_stop_event = threading.Event()
_alarm_lock = threading.RLock()

_spotify = SpotifyHandler()
_spotify.start_polling()


# ── Utility Functions ───────────────────────────────────────

def send_to_gateway(text: str):
    """Send a message to OpenClaw gateway via webhook"""
    try:
        import urllib.request
        import urllib.parse
        
        payload = json.dumps({
            'text': text,
            'mode': 'now',
            'source': 'friday_integration'
        }).encode()
        
        req = urllib.request.Request(
            f'http://127.0.0.1:{GATEWAY_PORT}/hooks/wake',
            data=payload,
            headers={'Content-Type': 'application/json'},
            method='POST'
        )
        
        if HOOK_TOKEN:
            req.add_header('Authorization', f'Bearer {HOOK_TOKEN}')
        
        with urllib.request.urlopen(req, timeout=5) as response:
            return response.status == 200
    except Exception as e:
        logger.error(f"Failed to send to gateway: {e}")
        return False


def find_display() -> Optional[str]:
    """Find primary display: respects DISPLAY_OUTPUT env var, falls back to xrandr query."""
    env_output = os.environ.get('DISPLAY_OUTPUT', '').strip()
    if env_output:
        return env_output
    try:
        result = subprocess.run(
            ['xrandr', '--query'],
            capture_output=True,
            text=True,
            timeout=5
        )
        for line in result.stdout.split('\n'):
            if ' connected' in line:
                return line.split()[0]
    except Exception:
        pass
    return os.environ.get('DISPLAY_OUTPUT', 'eDP-1')


def set_brightness_xrandr(level: int):
    """Set brightness with xrandr (0-100)"""
    display = find_display()
    if not display:
        logger.error("No display found")
        return False
    
    try:
        level = max(0, min(100, level))
        brightness = level / 100.0
        subprocess.run(
            ['xrandr', '--output', display, '--brightness', str(brightness)],
            capture_output=True,
            timeout=5
        )
        logger.info(f"Set {display} brightness to {level}%")
        return True
    except Exception as e:
        logger.error(f"xrandr error: {e}")
        return False


def set_brightness(level: int) -> bool:
    """Set screen brightness"""
    if level > 0:
        BRIGHTNESS_FILE.write_text(str(level))
    return set_brightness_xrandr(level)


def restore_brightness():
    """Restore brightness from saved value"""
    try:
        level = int(BRIGHTNESS_FILE.read_text().strip())
    except:
        level = DEFAULT_BRIGHTNESS
    return set_brightness(level)


def find_player():
    """Find available audio player"""
    for player in ['paplay', 'aplay', 'ffplay']:
        try:
            subprocess.run([player, '--version'], capture_output=True, timeout=1)
            return player
        except:
            continue
    return None


def play_sound(sound_file: str, loop: bool = False):
    """Play sound file"""
    player = find_player()
    if not player:
        return False
    
    if player == 'ffplay':
        cmd = ['ffplay', '-nodisp', '-autoexit', sound_file]
    elif player == 'paplay':
        cmd = ['paplay', sound_file]
    else:
        cmd = ['aplay', sound_file]
    
    try:
        if loop:
            while not _alarm_stop_event.is_set():
                subprocess.run(cmd, capture_output=True, timeout=30)
        else:
            subprocess.run(cmd, capture_output=True, timeout=30)
        return True
    except:
        return False


def speak(text: str):
    """Speak text using TTS"""
    try:
        subprocess.run(['espeak', text], capture_output=True, timeout=10)
        return True
    except:
        pass
    
    try:
        subprocess.run(['sherpa-onnx-tts', '--text', text], capture_output=True, timeout=10)
        return True
    except:
        pass
    
    return False


def start_alarm_loop(alarm_id: str, label: str):
    """Start alarm in background"""
    global _current_alarm
    
    with _alarm_lock:
        stop_alarm_loop()
        _alarm_stop_event.clear()
        
        message = f"Time to wake up. {label}" if label else "Time to wake up"
        
        def alarm_thread():
            speak(message)
            if ALARM_SOUND:
                play_sound(ALARM_SOUND, loop=True)
            else:
                while not _alarm_stop_event.is_set():
                    speak("Wake up")
                    time.sleep(3)
        
        thread = threading.Thread(target=alarm_thread, daemon=True)
        thread.start()
        
        _current_alarm = {
            'id': alarm_id,
            'label': label,
            'thread': thread,
            'started': datetime.now()
        }
        
        logger.info(f"Alarm started: {alarm_id}")


def stop_alarm_loop():
    """Stop current alarm"""
    global _current_alarm
    
    with _alarm_lock:
        if _current_alarm:
            _alarm_stop_event.set()
            try:
                subprocess.run(['pkill', '-9', 'paplay'], capture_output=True, timeout=1)
            except:
                pass
            _current_alarm = None
            logger.info("Alarm stopped")


def prune_old_recordings(max_files: int = 100):
    """Keep the recordings directory bounded."""
    try:
        recordings = sorted(
            RECORDINGS_DIR.glob('voice_*.wav'),
            key=lambda path: path.stat().st_mtime,
            reverse=True,
        )
        for stale_file in recordings[max_files:]:
            stale_file.unlink(missing_ok=True)
    except Exception as exc:
        logger.warning("Failed to prune recordings: %s", exc)


def transcribe_dummy(audio_path: str) -> str:
    """Dummy transcription - just save and return placeholder"""
    # In production, call whisper or sherpa-onnx here
    return f"[Audio received: {Path(audio_path).name}]"


# ── HTTP Handler ─────────────────────────────────────────────

class FridayHandler(BaseHTTPRequestHandler):
    """Main HTTP handler for all Friday endpoints"""
    
    def log_message(self, format, *args):
        logger.info(f"{self.client_address[0]} - {format % args}")
    
    def _json_response(self, code: int, data: dict):
        self.send_response(code)
        self.send_header('Content-Type', 'application/json')
        self.end_headers()
        self.wfile.write(json.dumps(data).encode())
    
    def _verify_auth(self):
        """Check authorization if token is set"""
        if not HOOK_TOKEN:
            return True
        auth = self.headers.get('Authorization', '')
        return auth == f"Bearer {HOOK_TOKEN}"
    
    def do_POST(self):
        path = urlparse(self.path).path
        
        if not self._verify_auth():
            self._json_response(401, {'error': 'Unauthorized'})
            return
        
        content_len = int(self.headers.get('Content-Length', 0))
        if content_len > MAX_AUDIO_SIZE:
            self._json_response(413, {'error': 'Request too large'})
            return

        body = self.rfile.read(content_len)
        
        try:
            payload = json.loads(body) if body else {}
        except json.JSONDecodeError:
            self._json_response(400, {'error': 'Malformed JSON'})
            return
        
        # Route handlers
        handlers = {
            '/hooks/voice': self._handle_voice,
            '/api/sleep': self._handle_sleep,
            '/api/wakeup': self._handle_wakeup,
            '/api/alarm/trigger': self._handle_alarm_trigger,
            '/api/alarm/snooze': self._handle_alarm_snooze,
            '/api/alarm/dismiss': self._handle_alarm_dismiss,
            '/api/alarm/schedule': self._handle_alarm_schedule,
        }
        
        handler = handlers.get(path)
        if handler:
            handler(payload)
        else:
            self._json_response(404, {'error': 'Not found', 'path': path})
    
    def _handle_voice(self, payload: dict):
        """Handle voice command from phone"""
        audio_b64 = payload.get('audio', '')
        timestamp = payload.get('timestamp', datetime.now().isoformat())
        
        if not audio_b64:
            self._json_response(400, {'error': 'No audio data'})
            return
        
        # Save audio
        audio_path = RECORDINGS_DIR / (
            f"voice_{datetime.now().strftime('%Y%m%d_%H%M%S_%f')}.wav"
        )
        try:
            audio_bytes = base64.b64decode(audio_b64, validate=True)
            if len(audio_bytes) > MAX_AUDIO_SIZE:
                self._json_response(413, {'error': 'Audio too large'})
                return
            with open(audio_path, 'wb') as f:
                f.write(audio_bytes)
            prune_old_recordings()
            logger.info(f"Saved audio: {audio_path}")
        except ValueError:
            self._json_response(400, {'error': 'Invalid base64 audio'})
            return
        except Exception as e:
            logger.error(f"Failed to save audio: {e}")
            self._json_response(500, {'error': 'Failed to save audio'})
            return
        
        # Transcribe (dummy for now - replace with actual transcription)
        transcription = transcribe_dummy(str(audio_path))
        logger.info(f"Transcription: {transcription}")
        
        # Send to Friday
        message = f'Daddy said: "{transcription}" via voice from phone.'
        send_to_gateway(message)
        
        self._json_response(200, {
            'success': True,
            'transcription': transcription,
            'audio_path': str(audio_path)
        })
    
    def _handle_sleep(self, payload: dict):
        """Handle sleep mode"""
        try:
            brightness = int(payload.get('brightness', 0))
        except (TypeError, ValueError):
            self._json_response(400, {'error': 'Brightness must be an integer'})
            return
        
        # Save current brightness before dimming
        try:
            current = 50  # Default
            with open('/tmp/.brightness_backup', 'w') as f:
                f.write(str(current))
        except:
            pass
        
        success = set_brightness(brightness)
        
        if success:
            # Notify Friday
            send_to_gateway(f"Sleep mode activated. Laptop brightness set to {brightness}%.")
        
        self._json_response(200 if success else 500, {
            'success': success,
            'action': 'sleep',
            'brightness': brightness
        })
    
    def _handle_wakeup(self, payload: dict):
        """Handle wakeup"""
        brightness = payload.get('brightness')
        
        if brightness is None:
            success = restore_brightness()
        else:
            try:
                brightness = int(brightness)
            except (TypeError, ValueError):
                self._json_response(400, {'error': 'Brightness must be an integer'})
                return
            success = set_brightness(brightness)
        
        self._json_response(200, {
            'success': success,
            'action': 'wakeup'
        })
    
    def _handle_alarm_trigger(self, payload: dict):
        """Handle alarm trigger"""
        alarm_id = payload.get('alarm_id', 'unknown')
        label = payload.get('label', '')
        
        start_alarm_loop(alarm_id, label)

        self._json_response(200, {
            'status': 'started',
            'success': True,
            'alarm_id': alarm_id,
            'action': 'trigger'
        })
    
    def _handle_alarm_snooze(self, payload: dict):
        """Handle snooze"""
        alarm_id = payload.get('alarm_id', '')
        stop_alarm_loop()
        
        self._json_response(200, {
            'success': True,
            'alarm_id': alarm_id,
            'action': 'snooze',
            'message': 'Snoozed for 5 minutes'
        })
    
    def _handle_alarm_dismiss(self, payload: dict):
        """Handle dismiss"""
        alarm_id = payload.get('alarm_id', '')
        stop_alarm_loop()
        
        self._json_response(200, {
            'success': True,
            'alarm_id': alarm_id,
            'action': 'dismiss'
        })
    
    def _handle_alarm_schedule(self, payload: dict):
        """Handle alarm schedule notification"""
        alarm_id = payload.get('alarm_id', '')
        label = payload.get('label', '')
        hour = payload.get('hour', 0)
        minute = payload.get('minute', 0)
        
        logger.info(f"Alarm {alarm_id} scheduled for {hour}:{minute:02d}")
        
        self._json_response(200, {
            'success': True,
            'alarm_id': alarm_id,
            'action': 'schedule',
            'time': f'{hour:02d}:{minute:02d}'
        })
    
    def do_GET(self):
        """Health check and Spotify endpoints"""
        parsed = urlparse(self.path)
        path = parsed.path
        qs = parse_qs(parsed.query)

        if path == '/health':
            player = find_player()
            try:
                recording_count = len(list(RECORDINGS_DIR.glob('*.wav')))
            except Exception:
                recording_count = -1
            self._json_response(200, {
                'status': 'ok',
                'service': 'friday_integration',
                'port': PORT,
                'alarm_active': _current_alarm is not None,
                'token_loaded': HOOK_TOKEN is not None,
                'recording_count': recording_count,
                'audio_player': player,
                'sound_file': ALARM_SOUND
            })
        elif path == '/stop-alarm':
            stop_alarm_loop()
            self._json_response(200, {'success': True, 'action': 'stop'})
        elif path == '/api/spotify/now-playing':
            self._json_response(200, _spotify.get_now_playing())
        elif path == '/api/spotify/auth':
            if not _spotify.is_configured():
                self._json_response(503, {'error': 'Spotify credentials not configured. Run setup.sh first.'})
                return
            auth_url = _spotify.get_auth_url()
            try:
                webbrowser.open(auth_url)
            except Exception:
                pass
            body = (
                f'<html><body>'
                f'<p>Opening Spotify login...</p>'
                f'<p>If browser did not open: <a href="{auth_url}">{auth_url}</a></p>'
                f'</body></html>'
            ).encode()
            self.send_response(200)
            self.send_header('Content-Type', 'text/html')
            self.end_headers()
            self.wfile.write(body)
        elif path == '/api/spotify/callback':
            code_list = qs.get('code')
            error_list = qs.get('error')
            if error_list:
                error = error_list[0]
                body = f'<html><body><p>Auth failed: {error}</p></body></html>'.encode()
                self.send_response(400)
                self.send_header('Content-Type', 'text/html')
                self.end_headers()
                self.wfile.write(body)
                return
            if not code_list:
                body = b'<html><body><p>No code received</p></body></html>'
                self.send_response(400)
                self.send_header('Content-Type', 'text/html')
                self.end_headers()
                self.wfile.write(body)
                return
            success = _spotify.handle_callback(code_list[0])
            if success:
                body = b'<html><body><h2>&#x2705; Spotify connected!</h2><p>You can close this tab. The app will now show now-playing info.</p></body></html>'
                self.send_response(200)
            else:
                body = b'<html><body><p>Token exchange failed. Check server logs.</p></body></html>'
                self.send_response(500)
            self.send_header('Content-Type', 'text/html')
            self.end_headers()
            self.wfile.write(body)
        else:
            self._json_response(404, {'error': 'Not found'})


# ── Main ─────────────────────────────────────────────────────

def run_server(port: int = PORT):
    """Run HTTP server"""
    httpd = HTTPServer(('', port), FridayHandler)
    logger.info(f"Friday Integration Server on port {port}")
    logger.info(f"Endpoints:")
    logger.info(f"  POST /hooks/voice - Voice commands")
    logger.info(f"  POST /api/sleep - Sleep mode")
    logger.info(f"  POST /api/wakeup - Wake up")
    logger.info(f"  POST /api/alarm/* - Alarm sync")
    logger.info(f"  GET  /health - Health check")
    
    try:
        httpd.serve_forever()
    except KeyboardInterrupt:
        logger.info("Shutting down...")
        stop_alarm_loop()
        httpd.shutdown()


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description='Friday Integration Server')
    parser.add_argument('--port', type=int, default=PORT, help='Port to listen on')
    args = parser.parse_args()
    
    run_server(args.port)
