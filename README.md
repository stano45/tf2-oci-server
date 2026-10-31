# tf2-oci-server

A Team Fortress 2 dedicated server on Oracle Cloud's Always Free ARM VM (`VM.Standard.A1.Flex`, 4 OCPU / 24 GB), managed with [OpenTofu](https://opentofu.org) (Terraform >= 1.6 works too).

Valve only ships x86 builds of SteamCMD and `srcds`, so the VM runs them through [FEX-Emu](https://github.com/FEX-Emu/FEX). Expect a comfortable 24-player server; a full 32 can get tight on busy maps.

## What it creates

- VCN, public subnet, internet gateway, route table
- Security list: UDP 27015 open to everyone; SSH (22/tcp) and RCON (27015/tcp) open to `admin_cidr`
- Ubuntu 24.04 aarch64 VM, 4 OCPU / 24 GB / 100 GB boot volume
- On first boot (cloud-init): host firewall rules, FEX-Emu, SteamCMD, TF2 server files, systemd units
- After boot (OpenTofu over SSH): `server.cfg` and launch settings, then starts `tf2.service`
- A daily timer (05:00 UTC) that updates the server and restarts it only when Valve ships a new build

## Prerequisites

- OpenTofu >= 1.6 (or Terraform >= 1.6: run the same commands with `terraform`; it adds its own entries to the lock file)
- An Oracle Cloud account. The defaults fit inside the Always Free allowance (4 OCPU / 24 GB A1, 200 GB block storage), so make sure no other A1 VM or large volume is already using it.
- An OCI API key in `~/.oci/config`: OCI Console → profile menu → My profile → API keys (or Tokens and keys) → Add API key → Generate API key pair. Save the private key, paste the shown config preview into `~/.oci/config`, and point `key_file=` at the key.
- An SSH key pair for the VM:

  ```bash
  ssh-keygen -t ed25519 -f ~/.ssh/tf2_oci -N "" -C tf2-oci
  ```

No credentials are stored in this repo. State, `terraform.tfvars`, plans and keys are gitignored; the state file holds the RCON password and Steam token, so keep it private.

## Usage

```bash
cp terraform.tfvars.example terraform.tfvars   # fill in tenancy_ocid at least
tofu init
tofu apply
```

The first apply takes roughly 20–40 minutes: OpenTofu waits for the first-boot install (the TF2 download runs under emulation) and prints progress. Then:

```bash
tofu output connect                # paste into the TF2 console
tofu output -raw rcon_password
```

With `server_password` set, join with `password <your password>; connect <ip>:27015`, or connect and enter it at the prompt. The TF2 client remembers the last password for the session; run `password ""` to test the prompt.

Changing server settings (`hostname`, `server_password`, `start_map`, `map_cycle`, `max_players`, `bot_quota`, `bot_difficulty`, `gslt`) and re-running `tofu apply` pushes the new config and restarts the server. The VM itself is not replaced.

### Steam server token (GSLT)

Without a token the server works through direct `connect`, but it won't appear in the public server list. Create one at <https://steamcommunity.com/dev/managegameservers> with app ID **440**, set `gslt` in `terraform.tfvars`, and apply.

### Custom maps

TF2 loads Steam Workshop maps natively: put `workshop/<id>` (the number from the map's Workshop URL) in `start_map` or `map_cycle`. The server downloads it and clients get it from the Workshop automatically.

### Optional: SourceMod (admin commands and map voting)

Off by default and self-contained in `sourcemod.tf`. Enable it in `terraform.tfvars`:

```hcl
sourcemod = {
  enabled = true
  admins  = ["[U:1:12345678]"]  # Steam IDs with full admin; `status` in the TF2 console shows yours
}
```

This installs pinned, checksum-verified builds of MetaMod:Source and SourceMod 1.12 (both with 64-bit TF2 support) and keeps the server vanilla:

- **On:** admin menu (`!admin`), kick/ban/map commands, admin votes, map voting (`rtv`, `nominate`, an end-of-map vote, `nextmap`), reserved slots
- **Off:** `funcommands`, `funvotes`, `playercommands` (slap/slay) and `sounds`

Setting `enabled = false` unloads it again and keeps SourceMod's files, bans and settings on disk. StAC (the community anti-cheat) isn't included: it needs extensions that only exist as 32-bit builds, and this server runs 64-bit TF2.

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
- **The VM is never replaced implicitly.** Newer Ubuntu images and edits to `files/` or `templates/cloud-init.yaml.tftpl` are ignored for an existing VM, because recreating a free VM can fail on capacity. To rebuild on purpose: `tofu apply -replace=oci_core_instance.tf2`.
- **Cost.** Always Free resources cost nothing, but on a Pay As You Go account anything beyond the free limits is billed. Raising `ocpus`, `memory_gb` or `boot_volume_gb`, or running another A1 VM next to this one, can push you over.
- **Idle reclamation.** Oracle may reclaim Always Free VMs that stay under ~20% CPU, network and memory use for 7 days. An empty game server can look idle. Upgrading the account to Pay As You Go removes this; Always Free resources stay free.
- **Two firewalls.** Ports need to be open both in the VCN security list and in the VM's iptables. Both are handled here; keep that in mind when adding ports.
- **Bots.** With `bot_quota` set, bots keep the server populated and leave as humans join. Measured on 4 A1 cores: 21 bots + 1 human used ~43% of one core at a steady 66 tick. Bots keep the server awake, which also keeps it clear of Oracle's idle reclamation. Valve's maps ship nav meshes; custom maps without one get no bots.
- **Why FEXBash.** Valve's `steamcmd.sh` and `srcds_run_64` check `uname -m` and look for native arm64 builds on an ARM shell, so both run inside FEX's emulated bash, where they see x86_64.
- **Empty server browser.** If the in-game or Steam server browser shows no servers at all, that's the client, not this server: try Steam → Settings → In Game → "In-game server browser: Max pings / minute" = 500. `Favorites → Add a server` with the IP always works.

## License

[MIT](LICENSE)
