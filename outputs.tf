output "public_ip" {
  value = oci_core_instance.tf2.public_ip
}

output "connect" {
  description = "Paste into the TF2 console."
  value       = "connect ${oci_core_instance.tf2.public_ip}:27015"
}

output "ssh" {
  value = "ssh -i ${var.ssh_private_key_path} ubuntu@${oci_core_instance.tf2.public_ip}"
}

output "rcon_password" {
  description = "Show with: tofu output -raw rcon_password"
  value       = random_password.rcon.result
  sensitive   = true
}
