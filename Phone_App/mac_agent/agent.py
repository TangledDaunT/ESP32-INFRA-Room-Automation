from __future__ import annotations

import base64
import os
import platform
import re
import shutil
import socket
import tempfile
import threading
import time
from dataclasses import asdict, dataclass
import subprocess
from pathlib import Path
from typing import Literal

from fastapi import FastAPI, HTTPException
from pydantic import BaseModel
import psutil


@dataclass(frozen=True)
class TargetConfig:
    app_name: str


@dataclass(frozen=True)
class SystemStatus:
    reachable: bool
    battery_percent: float | None
    battery_charging: bool | None
    wifi_ssid: str | None
    wifi_device: str | None
    cpu_percent: float
    memory_percent: float
    disk_percent: float
    timestamp: float


@dataclass(frozen=True)
class NotificationItem:
    id: str
    app_name: str
    request_id: str
    summary: str
    timestamp: float
    dismissed: bool = False


@dataclass(frozen=True)
class MediaDevice:
    id: str
    name: str


@dataclass(frozen=True)
class CaptureResult:
    success: bool
    kind: str
    filename: str
    preview_base64: str | None = None
    saved_to: str | None = None
    reason: str | None = None


TARGETS: dict[str, TargetConfig] = {
    "vscode": TargetConfig("Visual Studio Code"),
    "claude": TargetConfig("Claude"),
    "codex": TargetConfig("Codex"),
    "chrome": TargetConfig("Google Chrome"),
    "whatsapp": TargetConfig("WhatsApp"),
    "openclaw": TargetConfig("OpenClaw"),
}

SYSTEM_VERSION_CACHE: SystemStatus | None = None
NOTIFICATION_CACHE: list[NotificationItem] = []
NOTIFICATION_CACHE_TS: float = 0.0
MEDIA_OUTPUTS_CACHE: list[MediaDevice] = []
MEDIA_OUTPUTS_CACHE_TS: float = 0.0

BASE_DIR = Path(__file__).resolve().parent
SCREENSHOT_DIR = Path.home() / "Pictures" / "OpenClaw Remote" / "Screenshots"
RECORDING_DIR = Path.home() / "Movies" / "OpenClaw Remote" / "Recordings"
SCREENSHOT_DIR.mkdir(parents=True, exist_ok=True)
RECORDING_DIR.mkdir(parents=True, exist_ok=True)

_WIFI_DEVICE: str | None = None
_PSUTIL_PRIMED = False


class CommandRequest(BaseModel):
    target: str
    action: Literal["open", "close"] = "open"


class CommandResponse(BaseModel):
    success: bool
    target: str
    action: Literal["focused", "launched", "closed"]
    reason: str


class StatusResponse(BaseModel):
    reachable: bool
    batteryPercent: float | None = None
    batteryCharging: bool | None = None
    wifiSsid: str | None = None
    wifiDevice: str | None = None
    cpuPercent: float
    memoryPercent: float
    diskPercent: float
    timestamp: float


class NotificationResponse(BaseModel):
    id: str
    appName: str
    requestId: str
    summary: str
    timestamp: float
    dismissed: bool = False


class MediaDeviceResponse(BaseModel):
    id: str
    name: str


class CaptureResponse(BaseModel):
    success: bool
    kind: str
    filename: str
    previewBase64: str | None = None
    savedTo: str | None = None
    reason: str | None = None


class RecordRequest(BaseModel):
    durationSeconds: int = 10


class VolumeRequest(BaseModel):
    level: int


class OutputRequest(BaseModel):
    deviceId: str


class NotificationActionRequest(BaseModel):
    action: Literal["dismiss", "open"]


app = FastAPI(title="OpenClaw Mac Agent")


def _run(command: list[str]) -> subprocess.CompletedProcess[str]:
    return subprocess.run(
        command,
        capture_output=True,
        check=False,
        text=True,
        timeout=8,
    )


def _prime_psutil() -> None:
    global _PSUTIL_PRIMED
    if not _PSUTIL_PRIMED:
        psutil.cpu_percent(interval=None)
        _PSUTIL_PRIMED = True


