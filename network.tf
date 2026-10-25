locals {
  compartment_id = coalesce(var.compartment_ocid, var.tenancy_ocid)
}

resource "oci_core_vcn" "tf2" {
  compartment_id = local.compartment_id
  display_name   = "${var.name}-vcn"
  cidr_blocks    = ["10.0.0.0/16"]
  dns_label      = "tf2vcn"
}

resource "oci_core_internet_gateway" "tf2" {
  compartment_id = local.compartment_id
  vcn_id         = oci_core_vcn.tf2.id
  display_name   = "${var.name}-igw"
  enabled        = true
}

resource "oci_core_route_table" "tf2" {
  compartment_id = local.compartment_id
  vcn_id         = oci_core_vcn.tf2.id
  display_name   = "${var.name}-rt"

  route_rules {
    destination       = "0.0.0.0/0"
    destination_type  = "CIDR_BLOCK"
    network_entity_id = oci_core_internet_gateway.tf2.id
  }
}

resource "oci_core_security_list" "tf2" {
  compartment_id = local.compartment_id
  vcn_id         = oci_core_vcn.tf2.id
  display_name   = "${var.name}-sl"

  egress_security_rules {
    destination = "0.0.0.0/0"
    protocol    = "all"
  }

  # SSH
  ingress_security_rules {
    source   = var.admin_cidr
    protocol = "6"
    tcp_options {
      min = 22
      max = 22
    }
  }

  # Game traffic
  ingress_security_rules {
    source   = "0.0.0.0/0"
    protocol = "17"
    udp_options {
      min = 27015
      max = 27015
    }
  }

  # RCON
  ingress_security_rules {
    source   = var.admin_cidr
    protocol = "6"
    tcp_options {
      min = 27015
      max = 27015
    }
  }

  # Path MTU discovery
  ingress_security_rules {
    source   = "0.0.0.0/0"
    protocol = "1"
    icmp_options {
      type = 3
      code = 4
    }
  }
}

resource "oci_core_subnet" "tf2" {
  compartment_id             = local.compartment_id
  vcn_id                     = oci_core_vcn.tf2.id
  display_name               = "${var.name}-subnet"
  cidr_block                 = "10.0.1.0/24"
  dns_label                  = "public"
  route_table_id             = oci_core_route_table.tf2.id
  security_list_ids          = [oci_core_security_list.tf2.id]
  prohibit_public_ip_on_vnic = false
}
