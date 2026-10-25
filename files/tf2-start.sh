#!/bin/bash
# Started by tf2.service as the tf2 user, with settings from /etc/tf2/server.env.
set -euo pipefail
cd /home/tf2/tf2

# Prefer the 64-bit server Valve added in 2025; fall back to the 32-bit one.
bin=./srcds_run_64
[ -x "$bin" ] || bin=./srcds_run

args=(-game tf -port 27015 +ip 0.0.0.0 -norestart
  +maxplayers "${TF2_MAXPLAYERS:-24}" +map "${TF2_MAP:-ctf_2fort}")
[ -n "${TF2_GSLT:-}" ] && args+=(+sv_setsteamaccount "$TF2_GSLT")

exec "$bin" "${args[@]}"
