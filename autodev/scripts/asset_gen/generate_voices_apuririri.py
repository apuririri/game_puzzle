#!/usr/bin/env python3
"""あぷりりり専用ボイス生成: 春日部つむぎ(id=8) + ギャル口調テキスト。

- 出力: app/src/main/assets/voice/apuririri/<event>.ogg
- 既定は既存ファイル skip、--force で上書き。
- event キーは他キャラと揃える（AudioManager が同一キーで再生を試みる）。
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
OUT_DIR = REPO / "app/src/main/assets/voice/apuririri"
VV = os.environ.get("VOICEVOX_URL", "http://localhost:50021")
SPEAKER = 8  # 春日部つむぎ ノーマル

# ギャル口調のラインテーブル (event, text)
LINES = [
    ("select_preview", "はろ〜☆　あーし、あぷりりり！　よろよろ〜♪"),
    ("chain_1",        "いっけぇ！"),
    ("chain_1_alt1",   "はい、ぱっ！"),
    ("chain_1_alt2",   "うぇい！"),
    ("chain_2",        "にれんさ〜、余裕っしょ！"),
    ("chain_2_alt1",   "まだいくよっ、続くってばぁ！"),
    ("chain_2_alt2",   "うふふ、あーし止まんな〜い♡"),
    ("chain_big",      "だ・い・れ・ん・さぁ〜〜っ！　テンアゲ！"),
    ("chain_big_alt1", "ちょ〜、なにこれ！　あーしガチ天才かも？！"),
    ("chain_big_alt2", "きゃぴぃ〜！　派手にキメちゃお♡"),
    ("skill",          "ギャル、サンシャイィィン！"),
    ("skill_alt1",     "見せたげる、あーしの本気ってやつ！"),
    ("win",            "勝ちぃ〜っ！　あーし最強♡"),
    ("win_alt1",       "ちょろすぎ〜、まじガチ余裕っ！"),
    ("lose",           "うそでしょ〜っ、負けちった……。"),
    ("lose_alt1",      "つ、次はぜっったい勝つし！"),
    ("idle",           "ねぇねぇ、次なにやる？"),
    ("idle_alt1",      "はやくやろ〜？　あーし退屈っ！"),
    ("idle_alt2",      "ぼーっとしてないで、遊ぼ〜♪"),
]


def synth(text: str, speaker: int = SPEAKER, big: bool = False) -> bytes:
    qs = urllib.parse.urlencode({"text": text, "speaker": speaker})
    with urllib.request.urlopen(
        urllib.request.Request(f"{VV}/audio_query?{qs}", method="POST"), timeout=30
    ) as r:
        query = json.load(r)
    if big:
        query["speedScale"] = 0.95
        query["pitchScale"] = 0.05
        query["intonationScale"] = 1.3
        query["volumeScale"] = 1.1
    body = json.dumps(query).encode()
    qs2 = urllib.parse.urlencode({"speaker": speaker})
    req = urllib.request.Request(f"{VV}/synthesis?{qs2}", data=body)
    req.add_header("Content-Type", "application/json")
    with urllib.request.urlopen(req, timeout=60) as r:
        return r.read()


def main() -> int:
    p = argparse.ArgumentParser()
    p.add_argument("--force", action="store_true")
    args = p.parse_args()

    OUT_DIR.mkdir(parents=True, exist_ok=True)
    for event, text in LINES:
        out = OUT_DIR / f"{event}.ogg"
        if out.exists() and not args.force:
            sys.stderr.write(f"  skip {out.name}\n")
            continue
        wav_bytes = synth(text, big=event.startswith("chain_big"))
        audio, sr = sf.read(io.BytesIO(wav_bytes), dtype="int16")
        sf.write(out, audio, sr, format="OGG", subtype="VORBIS")
        sys.stderr.write(f"  → {out.relative_to(REPO)} ({out.stat().st_size//1024}KB)  「{text}」\n")
    print(f"done: {len(LINES)} lines → {OUT_DIR.relative_to(REPO)}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
