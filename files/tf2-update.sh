#!/bin/bash
# Installs or updates the TF2 server files. Run as the tf2 user; pass "validate" to verify all files.
set -euo pipefail

for attempt in 1 2 3; do
  # SteamCMD often fails on its first run while it updates itself, so retry.
  if ~/steamcmd/steamcmd.sh +force_install_dir ~/tf2 +login anonymous +app_update 232250 ${1:-} +quit; then
    exit 0
  fi
  echo "steamcmd failed (attempt $attempt), retrying" >&2
  sleep 15
done
exit 1
