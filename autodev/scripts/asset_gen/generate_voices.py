#!/usr/bin/env python3
"""VoiceVox HTTP API でキャラごとのボイスを生成し OGG/Vorbis で保存。

- 出力: app/src/main/assets/voice/<characterId>/<eventId>.ogg
- 既存ファイルがあれば skip（--force で上書き）
"""
import argparse
import io
import json
import os
import sys
import urllib.parse
import urllib.request
from pathlib import Path

import numpy as np
import soundfile as sf

HERE = Path(__file__).resolve().parent
REPO = HERE.parent.parent.parent
CHARS = json.loads((HERE / "characters.json").read_text(encoding="utf-8"))
ASSETS = REPO / "app/src/main/assets/voice"
VV = os.environ.get("VOICEVOX_URL", "http://localhost:50021")


def post_json(path: str, body) -> bytes:
    data = json.dumps(body).encode() if not isinstance(body, (bytes, bytearray)) else body
    req = urllib.request.Request(f"{VV}{path}", data=data)
    req.add_header("Content-Type", "application/json")
    with urllib.request.urlopen(req, timeout=30) as r:
        return r.read()


def gen_one(char: dict, line: dict, out_path: Path) -> None:
    # キャラ側で voice_lines_override が指定されていればそれを優先（口調がキャラ固有の場合、
    # 例: あぷりりり=ギャル口調）。無ければ共有テンプレを {name} 補完。
    overrides = char.get("voice_lines_override", {})
    text = overrides.get(line["event"]) or line["text_template"].format(name=char["displayName"])
    speaker = char["voicevox_speaker_id"]
    # 1) audio_query
    qs = urllib.parse.urlencode({"text": text, "speaker": speaker})
    with urllib.request.urlopen(
        urllib.request.Request(f"{VV}/audio_query?{qs}", method="POST"), timeout=30
    ) as r:
        query = json.load(r)
    # 大連鎖ボイスは少し抑揚を強める
    if line["event"] == "chain_big":
        query["speedScale"] = 0.95
        query["pitchScale"] = 0.05
        query["intonationScale"] = 1.3
        query["volumeScale"] = 1.1
    # 2) synthesis (WAV)
    qs2 = urllib.parse.urlencode({"speaker": speaker})
    wav_bytes = post_json(f"/synthesis?{qs2}", query)
    # 3) WAV → OGG/Vorbis
    audio, sr = sf.read(io.BytesIO(wav_bytes), dtype="int16")
    out_path.parent.mkdir(parents=True, exist_ok=True)
    sf.write(out_path, audio, sr, format="OGG", subtype="VORBIS")
    sys.stderr.write(f"  → {out_path.relative_to(REPO)} ({out_path.stat().st_size//1024}KB)\n")


def main() -> int:
    p = argparse.ArgumentParser()
    p.add_argument("--force", action="store_true")
    p.add_argument("--only-char", help="特定 char_id")
    p.add_argument("--only-event", help="特定 event のみ")
    args = p.parse_args()

    todo = []
    for ch in CHARS["characters"]:
        if args.only_char and ch["id"] != args.only_char:
            continue
        for line in CHARS["voice_lines"]:
            if args.only_event and line["event"] != args.only_event:
                continue
            out = ASSETS / ch["id"] / f"{line['event']}.ogg"
            if out.exists() and not args.force:
                continue
            todo.append((ch, line, out))

    sys.stderr.write(f"ボイス生成: {len(todo)} ファイル\n")
    for i, (ch, line, out) in enumerate(todo, 1):
        sys.stderr.write(f"[{i}/{len(todo)}] {ch['id']}/{line['event']} (speaker {ch['voicevox_speaker_id']})\n")
        try:
            gen_one(ch, line, out)
        except Exception as e:
            sys.stderr.write(f"  FAIL: {e}\n")
            return 1
    sys.stderr.write(f"完了: {len(todo)} ファイル\n")
    return 0


if __name__ == "__main__":
    sys.exit(main())