def _find_wifi_device() -> str | None:
    global _WIFI_DEVICE
    if _WIFI_DEVICE is not None:
        return _WIFI_DEVICE

    result = _run(["networksetup", "-listallhardwareports"])
    if result.returncode != 0:
        _WIFI_DEVICE = None
        return None

    matches = re.findall(r"Hardware Port: Wi-Fi\nDevice: (en\d+)", result.stdout)
    _WIFI_DEVICE = matches[0] if matches else None
    return _WIFI_DEVICE


def _wifi_ssid() -> str | None:
    device = _find_wifi_device()
    if not device:
        return None

    result = _run(["networksetup", "-getairportnetwork", device])
    if result.returncode != 0:
        return None

    text = result.stdout.strip()
    if ": " not in text:
        return None
    return text.split(": ", 1)[1].strip() or None


def _capture_status() -> SystemStatus:
    _prime_psutil()
    battery = psutil.sensors_battery()
    disk = psutil.disk_usage("/")
    return SystemStatus(
        reachable=True,
        battery_percent=battery.percent if battery else None,
        battery_charging=battery.power_plugged if battery else None,
        wifi_ssid=_wifi_ssid(),
        wifi_device=_find_wifi_device(),
        cpu_percent=round(psutil.cpu_percent(interval=None), 1),
        memory_percent=round(psutil.virtual_memory().percent, 1),
        disk_percent=round(disk.percent, 1),
        timestamp=time.time(),
    )


def _status() -> SystemStatus:
    global SYSTEM_VERSION_CACHE
    now = time.time()
    if SYSTEM_VERSION_CACHE is None or now - SYSTEM_VERSION_CACHE.timestamp > 10:
        SYSTEM_VERSION_CACHE = _capture_status()
    return SYSTEM_VERSION_CACHE


def _notification_summary(line: str) -> NotificationItem | None:
    match = re.search(
        r'record <NotificationRecord app:"(?P<app>[^"]+)" ident:"(?P<ident>[^"]+)" req:"(?P<req>[^"]+)".*(?:text:"(?P<text>[^"]*)")?',
        line,
    )
    if not match:
        return None

    app_name = match.group("app") or "Unknown"
    request_id = match.group("req") or match.group("ident") or "unknown"
    summary_parts = [app_name]
    text = match.group("text")
    if text:
        summary_parts.append(text)
    elif request_id:
        summary_parts.append(request_id)

    return NotificationItem(
        id=request_id,
        app_name=app_name,
        request_id=request_id,
        summary=" • ".join(summary_parts),
        timestamp=time.time(),
    )


def _refresh_notifications() -> list[NotificationItem]:
    global NOTIFICATION_CACHE, NOTIFICATION_CACHE_TS
    now = time.time()
    if NOTIFICATION_CACHE and now - NOTIFICATION_CACHE_TS < 20:
        return NOTIFICATION_CACHE

    result = _run([
        "log",
        "show",
        "--last",
        "2m",
        "--style",
        "compact",
        "--predicate",
        'process == "NotificationCenter"',
    ])
    items: list[NotificationItem] = []
    if result.returncode == 0:
        seen: set[str] = set()
        for line in result.stdout.splitlines():
            if "NotificationRecord" not in line:
                continue
            item = _notification_summary(line)
            if item and item.id not in seen:
                seen.add(item.id)
                items.append(item)

    NOTIFICATION_CACHE = items[-10:]
    NOTIFICATION_CACHE_TS = now
    return NOTIFICATION_CACHE


def _find_switch_audio_source() -> str | None:
    candidate = shutil.which("SwitchAudioSource")
    if candidate:
        return candidate
    homebrew = Path("/opt/homebrew/bin/SwitchAudioSource")
    if homebrew.exists():
        return str(homebrew)
    return None


