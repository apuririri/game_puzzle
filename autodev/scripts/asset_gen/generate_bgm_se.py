#!/usr/bin/env python3
"""BGM / SE を numpy で合成して OGG/Vorbis で保存（高速プロシージャル）。

- BGM: 7 scene 分（8 秒ループ、chord + bass + kick + hat を 1 ショットでミックス）
- SE: 9 event 分
- 出力: app/src/main/assets/bgm/<sceneId>.ogg / se/<eventId>.ogg
"""
import argparse
import json
import sys
from pathlib import Path

import numpy as np
import soundfile as sf

HERE = Path(__file__).resolve().parent
REPO = HERE.parent.parent.parent
CHARS = json.loads((HERE / "characters.json").read_text(encoding="utf-8"))
ASSETS = REPO / "app/src/main/assets"
SR = 22050  # 軽量化のため 22kHz


def note_freq(semi_from_a4: float) -> float:
    return 440.0 * 2 ** (semi_from_a4 / 12.0)


KEY_OFFSETS = {
    "C":  -9, "G":  -2, "F":  -4, "D":  5,
    "Am": 0,  "Dm": 5,
}

MOOD_PROGS = {
    "bright_arpeggio": [[0, 4, 7], [5, 9, 12], [7, 11, 14], [0, 4, 7]],
    "bouncy":          [[0, 4, 7], [9, 12, 16], [5, 9, 12], [7, 11, 14]],
    "calm":            [[0, 4, 7], [5, 9, 12], [0, 4, 7], [7, 11, 14]],
    "uptempo":         [[0, 4, 7], [7, 11, 14], [9, 12, 16], [5, 9, 12]],
    "triumphant":      [[0, 4, 7], [5, 9, 12], [7, 11, 14], [0, 4, 7]],
    "intense":         [[0, 3, 7], [-2, 2, 5], [5, 8, 12], [0, 3, 7]],
    "melancholy":      [[0, 3, 7], [5, 8, 12], [-3, 0, 3], [0, 3, 7]],
}


def tone(freq: float, n_samples: int, amp: float = 0.2) -> np.ndarray:
    t = np.arange(n_samples) / SR
    return amp * np.sin(2 * np.pi * freq * t).astype(np.float32)


def make_envelope(n_samples: int, attack_s: float = 0.005, release_s: float = 0.08) -> np.ndarray:
    env = np.ones(n_samples, dtype=np.float32)
    a = min(int(attack_s * SR), n_samples)
    r = min(int(release_s * SR), n_samples - a)
    if a > 0:
        env[:a] = np.linspace(0, 1, a, dtype=np.float32)
    if r > 0:
        env[-r:] = np.linspace(1, 0, r, dtype=np.float32)
    return env


def synth_chord_block(root: int, chord: list[int], n_samples: int, amp: float = 0.10) -> np.ndarray:
    out = np.zeros(n_samples, dtype=np.float32)
    env = make_envelope(n_samples, 0.01, 0.15)
    for iv in chord:
        out += tone(note_freq(root + iv), n_samples, amp / len(chord))
    return out * env


def synth_bass_block(root: int, chord_root_iv: int, n_samples: int, amp: float = 0.18) -> np.ndarray:
    env = make_envelope(n_samples, 0.005, 0.3)
    return tone(note_freq(root + chord_root_iv - 12), n_samples, amp) * env


def synth_kick(n_samples: int) -> np.ndarray:
    t = np.arange(n_samples) / SR
    freq = 120 * np.exp(-t * 12)
    env = np.exp(-t * 8)
    return (0.5 * np.sin(2 * np.pi * np.cumsum(freq) / SR) * env).astype(np.float32)


def synth_hihat(n_samples: int) -> np.ndarray:
    t = np.arange(n_samples) / SR
    env = np.exp(-t * 40)
    return (np.random.uniform(-0.15, 0.15, n_samples) * env).astype(np.float32)


