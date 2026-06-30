terraform {
  required_providers {
    ansible = {
      source  = "ansible/ansible"
      version = "~> 1.3"
    }
  }
}

provider "ansible" {}
provider "google" {
  project = "cloud-playground-423618"
  region  = "southamerica-east1"
}


locals {
  public_keys = sensitive(file("${path.module}/id_ed25519.pub"))
  username = "lucas.polesello" // You can hack this to inject $HOSTNAME output so SSH runs smoothly
}

resource "google_service_account" "default" {
  account_id   = "default-sa"
  display_name = "Default SA for VM Instance"
}

resource "google_compute_instance" "bastion" {
  name         = "bastion"
  machine_type = "e2-micro"
  zone         = "southamerica-east1-b"

  scheduling {
    provisioning_model = "SPOT"
    preemptible        = true
    automatic_restart  = false
    instance_termination_action = "STOP"
  }

  desired_status = "RUNNING"

  tags = ["k8s"]

  metadata = {
    "ssh-keys" = "${local.username}:${local.public_keys}"
  }

  metadata_startup_script = file("${path.module}/bootstrap_search_domain.sh")

  boot_disk {
    initialize_params {
      image = "debian-cloud/debian-11"
      type = "pd-standard"
    }
  }

  network_interface {
    network    = google_compute_network.network.id
    subnetwork = google_compute_subnetwork.bastion.id
    network_ip = google_compute_address.bastion_internal.address

    access_config {
      nat_ip = google_compute_address.bastion_external.address
    }
  }

  service_account {
    # Google recommends custom service accounts that have cloud-platform scope and permissions granted via IAM Roles.
    email  = google_service_account.default.email
    scopes = ["cloud-platform"]
  }
}

resource "google_compute_instance" "server" {
  name         = "server"
  machine_type = "e2-micro"
  zone         = "southamerica-east1-b"

  scheduling {
    provisioning_model = "SPOT"
    preemptible        = true
    automatic_restart  = false
    instance_termination_action = "STOP"
  }

  desired_status = "RUNNING"

  tags = ["k8s"]

  metadata = {
    "ssh-keys" = "${local.username}:${local.public_keys}"
  }

  boot_disk {
    initialize_params {
      image = "debian-cloud/debian-11"
      type = "pd-standard"
    }
  }

  network_interface {
    network    = google_compute_network.network.id
    subnetwork = google_compute_subnetwork.server.id
    network_ip = google_compute_address.server_internal.address
  }

  service_account {
    # Google recommends custom service accounts that have cloud-platform scope and permissions granted via IAM Roles.
    email  = google_service_account.default.email
    scopes = ["cloud-platform"]
  }
}
resource "google_compute_instance" "node_1" {
  name         = "node-1"
  machine_type = "e2-micro"
  zone         = "southamerica-east1-b"

  scheduling {
    provisioning_model = "SPOT"
    preemptible        = true
    automatic_restart  = false
    instance_termination_action = "STOP"
  }

  tags = ["k8s"]

  desired_status = "RUNNING"

  metadata = {
    "ssh-keys" = "${local.username}:${local.public_keys}"
  }

  boot_disk {
    initialize_params {
      image = "debian-cloud/debian-11"
      type = "pd-standard"
    }
  }

  network_interface {
    network    = google_compute_network.network.id
    subnetwork = google_compute_subnetwork.node_1.id
    network_ip = google_compute_address.node_1_internal.address
  }

  service_account {
    # Google recommends custom service accounts that have cloud-platform scope and permissions granted via IAM Roles.
    email  = google_service_account.default.email
    scopes = ["cloud-platform"]
  }
}
resource "google_compute_instance" "node_2" {
  name         = "node-2"
  machine_type = "e2-micro"
  zone         = "southamerica-east1-b"

  scheduling {
    provisioning_model = "SPOT"
    preemptible        = true
    automatic_restart  = false
    instance_termination_action = "STOP"
  }

  desired_status = "RUNNING"

  tags = ["k8s"]

  metadata = {
    "ssh-keys" = "${local.username}:${local.public_keys}"
  }

  boot_disk {
    initialize_params {
      image = "debian-cloud/debian-11"
      type = "pd-standard"
    }
  }

  network_interface {
    network    = google_compute_network.network.id
    subnetwork = google_compute_subnetwork.node_2.id
    network_ip = google_compute_address.node_2_internal.address
  }

  service_account {
    # Google recommends custom service accounts that have cloud-platform scope and permissions granted via IAM Roles.
    email  = google_service_account.default.email
    scopes = ["cloud-platform"]
  }
}

resource "google_compute_network" "network" {
  name                    = "k8s-network"
  auto_create_subnetworks = false
}

