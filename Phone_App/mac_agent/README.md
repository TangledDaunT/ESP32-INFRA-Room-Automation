# OpenClaw Mac Agent

Small FastAPI service for the OpenClaw Remote Mac Control screen.

## Run Manually

```sh
cd mac_agent
./launch.sh
```

The launcher refreshes `.venv311` in place so it keeps working even if the workspace path changes.

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
