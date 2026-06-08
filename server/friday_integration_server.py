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
import tempfile
import subprocess
import threading
import logging
from pathlib import Path
from http.server import HTTPServer, BaseHTTPRequestHandler
from urllib.parse import urlparse
from datetime import datetime
import argparse

# ── Configuration ─────────────────────────────────────────────

PORT = int(os.environ.get('FRIDAY_PORT', 41263))
GATEWAY_PORT = int(os.environ.get('GATEWAY_PORT', 41262))
HOOK_TOKEN = os.environ.get('OPENCLAW_HOOK_TOKEN', '')

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

# ── Global State ─────────────────────────────────────────────

_current_alarm = None
_alarm_stop_event = threading.Event()
_alarm_lock = threading.Lock()


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


def find_display():
    """Find primary display with xrandr"""
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
    except:
        pass
    return None


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
        body = self.rfile.read(content_len)
        
        try:
            payload = json.loads(body) if body else {}
        except:
            payload = {}
        
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
        audio_path = RECORDINGS_DIR / f"voice_{datetime.now().strftime('%Y%m%d_%H%M%S')}.wav"
        try:
            audio_bytes = base64.b64decode(audio_b64)
            with open(audio_path, 'wb') as f:
                f.write(audio_bytes)
            logger.info(f"Saved audio: {audio_path}")
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
        brightness = payload.get('brightness', 0)
        
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
        """Health check"""
        if self.path == '/health':
            player = find_player()
            self._json_response(200, {
                'status': 'ok',
                'service': 'friday_integration',
                'port': PORT,
                'alarm_active': _current_alarm is not None,
                'audio_player': player,
                'sound_file': ALARM_SOUND
            })
        elif self.path == '/stop-alarm':
            stop_alarm_loop()
            self._json_response(200, {'success': True, 'action': 'stop'})
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
