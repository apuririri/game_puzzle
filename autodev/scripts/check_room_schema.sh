#!/usr/bin/env bash
# Room schema / Migration ゲート（check_db_portability.sh の後継 / 修正方針 §3-8）。
#  - app/schemas/（exportSchema 出力）に複数バージョンがあるのに Migration 定義が無ければ WARN
#  - Migration があるのに MigrationTest（androidTest）が無ければ WARN
# --gate 指定時のみ fail(1)。
set -uo pipefail
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/_common.sh"

GATE=0; [ "${1:-}" = "--gate" ] && GATE=1
DRIFT=0
SCHEMA_DIR="$APP_DIR/schemas"

if [ ! -d "$SCHEMA_DIR" ]; then
  echo "[WARN] app/schemas/ が不在（Room exportSchema=true を確認）。初期段階ならスキップ。"
  exit 0
fi

# DB ごとの schema バージョン数
for db in "$SCHEMA_DIR"/*/; do
  [ -d "$db" ] || continue
  N="$(find "$db" -name '*.json' | wc -l | tr -d ' ')"
  NAME="$(basename "$db")"
  if [ "${N:-0}" -le 1 ]; then
    echo "[OK] $NAME: schema v$N（Migration 不要）"
    continue
  fi
  echo "[INFO] $NAME: schema $N バージョン → Migration 必須"
  if grep -rqE "Migration\(|addMigrations" "$APP_DIR/src/main" 2>/dev/null; then
    echo "[OK] Migration 定義あり"
  else
    echo "[WARN] schema が複数バージョンあるのに Migration 定義が見つかりません。"
    DRIFT=1
  fi
  if grep -rqE "MigrationTestHelper|runMigrationsAndValidate" "$APP_DIR/src/androidTest" 2>/dev/null; then
    echo "[OK] Migration テストあり"
  else
    echo "[WARN] Migration テスト（MigrationTestHelper）が見つかりません。"
    DRIFT=1
  fi
done

if [ "$DRIFT" = "0" ]; then echo "[OK] Room schema/Migration ゲート PASS"; exit 0; fi
[ "$GATE" = "1" ] && exit 1 || exit 0
