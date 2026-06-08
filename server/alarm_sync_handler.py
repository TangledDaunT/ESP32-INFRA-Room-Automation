#!/usr/bin/env python3
"""
Alarm Sync Handler - HTTP server for synchronized alarms

Receives POST /api/alarm/trigger - Play alarm on laptop
Receives POST /api/alarm/snooze - Snooze alarm
Receives POST /api/alarm/dismiss - Dismiss alarm
Receives POST /api/alarm/schedule - Schedule alarm notification

Usage:
    python3 alarm_sync_handler.py --server

Requires:
    - Python 3.8+
    - paplay or aplay (for audio playback)
    - Flask (if running as server): pip install flask
"""

import os
import sys
import json
import time
import subprocess
import threading
import logging
from pathlib import Path
from http.server import HTTPServer, BaseHTTPRequestHandler
from urllib.parse import urlparse
from datetime import datetime
import argparse

# Configuration
ALARM_SOUND = os.environ.get('ALARM_SOUND', "/usr/share/sounds/gnome/default/alerts/bark.ogg")
BACKUP_SOUNDS = [
    "/usr/share/sounds/freedesktop/stereo/alarm-clock-elapsed.oga",
    "/usr/share/sounds/deepin/stereo/message.ogg",
    "/usr/share/sounds/ubuntu/notifications/Positive.ogg",
    "/usr/share/sounds/gnome/default/alerts/bark.ogg",
]

# Try to find a working sound file
for sound in [ALARM_SOUND] + BACKUP_SOUNDS:
    if Path(sound).exists():
        ALARM_SOUND = sound
        break
else:
    ALARM_SOUND = None
    print("Warning: No alarm sound file found")

# Logging setup
logging.basicConfig(
    level=logging.INFO,
    format='[%(asctime)s] %(levelname)s: %(message)s',
    datefmt='%Y-%m-%d %H:%M:%S'
)
logger = logging.getLogger('alarm_sync')

# Global alarm state
_current_alarm = None
_alarm_thread = None
_alarm_stop_event = threading.Event()


def find_sound_player():
    """Find available audio player"""
    players = [
        ('paplay', ['paplay']),
        ('aplay', ['aplay']),
        ('play', ['play']),  # SoX
        ('ffplay', ['ffplay', '-nodisp', '-autoexit']),
    ]
    
    for player, _ in players:
        try:
            result = subprocess.run(
                [player, '--version'],
                capture_output=True,
                timeout=1
            )
            # Some tools return non-zero on --version but still work
            return player
        except FileNotFoundError:
            continue
        except subprocess.TimeoutExpired:
            return player
    
    return None


def play_sound(sound_file: str, loop: bool = False) -> bool:
    """
    Play sound file using available player
    Returns True on success
    """
    player = find_sound_player()
    
    if not player:
        logger.error("No audio player found (tried: paplay, aplay, play, ffplay)")
        return False
    
    if player == 'paplay':
        cmd = ['paplay', sound_file]
    elif player == 'aplay':
        cmd = ['aplay', sound_file]
    elif player == 'play':
        cmd = ['play', '-q', sound_file]
    elif player == 'ffplay':
        cmd = ['ffplay', '-nodisp', '-autoexit', sound_file]
    else:
        return False
    
    try:
        if loop:
            # Run in loop
            global _alarm_stop_event
            while not _alarm_stop_event.is_set():
                result = subprocess.run(
                    cmd,
                    capture_output=True,
                    timeout=30
                )
                if result.returncode != 0:
                    logger.warning(f"Sound player error: {result.stderr}")
                    break
        else:
            result = subprocess.run(cmd, capture_output=True, timeout=30)
            if result.returncode == 0:
                return True
            else:
                logger.warning(f"Sound player error: {result.stderr}")
                return False
                
    except subprocess.TimeoutExpired:
        logger.warning("Sound playback timeout")
        return False
    except Exception as e:
        logger.error(f"Sound playback error: {e}")
        return False


