terraform {
  required_version = ">= 1.6"

  required_providers {
    oci = {
      source  = "oracle/oci"
      version = ">= 6.0"
    }
    random = {
      source  = "hashicorp/random"
      version = ">= 3.6"
    }
  }
}

# Authenticates with the API key in ~/.oci/config; no credentials live in this repo.
provider "oci" {
  config_file_profile = var.oci_profile
  region              = var.region
}
