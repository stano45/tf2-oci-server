# Optional MetaMod:Source + SourceMod: admin commands and map voting, nothing that changes
# gameplay. Off unless sourcemod.enabled is true; the rest of the stack doesn't depend on it.

variable "sourcemod" {
  description = "Optional MetaMod:Source + SourceMod. admins: Steam IDs given full admin, e.g. \"[U:1:12345678]\"."
  type = object({
    enabled = optional(bool, false)
    admins  = optional(list(string), [])
  })
  default = {}

  validation {
    condition     = alltrue([for id in var.sourcemod.admins : can(regex("^(\\[U:1:[0-9]+\\]|STEAM_[0-5]:[01]:[0-9]+)$", id))])
    error_message = "sourcemod.admins entries must be Steam IDs like [U:1:12345678] or STEAM_0:1:1234567."
  }
}

locals {
  # Pinned builds with 64-bit TF2 support. To upgrade, bump the URL and its sha256 together.
  sourcemod_packages = {
    MMS_URL    = "https://mms.alliedmods.net/mmsdrop/1.12/mmsource-1.12.0-git1228-linux.tar.gz"
    MMS_SHA256 = "29f60bb40154fb4d9d0020ee35347c8359eeaf493dc4fdd7182873cf51f83f47"
    SM_URL     = "https://sm.alliedmods.net/smdrop/1.12/sourcemod-1.12.0-git7259-linux.tar.gz"
    SM_SHA256  = "1025717c46119c15c6e73fd9b4a190fd8da480987307d133e1281eb9a6f5c91c"
    # Keep the server vanilla: map voting on, slap/burn/fun votes off.
    PLUGINS_ON  = "mapchooser rockthevote nominations"
    PLUGINS_OFF = "funcommands funvotes playercommands sounds"
  }

  sourcemod_env    = join(" ", [for k, v in local.sourcemod_packages : "${k}='${v}'"])
  sourcemod_admins = join("", [for id in var.sourcemod.admins : "\"${id}\" \"99:z\"\n"])
}

resource "terraform_data" "sourcemod" {
  count      = var.sourcemod.enabled ? 1 : 0
  depends_on = [terraform_data.server_config]

  triggers_replace = [
    oci_core_instance.tf2.id,
    sha256(file("${path.module}/files/tf2-sourcemod.sh")),
    sha256(local.sourcemod_env),
    sha256(local.sourcemod_admins),
  ]

  # Kept so the destroy-time provisioner (which may only use self) can still connect.
  input = {
    host     = oci_core_instance.tf2.public_ip
    key_path = var.ssh_private_key_path
  }

  connection {
    type        = "ssh"
    host        = self.input.host
    user        = "ubuntu"
    private_key = file(pathexpand(self.input.key_path))
    timeout     = "5m"
  }

  provisioner "file" {
    source      = "${path.module}/files/tf2-sourcemod.sh"
    destination = "/home/ubuntu/.tf2-sourcemod.sh"
  }

  provisioner "file" {
    # Never empty: the file provisioner rejects empty content.
    content     = "// Managed by OpenTofu (sourcemod.tf)\n${local.sourcemod_admins}"
    destination = "/home/ubuntu/.tf2-admins.ini"
  }

  provisioner "remote-exec" {
    inline = [
      "sudo install -m 755 /home/ubuntu/.tf2-sourcemod.sh /usr/local/sbin/tf2-sourcemod",
      "sudo ${local.sourcemod_env} ADMINS_FILE=/home/ubuntu/.tf2-admins.ini /usr/local/sbin/tf2-sourcemod install",
      "rm -f /home/ubuntu/.tf2-sourcemod.sh /home/ubuntu/.tf2-admins.ini",
      "sudo systemctl restart tf2.service",
    ]
  }

  # Turning it off unloads MetaMod but keeps SourceMod's files, bans and settings on disk.
  provisioner "remote-exec" {
    when       = destroy
    on_failure = continue
    inline = [
      "sudo /usr/local/sbin/tf2-sourcemod disable",
      "sudo systemctl try-restart tf2.service",
    ]
  }
}