def speak_tts(message: str) -> bool:
    """
    Speak message using TTS if available
    Uses sherpa-onnx TTS or espeak as fallback
    """
    # Try sherpa-onnx TTS first
    try:
        import shutil
        tts_path = shutil.which('sherpa-onnx-tts')
        
        if tts_path:
            logger.info("Using sherpa-onnx TTS")
            result = subprocess.run(
                [tts_path, '--text', message],
                capture_output=True,
                timeout=30
            )
            if result.returncode == 0:
                return True
    except:
        pass
    
    # Fallback to espeak
    try:
        result = subprocess.run(
            ['espeak', message],
            capture_output=True,
            timeout=10
        )
        if result.returncode == 0:
            return True
    except:
        pass
    
    return False


def start_alarm(alarm_id: str, label: str = ""):
    """Start alarm loop in background thread"""
    global _alarm_thread, _alarm_stop_event, _current_alarm
    
    # Stop any existing alarm
    stop_alarm()
    
    _current_alarm = {
        'id': alarm_id,
        'label': label,
        'started_at': datetime.now().isoformat()
    }
    _alarm_stop_event.clear()
    
    def alarm_loop():
        global _alarm_stop_event
        logger.info(f"Alarm started: {alarm_id} ({label})")
        
        # Speak wakeup message
        message = f"Time to wake up. {label}" if label else "Time to wake up"
        speak_tts(message)
        
        # Play alarm sound in loop
        if ALARM_SOUND:
            play_sound(ALARM_SOUND, loop=True)
        else:
            # Fallback: speak periodically
            while not _alarm_stop_event.is_set():
                speak_tts("Wake up")
                time.sleep(3)
    
    _alarm_thread = threading.Thread(target=alarm_loop, daemon=True)
    _alarm_thread.start()
    
    logger.info(f"Alarm thread started for {alarm_id}")


def stop_alarm():
    """Stop current alarm"""
    global _alarm_thread, _alarm_stop_event, _current_alarm
    
    if _alarm_thread and _alarm_thread.is_alive():
        logger.info("Stopping alarm")
        _alarm_stop_event.set()
        
        # Stop paplay/aplay if running
        try:
            subprocess.run(['pkill', '-9', 'paplay'], capture_output=True, timeout=1)
        except:
            pass
        try:
            subprocess.run(['pkill', '-9', 'aplay'], capture_output=True, timeout=1)
        except:
            pass
        
        _alarm_thread.join(timeout=2)
        _current_alarm = None
        logger.info("Alarm stopped")
        return True
    else:
        logger.info("No active alarm")
        return False


