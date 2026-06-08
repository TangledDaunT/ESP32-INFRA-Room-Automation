#!/usr/bin/env python3
"""Minimal wireless history receiver for OpenClaw.

Run on Ubuntu and point the app's history sync URL to:
  http://<laptop-ip>:8765/log

Each POST body is appended as JSON to openclaw_history.jsonl.
"""

from __future__ import annotations

import json
from datetime import datetime, timezone
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path


LOG_PATH = Path("openclaw_history.jsonl")


class ReceiverHandler(BaseHTTPRequestHandler):
    def do_POST(self) -> None:
        if self.path != "/log":
            self.send_error(404, "Not found")
            return

        content_length = int(self.headers.get("Content-Length", "0"))
        raw = self.rfile.read(content_length)

        try:
            payload = json.loads(raw.decode("utf-8"))
        except Exception:
            self.send_error(400, "Invalid JSON")
            return

        record = {
            "receivedAt": datetime.now(timezone.utc).isoformat(),
            "payload": payload,
        }
        with LOG_PATH.open("a", encoding="utf-8") as handle:
            handle.write(json.dumps(record, ensure_ascii=False) + "\n")

        response = json.dumps({"ok": True}).encode("utf-8")
        self.send_response(200)
        self.send_header("Content-Type", "application/json")
        self.send_header("Content-Length", str(len(response)))
        self.end_headers()
        self.wfile.write(response)

    def log_message(self, format: str, *args) -> None:  # noqa: A003
        return


def main() -> None:
    server = ThreadingHTTPServer(("0.0.0.0", 8765), ReceiverHandler)
    print("OpenClaw history receiver listening on http://0.0.0.0:8765/log")
    try:
        server.serve_forever()
    except KeyboardInterrupt:
        pass
    finally:
        server.server_close()


if __name__ == "__main__":
    main()