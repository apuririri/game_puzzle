#!/usr/bin/env python3
"""ストーリーモード用の台詞ごとボイスを VoiceVox で生成。

- 入力: characters.json (speaker id) + story_dialogs.json (各キャラ×章×台詞)
- 出力: app/src/main/assets/voice/<characterId>/story_ch<chapter>_<index>.ogg
- variant に応じて intonation / pitch / speed を微調整（感情表現の底上げ）
- 既存ファイルは skip（--force で上書き）
"""
from __future__ import annotations
import argparse
import io
import json
import os
import sys
import urllib.parse
import urllib.request
from pathlib import Path

import soundfile as sf

HERE = Path(__file__).resolve().parent
REPO = HERE.parent.parent.parent
CHARS = json.loads((HERE / "characters.json").read_text(encoding="utf-8"))
DIALOGS = json.loads((HERE / "story_dialogs.json").read_text(encoding="utf-8"))
ASSETS = REPO / "app/src/main/assets/voice"
VV = os.environ.get("VOICEVOX_URL", "http://localhost:50021")

# variant → 音声パラメータ倍率 (speedScale / pitchScale / intonationScale / volumeScale)
VARIANT_STYLES = {
    "NORMAL":    (1.00,  0.00, 1.00, 1.00),
    "JOY":       (1.03,  0.03, 1.20, 1.05),
    "WINK":      (1.03,  0.02, 1.15, 1.00),
    "ANGER":     (1.05,  0.02, 1.25, 1.10),
    "SAD":       (0.92, -0.03, 0.85, 0.90),
    "THINKING":  (0.95, -0.01, 0.90, 0.95),
    "CHAIN":     (1.05,  0.02, 1.20, 1.10),
    "BIG_CHAIN": (0.95,  0.05, 1.35, 1.15),
    "LOSE":      (0.85, -0.05, 0.80, 0.85),
    "VICTORY":   (1.05,  0.05, 1.30, 1.15),
}


def speaker_of(char_id: str) -> int:
    for c in CHARS["characters"]:
        if c["id"] == char_id:
            return c["voicevox_speaker_id"]
    raise KeyError(char_id)


def synth(text: str, speaker: int, style: tuple) -> bytes:
    qs = urllib.parse.urlencode({"text": text, "speaker": speaker})
    with urllib.request.urlopen(
        urllib.request.Request(f"{VV}/audio_query?{qs}", method="POST"), timeout=30
    ) as r:
        query = json.load(r)
    query["speedScale"], query["pitchScale"], query["intonationScale"], query["volumeScale"] = style
    body = json.dumps(query).encode()
    qs2 = urllib.parse.urlencode({"speaker": speaker})
    req = urllib.request.Request(f"{VV}/synthesis?{qs2}", data=body)
    req.add_header("Content-Type", "application/json")
    with urllib.request.urlopen(req, timeout=60) as r:
        return r.read()


def main() -> int:
    p = argparse.ArgumentParser()
    p.add_argument("--force", action="store_true")
    p.add_argument("--only-char", help="特定 char_id のみ")
    args = p.parse_args()

    todo = []
    for cid, cdata in DIALOGS.items():
        if cid.startswith("_"):
            continue
        if args.only_char and cid != args.only_char:
            continue
        speaker = speaker_of(cid)
        for ch_idx, chapter_lines in enumerate(cdata["chapters"], start=1):
            for line_idx, line in enumerate(chapter_lines):
                out = ASSETS / cid / f"story_ch{ch_idx}_{line_idx}.ogg"
                if out.exists() and not args.force:
                    continue
                todo.append((cid, speaker, ch_idx, line_idx, line, out))

    sys.stderr.write(f"ストーリー台詞ボイス生成: {len(todo)} ファイル\n")
    for i, (cid, speaker, ch_idx, line_idx, line, out) in enumerate(todo, 1):
        variant = line.get("variant", "NORMAL")
        style = VARIANT_STYLES.get(variant, VARIANT_STYLES["NORMAL"])
        text = line["text"]
        sys.stderr.write(f"[{i}/{len(todo)}] {cid}/ch{ch_idx}_{line_idx} ({variant}) speaker={speaker}\n")
        try:
            wav_bytes = synth(text, speaker, style)
            audio, sr = sf.read(io.BytesIO(wav_bytes), dtype="int16")
            out.parent.mkdir(parents=True, exist_ok=True)
            sf.write(out, audio, sr, format="OGG", subtype="VORBIS")
            sys.stderr.write(f"    → {out.relative_to(REPO)} ({out.stat().st_size//1024}KB)  「{text}」\n")
        except Exception as e:
            sys.stderr.write(f"    FAIL: {e}\n")
            return 1
    sys.stderr.write(f"完了: {len(todo)} ファイル\n")
    return 0


if __name__ == "__main__":
    sys.exit(main())
