#!/usr/bin/env python3
"""ComfyUI HTTP API で 5キャラ × 7variant = 35 立ち絵を生成。

- model: animagine-xl-4.0.safetensors (SDXL)
- 出力: app/src/main/assets/image/character/<id>/<variant>.webp (512x768)
- 既存ファイルがあれば skip（--force で上書き）
"""
import argparse
import io
import json
import os
import sys
import time
import urllib.parse
import urllib.request
import uuid
from pathlib import Path

from PIL import Image

HERE = Path(__file__).resolve().parent
REPO = HERE.parent.parent.parent  # autodev/scripts/asset_gen/ → repo root
CHARS = json.loads((HERE / "characters.json").read_text(encoding="utf-8"))
ASSETS = REPO / "app/src/main/assets/image/character"
COMFY = os.environ.get("COMFY_URL", "http://localhost:8188")
CLIENT_ID = str(uuid.uuid4())
MODEL = os.environ.get("COMFY_MODEL", "animagine-xl-4.0.safetensors")
WIDTH = 832
HEIGHT = 1216
STEPS = 24

POSITIVE_TEMPLATE = (
    "masterpiece, best quality, very aesthetic, absurdres, "
    "{appearance}, {variant_mod}"
)
NEGATIVE_BASE = (
    "lowres, worst quality, bad anatomy, bad hands, missing fingers, "
    "extra fingers, jpeg artifacts, signature, watermark, multiple people, "
    "{neg_extra}"
)


def workflow(positive: str, negative: str, seed: int) -> dict:
    """SDXL の最小ワークフロー（KSampler + VAEDecode + SaveImage）。"""
    return {
        "4": {
            "class_type": "CheckpointLoaderSimple",
            "inputs": {"ckpt_name": MODEL},
        },
        "5": {
            "class_type": "EmptyLatentImage",
            "inputs": {"width": WIDTH, "height": HEIGHT, "batch_size": 1},
        },
        "6": {
            "class_type": "CLIPTextEncode",
            "inputs": {"text": positive, "clip": ["4", 1]},
        },
        "7": {
            "class_type": "CLIPTextEncode",
            "inputs": {"text": negative, "clip": ["4", 1]},
        },
        "3": {
            "class_type": "KSampler",
            "inputs": {
                "seed": seed,
                "steps": STEPS,
                "cfg": 6.0,
                "sampler_name": "euler",
                "scheduler": "normal",
                "denoise": 1.0,
                "model": ["4", 0],
                "positive": ["6", 0],
                "negative": ["7", 0],
                "latent_image": ["5", 0],
            },
        },
        "8": {
            "class_type": "VAEDecode",
            "inputs": {"samples": ["3", 0], "vae": ["4", 2]},
        },
        "9": {
            "class_type": "SaveImage",
            "inputs": {"filename_prefix": "prismalink", "images": ["8", 0]},
        },
    }


def queue_prompt(prompt: dict) -> str:
    body = json.dumps({"prompt": prompt, "client_id": CLIENT_ID}).encode()
    req = urllib.request.Request(f"{COMFY}/prompt", data=body)
    req.add_header("Content-Type", "application/json")
    with urllib.request.urlopen(req, timeout=10) as r:
        return json.load(r)["prompt_id"]


def wait_history(prompt_id: str, timeout_s: int = 600) -> dict:
    deadline = time.time() + timeout_s
    while time.time() < deadline:
        with urllib.request.urlopen(f"{COMFY}/history/{prompt_id}", timeout=10) as r:
            h = json.load(r)
        if prompt_id in h:
            return h[prompt_id]
        time.sleep(1.0)
    raise TimeoutError(f"ComfyUI generation timeout: {prompt_id}")


def fetch_image(filename: str, subfolder: str, type_: str) -> bytes:
    qs = urllib.parse.urlencode({"filename": filename, "subfolder": subfolder, "type": type_})
    with urllib.request.urlopen(f"{COMFY}/view?{qs}", timeout=30) as r:
        return r.read()


def gen_one(char: dict, variant: dict, out_path: Path) -> None:
    pos = POSITIVE_TEMPLATE.format(appearance=char["appearance"], variant_mod=variant["prompt_modifier"])
    neg = NEGATIVE_BASE.format(neg_extra=char["negative_extra"])
    seed = abs(hash((char["id"], variant["name"]))) % (2**31)
    wf = workflow(pos, neg, seed)
    pid = queue_prompt(wf)
    sys.stderr.write(f"  [queue {pid[:8]}] {char['id']}/{variant['name']} seed={seed}\n")
    hist = wait_history(pid)
    outputs = hist.get("outputs", {})
    images = outputs.get("9", {}).get("images", [])
    if not images:
        raise RuntimeError(f"no output for {char['id']}/{variant['name']}: {outputs}")
    raw = fetch_image(images[0]["filename"], images[0].get("subfolder", ""), images[0].get("type", "output"))
    img = Image.open(io.BytesIO(raw))
    out_path.parent.mkdir(parents=True, exist_ok=True)
    # APK サイズ抑制のため 512x768 にリサイズ
    img.thumbnail((512, 768), Image.LANCZOS)
    img.save(out_path, "WEBP", quality=85, method=6)
    sys.stderr.write(f"    → {out_path.relative_to(REPO)} ({out_path.stat().st_size//1024}KB)\n")


def main() -> int:
    p = argparse.ArgumentParser()
    p.add_argument("--force", action="store_true")
    p.add_argument("--only-char", help="特定 char_id のみ")
    p.add_argument("--only-variant", help="特定 variant のみ")
    p.add_argument("--limit", type=int, default=0, help="生成枚数上限（テスト用）")
    args = p.parse_args()

    todo = []
    for ch in CHARS["characters"]:
        if args.only_char and ch["id"] != args.only_char:
            continue
        for v in CHARS["variants"]:
            if args.only_variant and v["name"] != args.only_variant:
                continue
            out = ASSETS / ch["id"] / f"{v['name']}.webp"
            if out.exists() and not args.force:
                continue
            todo.append((ch, v, out))

    if args.limit > 0:
        todo = todo[: args.limit]

    sys.stderr.write(f"画像生成: {len(todo)} 枚\n")
    for i, (ch, v, out) in enumerate(todo, 1):
        sys.stderr.write(f"[{i}/{len(todo)}] {ch['id']}/{v['name']}\n")
        try:
            gen_one(ch, v, out)
        except Exception as e:
            sys.stderr.write(f"  FAIL: {e}\n")
            return 1
    sys.stderr.write(f"完了: {len(todo)} 枚\n")
    return 0


if __name__ == "__main__":
    sys.exit(main())
