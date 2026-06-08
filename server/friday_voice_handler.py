#!/usr/bin/env python3
"""
Friday Voice Handler - HTTP server for receiving audio from phone

Receives POST /hooks/voice with base64 audio
Saves audio file, transcribes using local whisper/sherpa-onnx
Sends transcribed command to Friday (OpenClaw)

Usage:
    python3 friday_voice_handler.py

Requires:
    - Python 3.8+
    - Flask: pip install flask
    - sherpa-onnx (optional, for transcription)
"""

import os
import sys
import json
import base64
import tempfile
import subprocess
import logging
from datetime import datetime
from pathlib import Path
from http.server import HTTPServer, BaseHTTPRequestHandler
from urllib.parse import urlparse

# Configuration
GATEWAY_HOST = "127.0.0.1"
GATEWAY_PORT = 41262
VOICE_HOOK_TOKEN = os.environ.get("OPENCLAW_HOOK_TOKEN", "")
RECORDINGS_DIR = Path("/tmp/friday_recordings")
RECORDINGS_DIR.mkdir(exist_ok=True)

# Logging setup
logging.basicConfig(
    level=logging.INFO,
    format='[%(asctime)s] %(levelname)s: %(message)s',
    datefmt='%Y-%m-%d %H:%M:%S'
)
logger = logging.getLogger('friday_voice')


