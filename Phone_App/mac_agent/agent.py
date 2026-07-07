from __future__ import annotations

import subprocess
from dataclasses import dataclass
from typing import Literal

from fastapi import FastAPI, HTTPException
from pydantic import BaseModel


@dataclass(frozen=True)
class TargetConfig:
    app_name: str


TARGETS: dict[str, TargetConfig] = {
    "vscode": TargetConfig("Visual Studio Code"),
    "claude": TargetConfig("Claude"),
    "codex": TargetConfig("Codex"),
    "chrome": TargetConfig("Google Chrome"),
    "whatsapp": TargetConfig("WhatsApp"),
    "openclaw": TargetConfig("OpenClaw"),
}


class CommandRequest(BaseModel):
    target: str
    action: Literal["open", "close"] = "open"


class CommandResponse(BaseModel):
    success: bool
    target: str
    action: Literal["focused", "launched", "closed"]
    reason: str


app = FastAPI(title="OpenClaw Mac Agent")


def _run(command: list[str]) -> subprocess.CompletedProcess[str]:
    return subprocess.run(
        command,
        capture_output=True,
        check=False,
        text=True,
        timeout=8,
    )


def _is_running(app_name: str) -> bool:
    script = f'application "{app_name}" is running'
    result = _run(["osascript", "-e", script])
    return result.returncode == 0 and result.stdout.strip().lower() == "true"


def _activate(app_name: str) -> tuple[bool, str]:
    script = f'tell application "{app_name}" to activate'
    result = _run(["osascript", "-e", script])
    if result.returncode == 0:
        return True, "Application focused"
    return False, (result.stderr or result.stdout or "Activation failed").strip()


def _launch(app_name: str) -> tuple[bool, str]:
    result = _run(["open", "-a", app_name])
    if result.returncode != 0:
        return False, (result.stderr or result.stdout or "Launch failed").strip()
    activated, reason = _activate(app_name)
    if not activated:
        return False, reason
    return True, "Application launched and focused"


def _quit(app_name: str) -> tuple[bool, str]:
    script = f'tell application "{app_name}" to quit saving no'
    result = _run(["osascript", "-e", script])
    if result.returncode == 0:
        return True, "Application closed"
    return False, (result.stderr or result.stdout or "Close failed").strip()


@app.get("/health")
def health() -> dict[str, str]:
    return {"status": "ok"}


@app.post("/command", response_model=CommandResponse)
def command(request: CommandRequest) -> CommandResponse:
    target = request.target.strip().lower()
    config = TARGETS.get(target)
    if config is None:
        raise HTTPException(
            status_code=400,
            detail=f"Unsupported target: {request.target}",
        )

    if request.action == "close":
        if not _is_running(config.app_name):
            return CommandResponse(
                success=True,
                target=target,
                action="closed",
                reason="Application already closed",
            )

        success, reason = _quit(config.app_name)
        if not success:
            raise HTTPException(status_code=500, detail=reason)
        return CommandResponse(
            success=True,
            target=target,
            action="closed",
            reason=reason,
        )

    if _is_running(config.app_name):
        success, reason = _activate(config.app_name)
        if not success:
            raise HTTPException(status_code=500, detail=reason)
        return CommandResponse(
            success=True,
            target=target,
            action="focused",
            reason=reason,
        )

    success, reason = _launch(config.app_name)
    if not success:
        raise HTTPException(status_code=500, detail=reason)
    return CommandResponse(
        success=True,
        target=target,
        action="launched",
        reason=reason,
    )
