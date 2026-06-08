#!/usr/bin/env python3
"""
Sleep Mode Handler - HTTP server for sleep mode integration

Receives POST /api/sleep to set laptop brightness
Receives POST /api/wakeup to restore normal brightness

Usage:
    python3 sleep_mode_handler.py --brightness 0  # Sleep
    python3 sleep_mode_handler.py --brightness 50 # Restore

Or run as server:
    python3 sleep_mode_handler.py --server

Requires:
    - Python 3.8+
    - ddcutil (for external monitors) OR xrandr (for laptop screen)
    - Flask (if running as server): pip install flask
"""

import os
import sys
import json
import argparse
import subprocess
import logging
from pathlib import Path
from http.server import HTTPServer, BaseHTTPRequestHandler
from urllib.parse import urlparse

# Configuration
DEFAULT_BRIGHTNESS = 50  # Default restored brightness (0-100)
BRIGHTNESS_FILE = Path("/tmp/friday_last_brightness")

# Logging setup
logging.basicConfig(
    level=logging.INFO,
    format='[%(asctime)s] %(levelname)s: %(message)s',
    datefmt='%Y-%m-%d %H:%M:%S'
)
logger = logging.getLogger('sleep_mode')


def find_display_output():
    """Find the primary display output using xrandr"""
    try:
        result = subprocess.run(
            ['xrandr', '--query'],
            capture_output=True,
            text=True,
            timeout=5
        )
        
        if result.returncode != 0:
            return None
        
        # Look for connected primary display
        for line in result.stdout.split('\n'):
            if ' connected primary' in line:
                # Extract display name (e.g., "eDP-1", "HDMI-1")
                return line.split()[0]
            elif ' connected' in line and 'primary' not in line:
                # Fallback to any connected display
                return line.split()[0]
        
        return None
        
    except Exception as e:
        logger.error(f"Failed to find display: {e}")
        return None


def set_brightness_xrandr(brightness: float):
    """
    Set brightness using xrandr
    brightness: 0.0 - 1.0 (0% - 100%)
    """
    display = find_display_output()
    
    if not display:
        logger.error("No display found with xrandr")
        return False
    
    try:
        # Clamp brightness to valid range
        xrandr_brightness = max(0.0, min(1.0, brightness / 100.0))
        
        result = subprocess.run(
            ['xrandr', '--output', display, '--brightness', str(xrandr_brightness)],
            capture_output=True,
            text=True,
            timeout=5
        )
        
        if result.returncode == 0:
            logger.info(f"Set {display} brightness to {brightness}%")
            return True
        else:
            logger.error(f"xrandr failed: {result.stderr}")
            return False
            
    except Exception as e:
        logger.error(f"xrandr error: {e}")
        return False


def set_brightness_ddcutil(brightness: int):
    """
    Set brightness using ddcutil (for external monitors with DDC/CI)
    brightness: 0 - 100
    """
    try:
        # Check if ddcutil is available
        result = subprocess.run(
            ['ddcutil', '--help'],
            capture_output=True,
            timeout=1
        )
        if result.returncode != 0:
            return False
    except FileNotFoundError:
        return False
    
    try:
        # Get display list
        result = subprocess.run(
            ['ddcutil', 'detect'],
            capture_output=True,
            text=True,
            timeout=5
        )
        
        if result.returncode != 0:
            logger.error("ddcutil detect failed")
            return False
        
        # Set brightness on all detected displays
        result = subprocess.run(
            ['ddcutil', 'setvcp', '10', str(brightness)],
            capture_output=True,
            text=True,
            timeout=10
        )
        
        if result.returncode == 0:
            logger.info(f"Set DDC brightness to {brightness}%")
            return True
        else:
            logger.error(f"ddcutil failed: {result.stderr}")
            return False
            
    except Exception as e:
        logger.error(f"ddcutil error: {e}")
        return False


def save_current_brightness():
    """Save current brightness before sleep"""
    # Use a default since we can't easily read xrandr brightness
    # In production, you might query xrandr or store a setting
    BRIGHTNESS_FILE.write_text(str(DEFAULT_BRIGHTNESS))
    logger.info(f"Saved current brightness: {DEFAULT_BRIGHTNESS}%")


def restore_brightness():
    """Restore brightness from saved value"""
    if BRIGHTNESS_FILE.exists():
        try:
            brightness = int(BRIGHTNESS_FILE.read_text().strip())
            set_brightness(brightness)
            logger.info(f"Restored brightness to {brightness}%")
            return True
        except Exception as e:
            logger.error(f"Failed to restore brightness: {e}")
    
    # Default fallback
    set_brightness(DEFAULT_BRIGHTNESS)
    return True


