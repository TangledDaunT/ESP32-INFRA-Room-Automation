#!/usr/bin/env python3
import argparse
import os
import sys
from faster_whisper import WhisperModel


def main() -> int:
    parser = argparse.ArgumentParser(description="Fast local Whisper transcription (faster-whisper)")
    parser.add_argument("audio_path", help="Path to input audio file")
    parser.add_argument("--model", default=os.getenv("WHISPER_FAST_MODEL", "small"), help="Whisper model size/name")
    parser.add_argument("--compute", default=os.getenv("WHISPER_FAST_COMPUTE", "int8"), help="Compute type (int8/int8_float16/float16/float32)")
    parser.add_argument("--beam", type=int, default=int(os.getenv("WHISPER_FAST_BEAM", "3")), help="Beam size")
    parser.add_argument("--language", default=os.getenv("WHISPER_FAST_LANGUAGE", ""), help="Optional language code, e.g. en, hi")
    args = parser.parse_args()

    if not os.path.exists(args.audio_path):
        print(f"Audio file not found: {args.audio_path}", file=sys.stderr)
        return 2

    cpu_threads = max(1, min(4, os.cpu_count() or 2))

    model = WhisperModel(
        args.model,
        device="cpu",
        compute_type=args.compute,
        cpu_threads=cpu_threads,
    )

    transcribe_kwargs = {
        "beam_size": args.beam,
        "vad_filter": True,
    }
    if args.language:
        transcribe_kwargs["language"] = args.language

    segments, _info = model.transcribe(args.audio_path, **transcribe_kwargs)
    text = " ".join((s.text or "").strip() for s in segments).strip()
    print(text)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
