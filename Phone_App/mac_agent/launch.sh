#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
VENV_DIR="$SCRIPT_DIR/.venv311"

cd "$SCRIPT_DIR"

python3 -m venv --upgrade "$VENV_DIR"
"$VENV_DIR/bin/python" -m pip install -r "$SCRIPT_DIR/requirements.txt"
exec "$VENV_DIR/bin/python" -m uvicorn agent:app --host 0.0.0.0 --port 8765