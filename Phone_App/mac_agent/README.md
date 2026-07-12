# OpenClaw Mac Agent

Small FastAPI service for the OpenClaw Remote Mac Control screen.

## Run Manually

```sh
cd mac_agent
./launch.sh
```

The launcher refreshes `.venv311` in place so it keeps working even if the workspace path changes.
It binds to `0.0.0.0:8765`, so the Flutter app can reach it through Tailscale
as long as macOS allows incoming connections for Python/uvicorn.

Set the Flutter app's `MAC AGENT URL` setting to your Mac's Tailscale address, for example:

```text
http://100.x.x.x:8765
```

The agent includes CORS headers for local Flutter web origins such as
`http://localhost:<port>` and `http://127.0.0.1:<port>`, so the Chrome debug
build can call the same Tailscale URL used by the Android app.

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
