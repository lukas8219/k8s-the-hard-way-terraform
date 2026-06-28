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
  name         = "k8s-bastion"
  machine_type = "e2-micro"
  zone         = "southamerica-east1-b"

  scheduling {
    provisioning_model = "SPOT"
    preemptible        = true
    automatic_restart  = false
  }

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
    network    = google_compute_network.k8s_network.id
    subnetwork = google_compute_subnetwork.k8s_subnet.id
    network_ip = google_compute_address.k8s_bastion_internal_ip.address

    access_config {
      nat_ip = google_compute_address.k8s_bastion_external_ip.address
    }
  }

  service_account {
    # Google recommends custom service accounts that have cloud-platform scope and permissions granted via IAM Roles.
    email  = google_service_account.default.email
    scopes = ["cloud-platform"]
  }
}

resource "google_compute_instance" "server" {
  name         = "k8s-server"
  machine_type = "e2-micro"
  zone         = "southamerica-east1-b"

  scheduling {
    provisioning_model = "SPOT"
    preemptible        = true
    automatic_restart  = false
  }

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
    network    = google_compute_network.k8s_network.id
    subnetwork = google_compute_subnetwork.k8s_subnet.id
    network_ip = google_compute_address.k8s_server_internal_ip.address
  }

  service_account {
    # Google recommends custom service accounts that have cloud-platform scope and permissions granted via IAM Roles.
    email  = google_service_account.default.email
    scopes = ["cloud-platform"]
  }
}
resource "google_compute_instance" "node_1" {
  name         = "k8s-server"
  machine_type = "e2-micro"
  zone         = "southamerica-east1-b"

  scheduling {
    provisioning_model = "SPOT"
    preemptible        = true
    automatic_restart  = false
  }

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
    network    = google_compute_network.k8s_network.id
    subnetwork = google_compute_subnetwork.k8s_subnet.id
    network_ip = google_compute_address.k8s_node_1_internal_ip.address
  }

  service_account {
    # Google recommends custom service accounts that have cloud-platform scope and permissions granted via IAM Roles.
    email  = google_service_account.default.email
    scopes = ["cloud-platform"]
  }
}
resource "google_compute_instance" "node_2" {
  name         = "k8s-server"
  machine_type = "e2-micro"
  zone         = "southamerica-east1-b"

  scheduling {
    provisioning_model = "SPOT"
    preemptible        = true
    automatic_restart  = false
  }

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
    network    = google_compute_network.k8s_network.id
    subnetwork = google_compute_subnetwork.k8s_subnet.id
    network_ip = google_compute_address.k8s_node_2_internal_ip.address
  }

  service_account {
    # Google recommends custom service accounts that have cloud-platform scope and permissions granted via IAM Roles.
    email  = google_service_account.default.email
    scopes = ["cloud-platform"]
  }
}

resource "google_compute_network" "k8s_network" {
  name                    = "k8s-network"
  auto_create_subnetworks = false
}

resource "google_compute_subnetwork" "k8s_subnet" {
  name          = "k8s-subnet"
  ip_cidr_range = "10.200.0.0/16"
  network       = google_compute_network.k8s_network.id
}

resource "google_compute_address" "k8s_bastion_internal_ip" {
  name         = "k8s-bastion-internal-ip"
  subnetwork   = google_compute_subnetwork.k8s_subnet.id
  address_type = "INTERNAL"
  address      = "10.200.0.2"
}

resource "google_compute_address" "k8s_server_internal_ip" {
  name         = "k8s-server-internal-ip"
  subnetwork   = google_compute_subnetwork.k8s_subnet.id
  address_type = "INTERNAL"
  address      = "10.200.0.3"
}
resource "google_compute_address" "k8s_node_1_internal_ip" {
  name         = "k8s-node-1-internal-ip"
  subnetwork   = google_compute_subnetwork.k8s_subnet.id
  address_type = "INTERNAL"
  address      = "10.200.0.4"
}
resource "google_compute_address" "k8s_node_2_internal_ip" {
  name         = "k8s-node-2-internal-ip"
  subnetwork   = google_compute_subnetwork.k8s_subnet.id
  address_type = "INTERNAL"
  address      = "10.200.0.5"
}

resource "google_compute_address" "k8s_bastion_external_ip" {
  name         = "k8s-bastion-external-ip"
  address_type = "EXTERNAL"
}

resource "google_compute_firewall" "bastion_ssh" {
  name        = "bastion-ssh"
  network     = google_compute_network.k8s_network.id

  allow {
    protocol  = "tcp"
    ports     = ["22"]
  }

  source_ranges = ["0.0.0.0/0"]
  target_tags = ["k8s"]
}

resource "google_dns_managed_zone" "k8s_dns_zone" {
  name        = "k8s-dns-zone"
  dns_name    = "kubernetes.local."
  labels = {
    name = "k8s"
  }
  visibility = "private"
  private_visibility_config {
    networks { 
      network_url = google_compute_network.k8s_network.self_link
    }
  }
}

resource "google_dns_record_set" "server" {
  name = "server.${google_dns_managed_zone.k8s_dns_zone.dns_name}"
  type = "A"
  ttl  = 300

  managed_zone = google_dns_managed_zone.k8s_dns_zone.name

  rrdatas = [google_compute_address.k8s_server_internal_ip.address]
}

resource "google_dns_record_set" "node-1" {
  name = "node-1.${google_dns_managed_zone.k8s_dns_zone.dns_name}"
  type = "A"
  ttl  = 300

  managed_zone = google_dns_managed_zone.k8s_dns_zone.name

  rrdatas = [google_compute_address.k8s_node_1_internal_ip.address]
}

resource "google_dns_record_set" "node-2" {
  name = "node-2.${google_dns_managed_zone.k8s_dns_zone.dns_name}"
  type = "A"
  ttl  = 300

  managed_zone = google_dns_managed_zone.k8s_dns_zone.name

  rrdatas = [google_compute_address.k8s_node_2_internal_ip.address]
}
