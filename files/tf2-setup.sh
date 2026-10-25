#!/bin/bash
# First-boot install, run by cloud-init as root; safe to re-run. Log: /var/log/tf2-setup.log
# Marks /var/lib/tf2-setup.done on success and /var/lib/tf2-setup.failed on error.
set -euxo pipefail
exec > >(tee -a /var/log/tf2-setup.log) 2>&1
rm -f /var/lib/tf2-setup.failed
trap 'touch /var/lib/tf2-setup.failed' ERR
export DEBIAN_FRONTEND=noninteractive

# Host firewall: Oracle's Ubuntu images REJECT all inbound traffic not explicitly allowed,
# so the game port has to go in before that rule (the VCN security list is a separate layer).
for proto in udp tcp; do
  iptables -C INPUT -p "$proto" --dport 27015 -j ACCEPT 2>/dev/null && continue
  pos=$(iptables -L INPUT --line-numbers -n | awk '$2 == "REJECT" { print $1; exit }')
  iptables -I INPUT "${pos:-1}" -p "$proto" --dport 27015 -j ACCEPT
done
netfilter-persistent save

# A freshly created VCN's resolver can take a few minutes to answer, and apt-get update only
# warns on fetch errors, so wait for DNS and treat any failed index download as an error.
for _ in $(seq 60); do getent ahostsv4 ports.ubuntu.com >/dev/null && break; sleep 5; done
apt_update() {
  for _ in 1 2 3 4 5; do apt-get update --error-on=any && return 0; sleep 15; done
  return 1
}

# FEX-Emu runs the x86/x86-64 SteamCMD and srcds binaries on ARM, registered via binfmt_misc.
apt_update
apt-get install -y software-properties-common curl ca-certificates squashfuse fuse3
add-apt-repository -y ppa:fex-emu/fex
apt_update
feat=$(grep -m1 '^Features' /proc/cpuinfo)
has() { grep -qw "$1" <<<"$feat"; }
if has atomics && has ilrcpc && has uscat && has flagm; then
  fex_pkg=fex-emu-armv8.4
elif has atomics && has asimdrdm && has dcpop; then
  fex_pkg=fex-emu-armv8.2 # Ampere Altra (A1) lands here
else
  fex_pkg=fex-emu-armv8.0
fi
apt-get install -y "$fex_pkg" fex-emu-binfmt32 fex-emu-binfmt64
test -e /proc/sys/fs/binfmt_misc/FEX-x86 && test -e /proc/sys/fs/binfmt_misc/FEX-x86_64

# Service user with its own x86 root filesystem for FEX. The fetcher would otherwise try a
# GUI prompt, and it doesn't reliably write Config.json, so select the RootFS explicitly.
id tf2 &>/dev/null || useradd --create-home --shell /bin/bash tf2
rootfs_dir=/home/tf2/.local/share/fex-emu/RootFS
find_rootfs() { find "$rootfs_dir" -mindepth 1 -maxdepth 1 -type d -printf '%f\n' 2>/dev/null | head -1; }
[ -n "$(find_rootfs)" ] || runuser -l tf2 -c 'FEXRootFSFetcher -y -x --force-ui=tty --distro-list-first'
rootfs=$(find_rootfs)
test -n "$rootfs"
rm -f "$rootfs_dir"/*.sqsh
install -d -o tf2 -g tf2 /home/tf2/.config/fex-emu
printf '{"Config":{"RootFS":"%s"}}\n' "$rootfs" >/home/tf2/.config/fex-emu/Config.json
chown tf2:tf2 /home/tf2/.config/fex-emu/Config.json

# SteamCMD and the TF2 dedicated server (app 232250).
runuser -l tf2 -c 'mkdir -p ~/steamcmd && curl -fsSL https://steamcdn-a.akamaihd.net/client/installer/steamcmd_linux.tar.gz | tar -xz -C ~/steamcmd'
runuser -l tf2 -c '/usr/local/bin/tf2-update validate'
runuser -l tf2 -c 'mkdir -p ~/.steam/sdk32 ~/.steam/sdk64 && ln -sf ~/steamcmd/linux32/steamclient.so ~/.steam/sdk32/steamclient.so && ln -sf ~/steamcmd/linux64/steamclient.so ~/.steam/sdk64/steamclient.so'

# tf2.service is enabled by Terraform once it has pushed /etc/tf2/server.env.
mkdir -p /etc/tf2
systemctl daemon-reload
systemctl enable --now tf2-update.timer

touch /var/lib/tf2-setup.done
