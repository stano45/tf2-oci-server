data "oci_identity_availability_domains" "ads" {
  compartment_id = var.tenancy_ocid
}

data "oci_core_images" "ubuntu" {
  compartment_id           = local.compartment_id
  operating_system         = "Canonical Ubuntu"
  operating_system_version = "24.04"
  shape                    = var.shape
  sort_by                  = "TIMECREATED"
  sort_order               = "DESC"

  filter {
    name   = "display_name"
    values = ["^Canonical-Ubuntu-24\\.04-aarch64-.*"]
    regex  = true
  }
}

locals {
  # Static first-boot install (FEX-Emu, SteamCMD, TF2, systemd units). Server settings are
  # pushed separately by terraform_data.server_config so changing them never replaces the VM.
  cloud_init = templatefile("${path.module}/templates/cloud-init.yaml.tftpl", {
    setup_sh       = file("${path.module}/files/tf2-setup.sh")
    start_sh       = file("${path.module}/files/tf2-start.sh")
    update_sh      = file("${path.module}/files/tf2-update.sh")
    auto_update_sh = file("${path.module}/files/tf2-auto-update.sh")
    tf2_service    = file("${path.module}/files/tf2.service")
    update_service = file("${path.module}/files/tf2-update.service")
    update_timer   = file("${path.module}/files/tf2-update.timer")
  })
}

resource "oci_core_instance" "tf2" {
  compartment_id      = local.compartment_id
  availability_domain = data.oci_identity_availability_domains.ads.availability_domains[var.availability_domain_index].name
  display_name        = var.name
  shape               = var.shape

  shape_config {
    ocpus         = var.ocpus
    memory_in_gbs = var.memory_gb
  }

  source_details {
    source_type             = "image"
    source_id               = data.oci_core_images.ubuntu.images[0].id
    boot_volume_size_in_gbs = var.boot_volume_gb
  }

  create_vnic_details {
    subnet_id        = oci_core_subnet.tf2.id
    assign_public_ip = true
    hostname_label   = "tf2"
  }

  metadata = {
    ssh_authorized_keys = trimspace(file(pathexpand(var.ssh_public_key_path)))
    user_data           = base64encode(local.cloud_init)
  }

  # Recreating a free A1 VM can fail on capacity, so newer images or edited first-boot
  # scripts don't replace it. Use `tofu apply -replace=oci_core_instance.tf2` on purpose.
  lifecycle {
    ignore_changes = [
      source_details[0].source_id,
      metadata["user_data"],
    ]
  }
}