def set_brightness(brightness: int) -> bool:
    """
    Set screen brightness using available methods
    Returns True on success
    """
    brightness = max(0, min(100, brightness))  # Clamp to 0-100
    
    # Try ddcutil first (external monitors)
    if set_brightness_ddcutil(brightness):
        return True
    
    # Fall back to xrandr (laptop/internal displays)
    if set_brightness_xrandr(brightness):
        return True
    
    logger.error("Failed to set brightness with any available method")
    return False


class SleepModeHandler(BaseHTTPRequestHandler):
    """HTTP handler for sleep/wakeup commands from phone"""
    
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
        
        # Route to handler
        if path == '/api/sleep':
            self._handle_sleep(payload)
        elif path == '/api/wakeup':
            self._handle_wakeup(payload)
        else:
            self._send_json_response(404, {'error': 'Not found', 'path': path})
    
    def _handle_sleep(self, payload: dict):
        """Handle sleep mode request"""
        brightness = payload.get('brightness', 0)
        action = payload.get('action', 'sleep')
        
        logger.info(f"Sleep mode request: brightness={brightness}, action={action}")
        
        # Save current brightness before dimming
        save_current_brightness()
        
        # Set brightness
        success = set_brightness(brightness)
        
        if success:
            # Log the action
            logger.info(f"Sleep mode activated: brightness set to {brightness}%")
            
            self._send_json_response(200, {
                'success': True,
                'action': 'sleep',
                'brightness': brightness,
                'message': 'Sleep mode activated'
            })
        else:
            self._send_json_response(500, {
                'success': False,
                'error': 'Failed to set brightness'
            })
    
    def _handle_wakeup(self, payload: dict):
        """Handle wakeup request"""
        brightness = payload.get('brightness')
        action = payload.get('action', 'wakeup')
        
        logger.info(f"Wakeup request: brightness={brightness}, action={action}")
        
        # Use provided brightness or restore saved value
        if brightness is None:
            restore_brightness()
            target_brightness = DEFAULT_BRIGHTNESS
            source = 'saved'
        else:
            set_brightness(brightness)
            target_brightness = brightness
            source = 'provided'
        
        self._send_json_response(200, {
            'success': True,
            'action': 'wakeup',
            'brightness': target_brightness,
            'source': source,
            'message': 'Wakeup activated'
        })
    
    def do_GET(self):
        """Handle GET requests - health check"""
        if self.path == '/health':
            # Check available brightness methods
            methods = []
            
            # Check xrandr
            try:
                result = subprocess.run(['xrandr', '--version'], capture_output=True, timeout=2)
                if result.returncode == 0:
                    methods.append('xrandr')
            except:
                pass
            
            # Check ddcutil
            try:
                result = subprocess.run(['ddcutil', '--version'], capture_output=True, timeout=2)
                if result.returncode == 0:
                    methods.append('ddcutil')
            except:
                pass
            
            self._send_json_response(200, {
                'status': 'ok',
                'service': 'sleep_mode_handler',
                'available_methods': methods,
                'default_brightness': DEFAULT_BRIGHTNESS
            })
        else:
            self._send_json_response(404, {'error': 'Not found'})


def run_server(port: int = 8080):
    """Run the HTTP server"""
    server_address = ('', port)
    httpd = HTTPServer(server_address, SleepModeHandler)
    logger.info(f"Sleep Mode Handler running on port {port}")
    
    try:
        httpd.serve_forever()
    except KeyboardInterrupt:
        logger.info("Shutting down...")
        httpd.shutdown()


def main():
    parser = argparse.ArgumentParser(description='Sleep Mode Handler')
    parser.add_argument('--brightness', type=int, help='Brightness level (0-100)')
    parser.add_argument('--save', action='store_true', help='Save current brightness')
    parser.add_argument('--restore', action='store_true', help='Restore saved brightness')
    parser.add_argument('--server', action='store_true', help='Run as HTTP server')
    parser.add_argument('--port', type=int, default=8080, help='Server port')
    args = parser.parse_args()
    
    if args.server:
        run_server(args.port)
    elif args.save:
        save_current_brightness()
    elif args.restore:
        restore_brightness()
    elif args.brightness is not None:
        set_brightness(args.brightness)
    else:
        parser.print_help()


if __name__ == '__main__':
    main()
