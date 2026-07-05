"""YAML 設定から dotted key を取り出す簡易ヘルパ（AutoDev for Android）。
使い方: python3 autodev/scripts/_conf.py <yaml> <dotted.key> [default]
PyYAML があればそれを使い、無ければ簡易パーサ（2スペースインデントの
ネスト dict + スカラのみ。リスト走査は不可）で読む。見つからなければ default(or 空)。
"""
from __future__ import annotations

import sys


def tiny_parse(text: str) -> dict:
    """PyYAML 不在時のフォールバック。コメント・空行を除き、
    `key:` (ネスト) / `key: value` (スカラ) のみ対応。リストは無視する。"""
    root: dict = {}
    stack: list[tuple[int, dict]] = [(-1, root)]
    for raw in text.splitlines():
        if not raw.strip() or raw.lstrip().startswith("#"):
            continue
        line = raw.rstrip()
        indent = len(line) - len(line.lstrip())
        stripped = line.strip()
        if stripped.startswith("- "):
            continue  # リストはスキップ（dotted get の対象外）
        if ":" not in stripped:
            continue
        key, _, val = stripped.partition(":")
        key = key.strip()
        # コメント除去（クォート外のみ簡易対応）
        v = val.strip()
        if v and not (v.startswith('"') or v.startswith("'")):
            v = v.split(" #", 1)[0].strip()
        while stack and indent <= stack[-1][0]:
            stack.pop()
        parent = stack[-1][1] if stack else root
        if v == "":
            child: dict = {}
            parent[key] = child
            stack.append((indent, child))
        else:
            if (v.startswith('"') and v.endswith('"')) or (v.startswith("'") and v.endswith("'")):
                v = v[1:-1]
            parent[key] = v
    return root


def load(path: str):
    text = open(path, encoding="utf-8").read()
    try:
        import yaml  # type: ignore
        return yaml.safe_load(text) or {}
    except Exception:
        return tiny_parse(text)


def main() -> int:
    if len(sys.argv) < 3:
        print("", end="")
        return 2
    path, dotted = sys.argv[1], sys.argv[2]
    default = sys.argv[3] if len(sys.argv) > 3 else ""
    try:
        data = load(path)
    except Exception:
        print(default, end="")
        return 0
    cur = data
    for k in dotted.split("."):
        if isinstance(cur, dict) and k in cur:
            cur = cur[k]
        else:
            print(default, end="")
            return 0
    if isinstance(cur, (dict, list)):
        print(default, end="")
    elif isinstance(cur, bool):
        print("true" if cur else "false", end="")
    else:
        print(cur, end="")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
