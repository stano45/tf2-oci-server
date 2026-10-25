#!/bin/bash
# Run daily by tf2-update.timer as root. Restarts the server only if Valve shipped a new build,
# since clients on a newer version can't join an outdated server.
set -euo pipefail
manifest=/home/tf2/tf2/steamapps/appmanifest_232250.acf
buildid() { grep -o '"buildid"[[:space:]]*"[0-9]*"' "$manifest" 2>/dev/null || true; }

before=$(buildid)
runuser -l tf2 -c /usr/local/bin/tf2-update
after=$(buildid)

if [ "$before" != "$after" ]; then
  echo "TF2 build changed ($before -> $after), restarting"
  systemctl try-restart tf2.service
fi
