# OpenClaw Mac Agent

Small FastAPI service for the OpenClaw Remote Mac Control screen.

## Run Manually

```sh
cd mac_agent
python3 -m venv .venv
source .venv/bin/activate
pip install -r requirements.txt
uvicorn agent:app --host 0.0.0.0 --port 8765
```

Set the Flutter app's `MAC AGENT URL` setting to your Mac's Tailscale address, for example:

```text
http://100.x.x.x:8765
```

## Commands

The agent accepts only these targets:

- `vscode`
- `claude`
- `codex`
- `chrome`
- `whatsapp`
- `openclaw`

Use `action: "open"` to launch/focus an app, or `action: "close"` to quit it.

Example:

```sh
curl -X POST http://100.x.x.x:8765/command \
  -H 'Content-Type: application/json' \
  -d '{"target":"chrome","action":"open"}'
```
