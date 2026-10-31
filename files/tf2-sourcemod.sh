#!/bin/bash
# Installs or disables MetaMod:Source + SourceMod for the TF2 server. Run as root by OpenTofu
# (sourcemod.tf). Usage: tf2-sourcemod install | disable
# install reads MMS_URL, MMS_SHA256, SM_URL, SM_SHA256, PLUGINS_ON, PLUGINS_OFF, ADMINS_FILE.
set -euo pipefail
tf=/home/tf2/tf2/tf
plugins=$tf/addons/sourcemod/plugins

case "${1:-}" in
install)
  tmp=$(mktemp -d)
  trap 'rm -rf "$tmp"' EXIT
  fetch() {
    curl -fsSL --retry 3 -o "$tmp/$2" "$1"
    echo "$3  $tmp/$2" | sha256sum -c --quiet -
  }
  fetch "$MMS_URL" mms.tgz "$MMS_SHA256"
  fetch "$SM_URL" sm.tgz "$SM_SHA256"

  # On upgrades keep the server's own SourceMod configs (admins, maplists, plugin settings).
  keep=()
  [ -d "$tf/addons/sourcemod/configs" ] && keep=(--exclude=addons/sourcemod/configs --exclude=cfg/sourcemod)
  tar -xzf "$tmp/mms.tgz" -C "$tf"
  tar -xzf "$tmp/sm.tgz" -C "$tf" "${keep[@]}"

  for p in $PLUGINS_OFF; do
    if [ -f "$plugins/$p.smx" ]; then mv -f "$plugins/$p.smx" "$plugins/disabled/"; fi
  done
  for p in $PLUGINS_ON; do
    if [ -f "$plugins/disabled/$p.smx" ]; then mv -f "$plugins/disabled/$p.smx" "$plugins/"; fi
  done

  install -m 640 "$ADMINS_FILE" "$tf/addons/sourcemod/configs/admins_simple.ini"
  chown -R tf2:tf2 "$tf/addons" "$tf/cfg/sourcemod"
  ;;
disable)
  # MetaMod is loaded through these .vdf files; without them SourceMod stays on disk, inactive.
  rm -f "$tf/addons/metamod.vdf" "$tf/addons/metamod_x64.vdf"
  ;;
*)
  echo "usage: $0 install|disable" >&2
  exit 2
  ;;
esac
