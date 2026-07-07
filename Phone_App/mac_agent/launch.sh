#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
VENV_DIR="$SCRIPT_DIR/.venv311"

cd "$SCRIPT_DIR"

if lsof -nP -iTCP:8765 -sTCP:LISTEN >/dev/null 2>&1; then
	echo "Mac agent is already running on port 8765; exiting." >&2
	exit 0
fi

if [[ ! -x "$VENV_DIR/bin/python" ]]; then
	python3 -m venv "$VENV_DIR"
fi

if ! "$VENV_DIR/bin/python" - <<'PY'
import importlib.util

required = ["fastapi", "uvicorn", "psutil"]
missing = [name for name in required if importlib.util.find_spec(name) is None]
raise SystemExit(1 if missing else 0)
PY
then
	"$VENV_DIR/bin/python" -m pip install -r "$SCRIPT_DIR/requirements.txt"
fi

export PYTHONFAULTHANDLER=1

exec "$VENV_DIR/bin/python" -m uvicorn agent:app --host 0.0.0.0 --port 8765