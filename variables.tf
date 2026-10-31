# --- OCI account -------------------------------------------------------------

variable "tenancy_ocid" {
  description = "Tenancy OCID (the tenancy= line in ~/.oci/config)."
  type        = string
}

variable "compartment_ocid" {
  description = "Compartment to create everything in. Defaults to the tenancy root."
  type        = string
  default     = null
}

variable "oci_profile" {
  description = "Profile name in ~/.oci/config."
  type        = string
  default     = "DEFAULT"
}

variable "region" {
  description = "OCI region, e.g. eu-frankfurt-1. Defaults to the region in ~/.oci/config."
  type        = string
  default     = null
}

# --- VM ----------------------------------------------------------------------

variable "name" {
  description = "Prefix for resource display names."
  type        = string
  default     = "tf2"
}

variable "shape" {
  description = "Compute shape. VM.Standard.A1.Flex is the Always Free ARM shape."
  type        = string
  default     = "VM.Standard.A1.Flex"
}

variable "ocpus" {
  description = "OCPUs (Always Free allows 4 in total across all A1 VMs)."
  type        = number
  default     = 4
}

variable "memory_gb" {
  description = "Memory in GB (Always Free allows 24 in total across all A1 VMs)."
  type        = number
  default     = 24
}

variable "boot_volume_gb" {
  description = "Boot volume size. Always Free includes 200 GB of block storage in total."
  type        = number
  default     = 100
}

variable "availability_domain_index" {
  description = "Which availability domain to use (0-based). Try another one on \"Out of host capacity\"."
  type        = number
  default     = 0
}

variable "ssh_public_key_path" {
  description = "Public key installed for the ubuntu user."
  type        = string
  default     = "~/.ssh/tf2_oci.pub"
}

variable "ssh_private_key_path" {
  description = "Private key OpenTofu uses to push the server config over SSH."
  type        = string
  default     = "~/.ssh/tf2_oci"
}

variable "admin_cidr" {
  description = "Source range allowed to reach SSH (22/tcp) and RCON (27015/tcp). Set to your IP/32 to lock it down."
  type        = string
  default     = "0.0.0.0/0"
}

# --- TF2 server --------------------------------------------------------------

variable "hostname" {
  description = "Server name shown in the server browser."
  type        = string
  default     = "TF2 on Oracle ARM"

  validation {
    condition     = !can(regex("[\"\\n]", var.hostname))
    error_message = "hostname must not contain double quotes or newlines."
  }
}

variable "server_password" {
  description = "Password players need to join. Empty means public."
  type        = string
  default     = ""
  sensitive   = true

  validation {
    condition     = !can(regex("[\"\\n;]", var.server_password))
    error_message = "server_password must not contain double quotes, semicolons or newlines."
  }
}

variable "start_map" {
  description = "Map loaded on startup."
  type        = string
  default     = "ctf_2fort"
}

variable "max_players" {
  description = "Player slots. 24 is a comfortable limit under x86 emulation on 4 A1 cores."
  type        = number
  default     = 24
}

variable "gslt" {
  description = "Steam Game Server Login Token (app ID 440). Needed for the public server list; empty works for direct connect."
  type        = string
  default     = ""
  sensitive   = true
}
