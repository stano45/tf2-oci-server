# tf2-oci-server

A Team Fortress 2 dedicated server on Oracle Cloud's Always Free ARM VM (`VM.Standard.A1.Flex`, 4 OCPU / 24 GB), managed with Terraform.

Valve only ships x86 builds of SteamCMD and `srcds`, so the VM runs them through [FEX-Emu](https://github.com/FEX-Emu/FEX). Expect a comfortable 24-player server; a full 32 can get tight on busy maps.

## What it creates

- VCN, public subnet, internet gateway, route table
- Security list: UDP 27015 open to everyone; SSH (22/tcp) and RCON (27015/tcp) open to `admin_cidr`
- Ubuntu 24.04 aarch64 VM, 4 OCPU / 24 GB / 100 GB boot volume
- On first boot (cloud-init): host firewall rules, FEX-Emu, SteamCMD, TF2 server files, systemd units
- After boot (Terraform over SSH): `server.cfg` and launch settings, then starts `tf2.service`
- A daily timer (05:00 UTC) that updates the server and restarts it only when Valve ships a new build

## Prerequisites

- Terraform >= 1.6
- An OCI API key in `~/.oci/config` (OCI Console → My profile → API keys → Add API key)
- An SSH key pair at `~/.ssh/tf2_oci` / `~/.ssh/tf2_oci.pub` (or set the `ssh_*_path` variables)

No credentials are stored in this repo. State, `terraform.tfvars`, and keys are gitignored.

## Usage

```bash
cp terraform.tfvars.example terraform.tfvars   # fill in tenancy_ocid at least
terraform init
terraform apply
```

The first apply takes roughly 20–40 minutes: Terraform waits for the first-boot install (the TF2 download runs under emulation) and prints progress. Then:

```bash
terraform output connect                # paste into the TF2 console
terraform output -raw rcon_password
```

Changing server settings (`hostname`, `server_password`, `start_map`, `max_players`, `gslt`) and re-running `terraform apply` pushes the new config and restarts the server. The VM itself is not replaced.

### Steam server token (GSLT)

Without a token the server works through direct `connect`, but it won't appear in the public server list. Create one at <https://steamcommunity.com/dev/managegameservers> with app ID **440**, set `gslt` in `terraform.tfvars`, and apply.

## Operating the server

```bash
ssh -i ~/.ssh/tf2_oci ubuntu@<ip>
sudo journalctl -u tf2 -f                       # server console output
sudo systemctl restart tf2
sudo systemctl start tf2-update                 # update now instead of waiting for the timer
sudo less /var/log/tf2-setup.log                # first-boot install log
```

## Gotchas

- **Out of host capacity.** Free A1 capacity is often exhausted. Retry later, or set `availability_domain_index` to another domain in your region.
- **The VM is never replaced implicitly.** Newer Ubuntu images and edits to `files/` or `templates/cloud-init.yaml.tftpl` are ignored for an existing VM, because recreating a free VM can fail on capacity. To rebuild on purpose: `terraform apply -replace=oci_core_instance.tf2`.
- **Idle reclamation.** Oracle may reclaim Always Free VMs that stay under ~20% CPU, network and memory use for 7 days. An empty game server can look idle. Upgrading the account to Pay As You Go removes this; Always Free resources stay free.
- **Two firewalls.** Ports need to be open both in the VCN security list and in the VM's iptables. Both are handled here; keep that in mind when adding ports.