def generate_bgm(scene: dict, out_path: Path, loop_seconds: float = 8.0) -> None:
    root = KEY_OFFSETS.get(scene["key"], -9)
    progression = MOOD_PROGS.get(scene["mood"], MOOD_PROGS["calm"])
    bpm = scene["tempo_bpm"]
    beat_seconds = 60.0 / bpm
    bar_seconds = beat_seconds * 4

    total_n = int(SR * loop_seconds)
    total = np.zeros(total_n, dtype=np.float32)

    # コード進行を 1 周バーずつ重ねる（progression を時間軸方向にループ）
    pos = 0
    chord_idx = 0
    while pos < total_n:
        n = min(int(bar_seconds * SR), total_n - pos)
        if n <= 100:
            break
        chord = progression[chord_idx % len(progression)]
        chord_idx += 1
        total[pos:pos + n] += synth_chord_block(root, chord, n)
        total[pos:pos + n] += synth_bass_block(root, chord[0], n)
        pos += n

    # ドラム（kick を各拍頭、hi-hat を各拍の裏）
    kick_buf = synth_kick(int(0.12 * SR))
    hat_buf = synth_hihat(int(0.04 * SR))
    n_beats = int(loop_seconds / beat_seconds)
    for b in range(n_beats):
        bp = int(b * beat_seconds * SR)
        end = min(bp + len(kick_buf), total_n)
        total[bp:end] += kick_buf[: end - bp] * 0.6
        hp = int((b * beat_seconds + beat_seconds / 2) * SR)
        end = min(hp + len(hat_buf), total_n)
        total[hp:end] += hat_buf[: end - hp] * 0.4

    peak = float(np.max(np.abs(total))) or 1.0
    total = np.tanh(total / peak * 1.3) * 0.85
    out_path.parent.mkdir(parents=True, exist_ok=True)
    sf.write(out_path, total.astype(np.float32), SR, format="OGG", subtype="VORBIS")
    sys.stderr.write(f"  → {out_path.relative_to(REPO)} ({out_path.stat().st_size//1024}KB)\n")


def generate_se(ev: dict, out_path: Path) -> None:
    dur = ev["duration_ms"] / 1000.0
    freq = ev["freq"]
    typ = ev["type"]
    n = int(SR * dur)
    if n <= 0:
        n = 100
    t = np.arange(n) / SR
    if typ == "click":
        sig = 0.3 * np.sin(2 * np.pi * freq * t) * np.exp(-t * 50)
    elif typ == "tone":
        sig = 0.25 * np.sin(2 * np.pi * freq * t) * np.exp(-t * 20)
    elif typ == "sweep":
        f = freq * (1 + 2 * t / dur)
        sig = 0.25 * np.sin(2 * np.pi * np.cumsum(f) / SR) * np.exp(-t * 12)
    elif typ == "thud":
        f = freq * np.exp(-t * 8)
        sig = 0.4 * np.sin(2 * np.pi * np.cumsum(f) / SR) * np.exp(-t * 10)
    elif typ == "chime":
        sig = sum(
            0.2 / (i + 1) * np.sin(2 * np.pi * freq * p * t) * np.exp(-t * (5 + i * 2))
            for i, p in enumerate([1.0, 2.0, 3.0])
        )
    elif typ == "chord":
        sig = sum(0.15 * np.sin(2 * np.pi * freq * r * t) for r in [1.0, 1.25, 1.5])
        sig *= np.exp(-t * 5)
    elif typ == "buzz":
        sig = 0.25 * np.sign(np.sin(2 * np.pi * freq * t)) * np.exp(-t * 6)
    else:
        sig = 0.2 * np.sin(2 * np.pi * freq * t)
    sig = np.tanh(sig * 1.5) * 0.7
    out_path.parent.mkdir(parents=True, exist_ok=True)
    sf.write(out_path, sig.astype(np.float32), SR, format="OGG", subtype="VORBIS")
    sys.stderr.write(f"  → {out_path.relative_to(REPO)} ({out_path.stat().st_size}B)\n")


def main() -> int:
    p = argparse.ArgumentParser()
    p.add_argument("--force", action="store_true")
    p.add_argument("--only-bgm", action="store_true")
    p.add_argument("--only-se", action="store_true")
    args = p.parse_args()

    if not args.only_se:
        sys.stderr.write(f"BGM 生成 ({len(CHARS['bgm_scenes'])} scene)\n")
        for sc in CHARS["bgm_scenes"]:
            out = ASSETS / "bgm" / f"{sc['id']}.ogg"
            if out.exists() and not args.force:
                continue
            sys.stderr.write(f"  {sc['id']} ({sc['mood']} / {sc['tempo_bpm']}bpm / {sc['key']})\n")
            generate_bgm(sc, out)

    if not args.only_bgm:
        sys.stderr.write(f"SE 生成 ({len(CHARS['se_events'])} event)\n")
        for ev in CHARS["se_events"]:
            out = ASSETS / "se" / f"{ev['id']}.ogg"
            if out.exists() and not args.force:
                continue
            sys.stderr.write(f"  {ev['id']} ({ev['type']} / {ev['freq']}Hz / {ev['duration_ms']}ms)\n")
            generate_se(ev, out)
    return 0


if __name__ == "__main__":
    sys.exit(main())
