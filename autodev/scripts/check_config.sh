#!/usr/bin/env bash
# autodev/config/*.yaml を _schema/ 配下の JSON Schema で検証（案5）。
# SessionStart hook と CI で実行。
# 依存: システム python3 + PyYAML + jsonschema（無ければ SKIP。setup.sh が best-effort で導入）。
set -uo pipefail
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/_common.sh"

SCHEMA_DIR="$AUTODEV_DIR/config/_schema"
if [ ! -d "$SCHEMA_DIR" ]; then
  echo "[SKIP] $SCHEMA_DIR 不在。"
  exit 0
fi

PY=""
if command -v python3 >/dev/null 2>&1; then
  PY="python3"
else
  echo "[SKIP] python3 が見つかりません。"
  exit 0
fi

# 検査対象を組み立て: <config_path>::<schema_path> ペア
PAIRS=()
for c in loop deploy retention watchdog android_env; do
  conf="$AUTODEV_DIR/config/${c}.yaml"
  sch="$SCHEMA_DIR/${c}.schema.yaml"
  if [ -f "$conf" ] && [ -f "$sch" ]; then
    PAIRS+=("$conf::$sch")
  fi
done

if [ "${#PAIRS[@]}" -eq 0 ]; then
  echo "[SKIP] 検査対象 (config + schema) なし。"
  exit 0
fi

"$PY" - "${PAIRS[@]}" <<'PYEOF'
import sys
try:
    import yaml  # type: ignore
except ImportError:
    print("[SKIP] PyYAML 未インストール（pip install pyyaml）。")
    sys.exit(0)
try:
    import jsonschema  # type: ignore
except ImportError:
    print("[SKIP] jsonschema 未インストール（pip install jsonschema）。")
    sys.exit(0)

fail = 0
for pair in sys.argv[1:]:
    config_path, schema_path = pair.split("::", 1)
    try:
        with open(config_path, encoding="utf-8") as f:
            config = yaml.safe_load(f) or {}
        with open(schema_path, encoding="utf-8") as f:
            schema = yaml.safe_load(f)
        jsonschema.validate(instance=config, schema=schema)
        print(f"[OK]   {config_path}")
    except FileNotFoundError as e:
        print(f"[WARN] {e}")
    except yaml.YAMLError as e:
        print(f"[FAIL] YAML parse error in {config_path}: {e}")
        fail = 1
    except jsonschema.ValidationError as e:
        path = ".".join(map(str, e.absolute_path)) or "(root)"
        print(f"[FAIL] {config_path}: schema 違反 at {path}: {e.message}")
        fail = 1
    except Exception as e:
        print(f"[FAIL] {config_path}: {type(e).__name__}: {e}")
        fail = 1
sys.exit(fail)
PYEOF
