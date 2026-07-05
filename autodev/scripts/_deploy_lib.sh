#!/usr/bin/env bash
# デプロイ共通: deploy.yaml の読み出しヘルパ。source して使う（_common.sh が先）。
DEPLOY_YAML="$AUTODEV_DIR/config/deploy.yaml"

dconf() {  # dconf <dotted.key> [default]
  conf_get "$DEPLOY_YAML" "$1" "${2:-}"
}
env_defined() { dconf "environments.$1.role" "" | grep -q .; }

# デプロイ先デバイスの解決: kind=avd → エミュレータ起動 / kind=adb-device → serial
resolve_target_device() {  # resolve_target_device <target> → serial を echo
  local tgt="$1" kind serial avd
  kind="$(dconf "environments.$tgt.kind" avd)"
  if [ "$kind" = "avd" ]; then
    avd="$(dconf "environments.$tgt.avd_name" "")"
    "$SCRIPTS_DIR/start_emulator.sh" ${avd:+"$avd"} | tail -1
  else
    serial="$(dconf "environments.$tgt.serial" "")"
    device_required "$serial"
  fi
}
