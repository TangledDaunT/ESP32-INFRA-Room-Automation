#!/usr/bin/env bash
set -e

echo "=== Friday Integration Server Setup ==="

# 1. Install Python deps
echo "[1/5] Installing Python dependencies..."
pip3 install flask requests --quiet

# 2. Create Friday data dir
echo "[2/5] Creating ~/.friday/ directory..."
mkdir -p ~/.friday/recordings

# 3. Generate token if not exists
TOKEN_FILE=~/.friday/.hook_token
if [ ! -f "$TOKEN_FILE" ]; then
    echo "[3/5] Generating hook token..."
    python3 -c "import secrets; print(secrets.token_hex(32))" > "$TOKEN_FILE"
    chmod 600 "$TOKEN_FILE"
else
    echo "[3/5] Hook token already exists, skipping."
fi

TOKEN=$(cat "$TOKEN_FILE")
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# 4. Install systemd service
echo "[4/5] Installing systemd service..."
SERVICE_SRC="$SCRIPT_DIR/friday_integration_server.service"
SERVICE_DST="/etc/systemd/system/friday_integration_server.service"

# Patch the ExecStart to use the actual script path
sed "s|ExecStart=.*|ExecStart=/usr/bin/python3 $SCRIPT_DIR/friday_integration_server.py|g" \
    "$SERVICE_SRC" > /tmp/friday_patched.service

sudo cp /tmp/friday_patched.service "$SERVICE_DST"
sudo systemctl daemon-reload
sudo systemctl enable friday_integration_server
sudo systemctl restart friday_integration_server

LAPTOP_IP=$(hostname -I | awk '{print $1}')

# 5. Print summary
echo ""
echo "[5/5] Setup complete."

# 6. Spotify credentials (optional)
echo ""
echo "[6/6] Spotify Now Playing Setup (optional - press Enter to skip)"
read -p "  Enter Spotify Client ID (or press Enter to skip): " SPOTIFY_CLIENT_ID

if [ -n "$SPOTIFY_CLIENT_ID" ]; then
    read -p "  Enter Spotify Client Secret: " SPOTIFY_CLIENT_SECRET

    cat > ~/.friday/spotify_credentials.json << EOF
{
  "client_id": "$SPOTIFY_CLIENT_ID",
  "client_secret": "$SPOTIFY_CLIENT_SECRET"
}
EOF
    chmod 600 ~/.friday/spotify_credentials.json
    echo ""
    echo "  Spotify credentials saved."
    echo ""
    echo "  Add this redirect URI in your Spotify Developer Dashboard:"
    echo "     http://localhost:41263/api/spotify/callback"
    echo ""
    echo "  Then authorize by opening this URL in your browser:"
    echo "     http://$LAPTOP_IP:41263/api/spotify/auth"
else
    echo "  Skipped. Run setup.sh again to add Spotify later."
fi

echo ""
echo "============================"
echo "  Friday Server is running"
echo "============================"
echo "  URL:   http://$LAPTOP_IP:41263"
echo "  Token: $TOKEN"
echo ""
echo "  In your phone app settings:"
echo "    Friday Base URL: http://$LAPTOP_IP:41263"
echo "    Hook Token:      $TOKEN"
echo ""
echo "  Check status: systemctl status friday_integration_server"
echo "  View logs:    journalctl -u friday_integration_server -f"
