
terraform {
  required_providers {
    ansible = {
      source  = "ansible/ansible"
      version = "~> 1.3"
    }
  }
}

variable "public_key" {}
variable "username" {}
variable "service_account_email" {}
variable "network" {}
variable "startup_script" {
  default = null
}
variable "has_public_ip" {
  default = false
}
variable "ip_cidr" {}
variable "name" {}
variable "dns_name" {}
variable "dns_zone" {}

resource "google_compute_instance" "node" {
  name         = var.name ## how to generate a better name
  machine_type = "e2-micro"
  zone         = "southamerica-east1-b"

  scheduling {
    provisioning_model          = "SPOT"
    preemptible                 = true
    automatic_restart           = false
    instance_termination_action = "STOP"
  }

  desired_status = "RUNNING"

  tags = ["k8s"]

  metadata = {
    "ssh-keys" = "${var.username}:${var.public_key}"
  }

  metadata_startup_script = var.startup_script

  boot_disk {
    initialize_params {
      image = "debian-cloud/debian-11"
      type  = "pd-standard"
    }
  }

  network_interface {
    network    = var.network 
    subnetwork = google_compute_subnetwork.node.id
    network_ip = google_compute_address.internal.address

    access_config {
      nat_ip = var.has_public_ip ? google_compute_address.external[0].address : null
    }
  }

  service_account {
    # Google recommends custom service accounts that have cloud-platform scope and permissions granted via IAM Roles.
    email  = var.service_account_email
    scopes = ["cloud-platform"]
  }
}

resource "google_compute_subnetwork" "node" {
  name          = "${var.name}-subnet"
  ip_cidr_range = var.ip_cidr
  network       = var.network
}
resource "google_compute_address" "internal" {
  name         = "${var.name}-internal"
  subnetwork   = google_compute_subnetwork.node.id
  address_type = "INTERNAL"
  address      = cidrhost(var.ip_cidr, 2)
}
resource "google_compute_address" "external" {
  count = var.has_public_ip ? 1 : 0
  name         = "${var.name}-external"
  address_type = "EXTERNAL"
}

resource "google_dns_record_set" "node" {
  name = "${var.name}.${var.dns_zone}"
  type = "A"
  ttl  = 300

  managed_zone = var.dns_name

  rrdatas = [google_compute_address.internal.address]
}

output "external_ip" {
  value = var.has_public_ip ? google_compute_address.external[0].address : null
}
output "internal_ip" {
  value = google_compute_address.internal.address
}
output "subnet_id" {
  value = google_compute_subnetwork.node.id
}
output "name" {
  value = var.name
}
output "ip_cidr" {
  value = var.ip_cidr
}
