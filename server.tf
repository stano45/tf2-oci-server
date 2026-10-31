resource "random_password" "rcon" {
  length  = 24
  special = false
}

locals {
  server_env = <<-EOT
    TF2_MAP=${var.start_map}
    TF2_MAXPLAYERS=${var.max_players}
    TF2_GSLT=${var.gslt}
  EOT

  server_cfg = templatefile("${path.module}/templates/server.cfg.tftpl", {
    hostname        = var.hostname
    rcon_password   = random_password.rcon.result
    server_password = var.server_password
    custom_cycle    = length(var.map_cycle) > 0
  })

  # Always non-empty: the file provisioner rejects empty content.
  map_cycle = length(var.map_cycle) > 0 ? join("", [for m in var.map_cycle : "${m}\n"]) : "// unused: map_cycle is empty\n"
}

# Waits for the first-boot install to finish, then pushes server settings and (re)starts
# the server. Re-runs whenever a setting changes, without touching the VM.
resource "terraform_data" "server_config" {
  triggers_replace = [
    oci_core_instance.tf2.id,
    sha256(local.server_env),
    sha256(local.server_cfg),
    sha256(local.map_cycle),
  ]

  connection {
    type        = "ssh"
    host        = oci_core_instance.tf2.public_ip
    user        = "ubuntu"
    private_key = file(pathexpand(var.ssh_private_key_path))
    timeout     = "10m"
  }

  provisioner "remote-exec" {
    inline = [
      "while [ ! -f /var/lib/tf2-setup.done ]; do if [ -f /var/lib/tf2-setup.failed ]; then echo 'First-boot setup failed:'; sudo tail -n 40 /var/log/tf2-setup.log; exit 1; fi; echo \"setup running: $(sudo tail -n 1 /var/log/tf2-setup.log 2>/dev/null | cut -c1-120)\"; sleep 30; done",
    ]
  }

  provisioner "file" {
    content     = local.server_env
    destination = "/home/ubuntu/.tf2-server.env"
  }

  provisioner "file" {
    content     = local.server_cfg
    destination = "/home/ubuntu/.tf2-server.cfg"
  }

  provisioner "file" {
    content     = local.map_cycle
    destination = "/home/ubuntu/.tf2-mapcycle.txt"
  }

  provisioner "remote-exec" {
    inline = [
      "sudo install -D -m 600 -o root -g root /home/ubuntu/.tf2-server.env /etc/tf2/server.env",
      "sudo install -m 640 -o tf2 -g tf2 /home/ubuntu/.tf2-server.cfg /home/tf2/tf2/tf/cfg/server.cfg",
      "sudo install -m 644 -o tf2 -g tf2 /home/ubuntu/.tf2-mapcycle.txt /home/tf2/tf2/tf/cfg/mapcycle_custom.txt",
      "rm -f /home/ubuntu/.tf2-server.env /home/ubuntu/.tf2-server.cfg /home/ubuntu/.tf2-mapcycle.txt",
      "sudo systemctl enable tf2.service",
      "sudo systemctl restart tf2.service",
    ]
  }
}