def _list_media_outputs() -> list[MediaDevice]:
    global MEDIA_OUTPUTS_CACHE, MEDIA_OUTPUTS_CACHE_TS
    now = time.time()
    if MEDIA_OUTPUTS_CACHE and now - MEDIA_OUTPUTS_CACHE_TS < 60:
        return MEDIA_OUTPUTS_CACHE

    binary = _find_switch_audio_source()
    if not binary:
        MEDIA_OUTPUTS_CACHE = []
        MEDIA_OUTPUTS_CACHE_TS = now
        return MEDIA_OUTPUTS_CACHE

    result = _run([binary, "-a", "-t", "output"])
    devices: list[MediaDevice] = []
    if result.returncode == 0:
        for line in result.stdout.splitlines():
            name = line.strip()
            if name:
                devices.append(MediaDevice(id=name, name=name))

    MEDIA_OUTPUTS_CACHE = devices
    MEDIA_OUTPUTS_CACHE_TS = now
    return MEDIA_OUTPUTS_CACHE


def _screenshot_file() -> Path:
    return SCREENSHOT_DIR / f"openclaw-{time.strftime('%Y%m%d-%H%M%S')}.png"


def _recording_file() -> Path:
    return RECORDING_DIR / f"openclaw-{time.strftime('%Y%m%d-%H%M%S')}.mp4"


def _encode_preview(path: Path) -> str | None:
    try:
        return base64.b64encode(path.read_bytes()).decode("ascii")
    except Exception:
        return None


def _capture_screenshot() -> CaptureResult:
    target = _screenshot_file()
    result = _run(["screencapture", "-x", "-t", "png", str(target)])
    if result.returncode != 0 or not target.exists():
        return CaptureResult(
            success=False,
            kind="screenshot",
            filename=target.name,
            reason=(result.stderr or result.stdout or "Screenshot failed").strip(),
        )
    return CaptureResult(
        success=True,
        kind="screenshot",
        filename=target.name,
        preview_base64=_encode_preview(target),
        saved_to=str(target),
    )


def _record_screen(duration_seconds: int) -> CaptureResult:
    binary = _find_ffmpeg()
    if not binary:
        return CaptureResult(
            success=False,
            kind="screen_record",
            filename="",
            reason="ffmpeg not found",
        )

    output = _recording_file()
    screen_input = _discover_screen_input(binary)
    if screen_input is None:
        return CaptureResult(
            success=False,
            kind="screen_record",
            filename=output.name,
            reason="No screen capture input detected",
        )

    command = [
        binary,
        "-y",
        "-f",
        "avfoundation",
        "-capture_cursor",
        "1",
        "-framerate",
        "15",
        "-i",
        f"{screen_input}:none",
        "-t",
        str(max(1, min(duration_seconds, 120))),
        "-pix_fmt",
        "yuv420p",
        str(output),
    ]
    result = _run(command)
    if result.returncode != 0 or not output.exists():
        return CaptureResult(
            success=False,
            kind="screen_record",
            filename=output.name,
            reason=(result.stderr or result.stdout or "Screen recording failed").strip(),
        )

    preview = _capture_screenshot()
    return CaptureResult(
        success=True,
        kind="screen_record",
        filename=output.name,
        preview_base64=preview.preview_base64 if preview.success else None,
        saved_to=str(output),
    )


def _find_ffmpeg() -> str | None:
    candidate = shutil.which("ffmpeg")
    if candidate:
        return candidate
    homebrew = Path("/opt/homebrew/bin/ffmpeg")
    if homebrew.exists():
        return str(homebrew)
    return None


def _discover_screen_input(ffmpeg_binary: str) -> str | None:
    result = _run([ffmpeg_binary, "-f", "avfoundation", "-list_devices", "true", "-i", ""])
    output = result.stderr + "\n" + result.stdout
    match = re.search(r"\[(\d+)\]\s+Capture screen \d+", output)
    if match:
        return match.group(1)
    match = re.search(r"\[(\d+)\]\s+Display", output)
    if match:
        return match.group(1)
    return None


def _media_action(script: str) -> tuple[bool, str]:
    result = _run(["osascript", "-e", script])
    if result.returncode == 0:
        return True, "OK"
    return False, (result.stderr or result.stdout or "Media action failed").strip()


def _all_media_apps() -> list[str]:
    return ["Music", "Spotify", "iTunes"]


def _playback(script_body: str) -> tuple[bool, str]:
    for app_name in _all_media_apps():
        ok, reason = _media_action(f'tell application "{app_name}" to {script_body}')
        if ok:
            return True, f"{app_name} updated"
    return False, "No media app responded"


