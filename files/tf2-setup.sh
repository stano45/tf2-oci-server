#!/bin/bash
# First-boot install, run once by cloud-init as root. Log: /var/log/tf2-setup.log
# Marks /var/lib/tf2-setup.done on success and /var/lib/tf2-setup.failed on error.
set -euxo pipefail
exec > >(tee -a /var/log/tf2-setup.log) 2>&1
trap 'touch /var/lib/tf2-setup.failed' ERR
export DEBIAN_FRONTEND=noninteractive

# Host firewall: Oracle's Ubuntu images REJECT all inbound traffic not explicitly allowed,
# so the game port has to go in before that rule (the VCN security list is a separate layer).
pos=$(iptables -L INPUT --line-numbers -n | awk '$2 == "REJECT" { print $1; exit }')
iptables -I INPUT "${pos:-1}" -p udp --dport 27015 -j ACCEPT
iptables -I INPUT "${pos:-1}" -p tcp --dport 27015 -j ACCEPT
netfilter-persistent save

# FEX-Emu runs the x86/x86-64 SteamCMD and srcds binaries on ARM, registered via binfmt_misc.
apt-get update
apt-get install -y software-properties-common curl ca-certificates squashfuse fuse3
add-apt-repository -y ppa:fex-emu/fex
apt-get update
feat=$(grep -m1 '^Features' /proc/cpuinfo)
has() { grep -qw "$1" <<<"$feat"; }
if has atomics && has ilrcpc && has uscat && has flagm; then
  fex_pkg=fex-emu-armv8.4
elif has atomics && has asimdrdm && has dcpop; then
  fex_pkg=fex-emu-armv8.2 # Ampere Altra (A1) lands here
else
  fex_pkg=fex-emu-armv8.0
fi
apt-get install -y "$fex_pkg"
ls /proc/sys/fs/binfmt_misc/

# Service user with its own x86 root filesystem for FEX.
id tf2 &>/dev/null || useradd --create-home --shell /bin/bash tf2
runuser -l tf2 -c 'FEXRootFSFetcher -y -x'

# SteamCMD and the TF2 dedicated server (app 232250).
runuser -l tf2 -c 'mkdir -p ~/steamcmd && curl -fsSL https://steamcdn-a.akamaihd.net/client/installer/steamcmd_linux.tar.gz | tar -xz -C ~/steamcmd'
runuser -l tf2 -c '/usr/local/bin/tf2-update validate'
runuser -l tf2 -c 'mkdir -p ~/.steam/sdk32 ~/.steam/sdk64 && ln -sf ~/steamcmd/linux32/steamclient.so ~/.steam/sdk32/steamclient.so && ln -sf ~/steamcmd/linux64/steamclient.so ~/.steam/sdk64/steamclient.so'

# tf2.service is enabled by Terraform once it has pushed /etc/tf2/server.env.
mkdir -p /etc/tf2
systemctl daemon-reload
systemctl enable --now tf2-update.timer

touch /var/lib/tf2-setup.done