class FridayVoiceHandler(BaseHTTPRequestHandler):
    """HTTP handler for voice commands from phone"""
    
    def log_message(self, format, *args):
        """Custom logging"""
        logger.info(f"{self.address_string()} - {format % args}")
    
    def _send_json_response(self, status_code: int, data: dict):
        """Send JSON response"""
        self.send_response(status_code)
        self.send_header('Content-Type', 'application/json')
        self.end_headers()
        self.wfile.write(json.dumps(data).encode())
    
    def _verify_auth(self) -> bool:
        """Verify Authorization header"""
        auth_header = self.headers.get('Authorization', '')
        expected = f"Bearer {VOICE_HOOK_TOKEN}" if VOICE_HOOK_TOKEN else None
        
        if not expected:
            logger.warning("No VOICE_HOOK_TOKEN set, allowing all requests")
            return True
        
        if auth_header == expected:
            return True
        
        logger.warning(f"Invalid auth header: {auth_header}")
        return False
    
    def do_POST(self):
        """Handle POST requests"""
        parsed_path = urlparse(self.path)
        path = parsed_path.path
        
        # Only handle /hooks/voice
        if path != '/hooks/voice':
            self._send_json_response(404, {'error': 'Not found'})
            return
        
        # Verify auth
        if not self._verify_auth():
            self._send_json_response(401, {'error': 'Unauthorized'})
            return
        
        # Read request body
        content_length = int(self.headers.get('Content-Length', 0))
        body = self.rfile.read(content_length)
        
        try:
            payload = json.loads(body)
        except json.JSONDecodeError as e:
            logger.error(f"Invalid JSON: {e}")
            self._send_json_response(400, {'error': 'Invalid JSON'})
            return
        
        # Process voice command
        result = self._process_voice_command(payload)
        self._send_json_response(200, result)
    
    def _process_voice_command(self, payload: dict) -> dict:
        """Process incoming voice command"""
        timestamp = payload.get('timestamp', datetime.now().isoformat())
        audio_base64 = payload.get('audio', '')
        source = payload.get('source', 'unknown')
        
        if not audio_base64:
            return {'error': 'No audio data provided'}
        
        try:
            # Decode audio
            audio_bytes = base64.b64decode(audio_base64)
            
            # Save to file
            timestamp_str = datetime.now().strftime('%Y%m%d_%H%M%S')
            audio_path = RECORDINGS_DIR / f"friday_{timestamp_str}.wav"
            
            with open(audio_path, 'wb') as f:
                f.write(audio_bytes)
            
            logger.info(f"Saved audio to {audio_path} ({len(audio_bytes)} bytes)")
            
            # Transcribe audio
            transcription = self._transcribe_audio(audio_path)
            
            if transcription:
                logger.info(f"Transcription: {transcription}")
                
                # Send to Friday (OpenClaw)
                self._send_to_friday(transcription, str(audio_path))
                
                return {
                    'success': True,
                    'transcription': transcription,
                    'audio_path': str(audio_path),
                    'timestamp': timestamp
                }
            else:
                return {
                    'success': False,
                    'error': 'Transcription failed',
                    'audio_path': str(audio_path)
                }
                
        except Exception as e:
            logger.error(f"Error processing voice: {e}")
            return {'error': str(e)}
    
    def _transcribe_audio(self, audio_path: Path) -> str:
        """Transcribe audio file to text"""
        
        # Try sherpa-onnx first (local, offline)
        transcription = self._transcribe_with_sherpa(audio_path)
        
        if transcription:
            return transcription
        
        # Fallback: whisper CLI if available
        transcription = self._transcribe_with_whisper(audio_path)
        
        if transcription:
            return transcription
        
        # Last resort: mock for testing
        logger.warning("No transcription method available, returning mock")
        return "[transcription mock - please install sherpa-onnx or whisper]"
    
    def _transcribe_with_sherpa(self, audio_path: Path) -> str:
        """Transcribe using sherpa-onnx (local, fast)"""
        try:
            # Check if sherpa-onnx-cli is available
            result = subprocess.run(
                ['sherpa-onnx-cli', '--help'],
                capture_output=True,
                timeout=1
            )
            if result.returncode != 0:
                return None
        except (FileNotFoundError, subprocess.TimeoutExpired):
            return None
        
        try:
            # Run transcription
            result = subprocess.run(
                ['sherpa-onnx-cli', 'transcribe', str(audio_path)],
                capture_output=True,
                text=True,
                timeout=10
            )
            
            if result.returncode == 0:
                return result.stdout.strip()
            else:
                logger.warning(f"Sherpa transcription failed: {result.stderr}")
                return None
                
        except Exception as e:
            logger.error(f"Sherpa error: {e}")
            return None
    
    def _transcribe_with_whisper(self, audio_path: Path) -> str:
        """Transcribe using OpenAI Whisper (local)"""
        try:
            # Check if whisper is available
            result = subprocess.run(
                ['whisper', '--help'],
                capture_output=True,
                timeout=1
            )
            if result.returncode != 0:
                return None
        except (FileNotFoundError, subprocess.TimeoutExpired):
            return None
        
        try:
            # Run whisper
            result = subprocess.run(
                ['whisper', str(audio_path), '--model', 'tiny', '--language', 'en'],
                capture_output=True,
                text=True,
                timeout=30,
                cwd=RECORDINGS_DIR
            )
            
            if result.returncode == 0:
                # Read the output text file
                txt_path = audio_path.with_suffix('.txt')
                if txt_path.exists():
                    return txt_path.read_text().strip()
                else:
                    return result.stdout.strip()
            else:
                logger.warning(f"Whisper transcription failed: {result.stderr}")
                return None
                
        except Exception as e:
            logger.error(f"Whisper error: {e}")
            return None
    
    def _send_to_friday(self, transcription: str, audio_path: str):
        """Send transcription to Friday via OpenClaw gateway"""
        try:
            # Use curl to send to OpenClaw hooks
            # This wakes Friday with the transcribed message
            
            payload = {
                'text': f'Daddy said: "{transcription}" via voice command from his phone.',
                'mode': 'now',
                'source': 'phone_voice',
                'audio_path': audio_path
            }
            
            curl_cmd = [
                'curl', '-s', '-X', 'POST',
                f'http://{GATEWAY_HOST}:{GATEWAY_PORT}/hooks/wake',
                '-H', 'Content-Type: application/json',
            ]
            
            if VOICE_HOOK_TOKEN:
                curl_cmd.extend(['-H', f'Authorization: Bearer {VOICE_HOOK_TOKEN}'])
            
            curl_cmd.extend(['-d', json.dumps(payload)])
            
            result = subprocess.run(curl_cmd, capture_output=True, text=True, timeout=10)
            
            if result.returncode == 0:
                logger.info(f"Sent to Friday successfully: {transcription}")
            else:
                logger.error(f"Failed to send to Friday: {result.stderr}")
                
        except Exception as e:
            logger.error(f"Error sending to Friday: {e}")
    
    def do_GET(self):
        """Handle GET requests - health check"""
        if self.path == '/health':
            self._send_json_response(200, {
                'status': 'ok',
                'service': 'friday_voice_handler',
                'recordings_dir': str(RECORDINGS_DIR)
            })
        else:
            self._send_json_response(404, {'error': 'Not found'})


def run_server(port: int = 8080):
    """Run the HTTP server"""
    server_address = ('', port)
    httpd = HTTPServer(server_address, FridayVoiceHandler)
    logger.info(f"Friday Voice Handler running on port {port}")
    logger.info(f"Recordings saved to: {RECORDINGS_DIR}")
    logger.info(f"Gateway: http://{GATEWAY_HOST}:{GATEWAY_PORT}")
    
    try:
        httpd.serve_forever()
    except KeyboardInterrupt:
        logger.info("Shutting down...")
        httpd.shutdown()


if __name__ == '__main__':
    import argparse
    
    parser = argparse.ArgumentParser(description='Friday Voice Handler')
    parser.add_argument('--port', type=int, default=8080, help='Port to listen on')
    parser.add_argument('--gateway-port', type=int, default=41262, help='OpenClaw gateway port')
    args = parser.parse_args()
    
    GATEWAY_PORT = args.gateway_port
    run_server(args.port)