def _set_volume(level: int) -> tuple[bool, str]:
    level = max(0, min(100, level))
    ok, reason = _media_action(f"set volume output volume {level}")
    return ok, reason


def _set_output_device(device_id: str) -> tuple[bool, str]:
    binary = _find_switch_audio_source()
    if not binary:
        return False, "SwitchAudioSource not installed"
    result = _run([binary, "-t", "output", "-s", device_id])
    if result.returncode == 0:
        return True, "Audio output changed"
    return False, (result.stderr or result.stdout or "Output switch failed").strip()


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


@app.get("/status", response_model=StatusResponse)
def status() -> StatusResponse:
    s = _status()
    return StatusResponse(
        reachable=s.reachable,
        batteryPercent=s.battery_percent,
        batteryCharging=s.battery_charging,
        wifiSsid=s.wifi_ssid,
        wifiDevice=s.wifi_device,
        cpuPercent=s.cpu_percent,
        memoryPercent=s.memory_percent,
        diskPercent=s.disk_percent,
        timestamp=s.timestamp,
    )


@app.get("/notifications", response_model=list[NotificationResponse])
def notifications() -> list[NotificationResponse]:
    items = _refresh_notifications()
    return [
        NotificationResponse(
            id=item.id,
            appName=item.app_name,
            requestId=item.request_id,
            summary=item.summary,
            timestamp=item.timestamp,
            dismissed=item.dismissed,
        )
        for item in items
    ]


@app.post("/notifications/{notification_id}/action")
def notification_action(notification_id: str, request: NotificationActionRequest) -> dict[str, str]:
    if request.action == "dismiss":
        global NOTIFICATION_CACHE
        NOTIFICATION_CACHE = [item for item in _refresh_notifications() if item.id != notification_id]
        return {"status": "dismissed", "id": notification_id}

    items = _refresh_notifications()
    match = next((item for item in items if item.id == notification_id), None)
    if match is None:
        raise HTTPException(status_code=404, detail="Notification not found")

    activated, reason = _activate(match.app_name)
    if not activated:
        raise HTTPException(status_code=500, detail=reason)
    return {"status": "opened", "id": notification_id}


@app.post("/screenshot", response_model=CaptureResponse)
def screenshot() -> CaptureResponse:
    result = _capture_screenshot()
    return CaptureResponse(
        success=result.success,
        kind=result.kind,
        filename=result.filename,
        previewBase64=result.preview_base64,
        savedTo=result.saved_to,
        reason=result.reason,
    )


@app.post("/screen-record", response_model=CaptureResponse)
def screen_record(request: RecordRequest) -> CaptureResponse:
    result = _record_screen(request.durationSeconds)
    return CaptureResponse(
        success=result.success,
        kind=result.kind,
        filename=result.filename,
        previewBase64=result.preview_base64,
        savedTo=result.saved_to,
        reason=result.reason,
    )


@app.get("/media/output-devices", response_model=list[MediaDeviceResponse])
def media_outputs() -> list[MediaDeviceResponse]:
    return [MediaDeviceResponse(id=device.id, name=device.name) for device in _list_media_outputs()]


@app.post("/media/play-pause")
def media_play_pause() -> dict[str, str]:
    ok, reason = _playback("playpause")
    if not ok:
        raise HTTPException(status_code=500, detail=reason)
    return {"status": "ok"}


@app.post("/media/next")
def media_next() -> dict[str, str]:
    ok, reason = _playback("next track")
    if not ok:
        raise HTTPException(status_code=500, detail=reason)
    return {"status": "ok"}


@app.post("/media/previous")
def media_previous() -> dict[str, str]:
    ok, reason = _playback("previous track")
    if not ok:
        raise HTTPException(status_code=500, detail=reason)
    return {"status": "ok"}


@app.post("/media/volume")
def media_volume(request: VolumeRequest) -> dict[str, str]:
    ok, reason = _set_volume(request.level)
    if not ok:
        raise HTTPException(status_code=500, detail=reason)
    return {"status": "ok"}


@app.post("/media/output-device")
def media_output_device(request: OutputRequest) -> dict[str, str]:
    ok, reason = _set_output_device(request.deviceId)
    if not ok:
        raise HTTPException(status_code=500, detail=reason)
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