resource "google_compute_subnetwork" "bastion" {
  name          = "k8s-subnet-bastion"
  ip_cidr_range = "10.200.0.0/24"
  network       = google_compute_network.network.id
}
resource "google_compute_address" "bastion_internal" {
  name         = "k8s-bastion-internal-ip"
  subnetwork   = google_compute_subnetwork.bastion.id
  address_type = "INTERNAL"
  address      = "10.200.0.2"
}
resource "google_compute_address" "bastion_external" {
  name         = "k8s-bastion-external-ip"
  address_type = "EXTERNAL"
}
resource "google_compute_subnetwork" "server" {
  name          = "k8s-subnet-server"
  ip_cidr_range = "10.200.1.0/24"
  network       = google_compute_network.network.id
}
resource "google_compute_address" "server_internal" {
  name         = "k8s-server-internal-ip"
  subnetwork   = google_compute_subnetwork.server.id
  address_type = "INTERNAL"
  address      = "10.200.1.2"
}
resource "google_compute_subnetwork" "node_1" {
  name          = "k8s-subnet-node-1"
  ip_cidr_range = "10.200.2.0/24"
  network       = google_compute_network.network.id
}
resource "google_compute_address" "node_1_internal" {
  name         = "k8s-node-1-internal-ip"
  subnetwork   = google_compute_subnetwork.node_1.id
  address_type = "INTERNAL"
  address      = "10.200.2.2"
}
resource "google_compute_subnetwork" "node_2" {
  name          = "k8s-subnet-node-2"
  ip_cidr_range = "10.200.3.0/24"
  network       = google_compute_network.network.id
}

resource "google_compute_address" "node_2_internal" {
  name         = "k8s-node-2-internal-ip"
  subnetwork   = google_compute_subnetwork.node_2.id
  address_type = "INTERNAL"
  address      = "10.200.3.2"
}

resource "google_compute_firewall" "bastion_ssh" {
  name        = "bastion-ssh"
  network     = google_compute_network.network.id

  allow {
    protocol  = "tcp"
    ports     = ["22"]
  }

  source_ranges = ["0.0.0.0/0"]
  target_tags = ["k8s"]
}
resource "google_compute_firewall" "api-server" {
  name        = "api-server"
  network     = google_compute_network.network.id

  allow {
    protocol  = "tcp"
    ports     = ["6443"]
  }

  source_tags = ["k8s"]
  target_tags = ["k8s"]
}

resource "google_dns_managed_zone" "dns_zone" {
  name        = "k8s-dns-zone"
  dns_name    = "kubernetes.local."
  labels = {
    name = "k8s"
  }
  visibility = "private"
  private_visibility_config {
    networks { 
      network_url = google_compute_network.network.self_link
    }
  }
}

resource "google_dns_record_set" "server" {
  name = "server.${google_dns_managed_zone.dns_zone.dns_name}"
  type = "A"
  ttl  = 300

  managed_zone = google_dns_managed_zone.dns_zone.name

  rrdatas = [google_compute_address.server_internal.address]
}

resource "google_dns_record_set" "node-1" {
  name = "node-1.${google_dns_managed_zone.dns_zone.dns_name}"
  type = "A"
  ttl  = 300

  managed_zone = google_dns_managed_zone.dns_zone.name

  rrdatas = [google_compute_address.node_1_internal.address]
}

resource "google_dns_record_set" "node-2" {
  name = "node-2.${google_dns_managed_zone.dns_zone.dns_name}"
  type = "A"
  ttl  = 300

  managed_zone = google_dns_managed_zone.dns_zone.name

  rrdatas = [google_compute_address.node_2_internal.address]
}

resource "ansible_host" "bastion" {
  name   = "bastion"
  groups = ["bastion"]

  variables = {
    external_ip = google_compute_instance.bastion.network_interface[0].access_config[0].nat_ip
    internal_ip = google_compute_instance.bastion.network_interface[0].network_ip
    ansible_host = google_compute_instance.bastion.network_interface[0].access_config[0].nat_ip
  }
}
resource "ansible_host" "server" {
  name   = "server"
  groups = [ansible_group.k8s_internal_nodes.name, "control-plane"]

  variables = {
    internal_ip = google_compute_instance.server.network_interface[0].network_ip
    ansible_host = google_compute_instance.server.network_interface[0].network_ip
  }
}
resource "ansible_host" "node_1" {
  name   = "node_1"
  groups = [ansible_group.worker_nodes.name, ansible_group.k8s_internal_nodes.name]

  variables = {
    internal_ip = google_compute_instance.node_1.network_interface[0].network_ip
    ansible_host = google_compute_instance.node_1.network_interface[0].network_ip
  }
}
resource "ansible_host" "node_2" {
  name   = "node_2"
  groups = [ansible_group.worker_nodes.name, ansible_group.k8s_internal_nodes.name]

  variables = {
    internal_ip = google_compute_instance.node_2.network_interface[0].network_ip
    ansible_host = google_compute_instance.node_2.network_interface[0].network_ip
  }
}

resource "ansible_group" "worker_nodes" {
  name = "worker-nodes"
}

resource "ansible_group" "k8s_internal_nodes" {
  name = "k8s_internal_nodes"
  variables = {
    # This might not be necessary to pass `-i id_ed25519` since the ansible.cfg already has it
    ansible_ssh_common_args = "-o ProxyCommand=\"ssh -i id_ed25519 -p 22 -W %h:%p -q ${google_compute_instance.bastion.network_interface[0].access_config[0].nat_ip}\""
  }
}