class AlarmSyncHandler(BaseHTTPRequestHandler):
    """HTTP handler for alarm sync from phone"""
    
    def log_message(self, format, *args):
        """Custom logging"""
        logger.info(f"{self.address_string()} - {format % args}")
    
    def _send_json_response(self, status_code: int, data: dict):
        """Send JSON response"""
        self.send_response(status_code)
        self.send_header('Content-Type', 'application/json')
        self.end_headers()
        self.wfile.write(json.dumps(data).encode())
    
    def do_POST(self):
        """Handle POST requests"""
        parsed_path = urlparse(self.path)
        path = parsed_path.path
        
        # Read request body
        content_length = int(self.headers.get('Content-Length', 0))
        body = self.rfile.read(content_length)
        
        try:
            payload = json.loads(body) if body else {}
        except json.JSONDecodeError:
            payload = {}
        
        logger.info(f"POST {path} - Payload: {payload}")
        
        # Route to handler
        if path == '/api/alarm/trigger':
            self._handle_trigger(payload)
        elif path == '/api/alarm/dismiss':
            self._handle_dismiss(payload)
        elif path == '/api/alarm/snooze':
            self._handle_snooze(payload)
        elif path == '/api/alarm/schedule':
            self._handle_schedule(payload)
        else:
            self._send_json_response(404, {'error': 'Not found', 'path': path})
    
    def _handle_trigger(self, payload: dict):
        """Handle alarm trigger from phone"""
        alarm_id = payload.get('alarm_id', 'unknown')
        label = payload.get('label', '')
        
        logger.info(f"Alarm triggered: {alarm_id} ({label})")
        
        # Start alarm on laptop
        start_alarm(alarm_id, label)
        
        self._send_json_response(200, {
            'success': True,
            'alarm_id': alarm_id,
            'action': 'trigger',
            'message': f'Alarm triggered: {label}'
        })
    
    def _handle_dismiss(self, payload: dict):
        """Handle alarm dismiss"""
        alarm_id = payload.get('alarm_id', 'unknown')
        
        logger.info(f"Alarm dismissed: {alarm_id}")
        
        # Stop alarm on laptop
        stopped = stop_alarm()
        
        self._send_json_response(200, {
            'success': True,
            'alarm_id': alarm_id,
            'action': 'dismiss',
            'was_stopped': stopped
        })
    
    def _handle_snooze(self, payload: dict):
        """Handle alarm snooze"""
        alarm_id = payload.get('alarm_id', 'unknown')
        
        logger.info(f"Alarm snoozed: {alarm_id}")
        
        # Stop alarm temporarily
        stop_alarm()
        
        self._send_json_response(200, {
            'success': True,
            'alarm_id': alarm_id,
            'action': 'snooze',
            'message': 'Alarm snoozed for 5 minutes'
        })
    
    def _handle_schedule(self, payload: dict):
        """Handle alarm scheduled notification"""
        alarm_id = payload.get('alarm_id', 'unknown')
        label = payload.get('label', '')
        hour = payload.get('hour', 0)
        minute = payload.get('minute', 0)
        
        logger.info(f"Alarm scheduled: {alarm_id} at {hour:02d}:{minute:02d}")
        
        self._send_json_response(200, {
            'success': True,
            'alarm_id': alarm_id,
            'action': 'schedule',
            'scheduled_for': f'{hour:02d}:{minute:02d}',
            'message': f'Alarm scheduled at {hour:02d}:{minute:02d}'
        })
    
    def do_GET(self):
        """Handle GET requests - health check"""
        if self.path == '/health':
            active = _current_alarm is not None
            player = find_sound_player()
            
            self._send_json_response(200, {
                'status': 'ok',
                'service': 'alarm_sync_handler',
                'active_alarm': _current_alarm if active else None,
                'sound_available': ALARM_SOUND is not None and Path(ALARM_SOUND).exists(),
                'sound_player': player
            })
        elif self.path == '/api/alarm/stop':
            # Convenience endpoint to stop alarm via browser/curl
            stopped = stop_alarm()
            self._send_json_response(200, {
                'success': True,
                'was_stopped': stopped
            })
        else:
            self._send_json_response(404, {'error': 'Not found'})


def run_server(port: int = 8080):
    """Run the HTTP server"""
    server_address = ('', port)
    httpd = HTTPServer(server_address, AlarmSyncHandler)
    logger.info(f"Alarm Sync Handler running on port {port}")
    logger.info(f"Alarm sound: {ALARM_SOUND}")
    
    try:
        httpd.serve_forever()
    except KeyboardInterrupt:
        logger.info("Shutting down...")
        stop_alarm()
        httpd.shutdown()


def main():
    parser = argparse.ArgumentParser(description='Alarm Sync Handler')
    parser.add_argument('--server', action='store_true', help='Run as HTTP server')
    parser.add_argument('--port', type=int, default=8080, help='Server port')
    parser.add_argument('--test', action='store_true', help='Test alarm (play and stop after 5s)')
    args = parser.parse_args()
    
    if args.server:
        run_server(args.port)
    elif args.test:
        print("Testing alarm...")
        start_alarm('test', 'Test Alarm')
        time.sleep(5)
        stop_alarm()
        print("Test complete")
    else:
        parser.print_help()


if __name__ == '__main__':
    main()
