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
  username    = "lucas.polesello" // You can hack this to inject $HOSTNAME output so SSH runs smoothly
  tag = "k8s"
  provisioning = "STANDARD"
  dns_zone = "kubernetes.local."
  dns_name = google_dns_managed_zone.dns_zone.name

  cluster_cidr = "10.240.0.0/16"
  pod_cidr = "10.200.0.0/16"

  worker_count = 2
  non_worker_nodes_count = 2
  gateway_ip = 1 # skip the 0.0.0.1 because the network uses as gateway

  worker_nodes = {
    for i in range(local.worker_count) :
    "node-${i}" => {
      vm_ip = cidrhost(local.cluster_cidr, i + 1 + local.gateway_ip + local.non_worker_nodes_count),
      pod_ipcidr = cidrsubnet(local.pod_cidr, 8, i + 1 + local.non_worker_nodes_count),
    }
  }
}

resource "google_service_account" "default" {
  account_id   = "default-sa"
  display_name = "Default SA for VM Instance"
}

module "bastion" {
  name = "bastion"
  source = "./modules/nodes"
  public_key = local.public_keys
  username = local.username
  has_public_ip = true
  startup_script = file("${path.module}/bootstrap_search_domain.sh")
  network = google_compute_network.network.id
  service_account_email = google_service_account.default.email
  pod_ip_cidr = cidrsubnet(local.pod_cidr, 8, 1)
  vm_ip = cidrhost(local.cluster_cidr, 2)
  dns_zone = local.dns_zone
  dns_name = local.dns_name
  subnetwork = google_compute_subnetwork.subnet.id
  network_name = google_compute_network.network.name
}

module "server" {
  source = "./modules/nodes"
  name = "server"
  public_key = local.public_keys
  username = local.username
  network = google_compute_network.network.id
  service_account_email = google_service_account.default.email
  pod_ip_cidr = cidrsubnet(local.pod_cidr, 8, 1)
  vm_ip = cidrhost(local.cluster_cidr, 3)
  dns_zone = local.dns_zone
  dns_name = local.dns_name
  subnetwork = google_compute_subnetwork.subnet.id
  network_name = google_compute_network.network.name
}

module "worker_nodes" {
  source = "./modules/nodes"
  for_each = local.worker_nodes
  name = each.key
  public_key = local.public_keys
  username = local.username
  network = google_compute_network.network.id
  service_account_email = google_service_account.default.email
  pod_ip_cidr = each.value.pod_ipcidr
  vm_ip = each.value.vm_ip
  dns_zone = local.dns_zone
  dns_name = local.dns_name
  subnetwork = google_compute_subnetwork.subnet.id
  network_name = google_compute_network.network.name
}

resource "google_compute_network" "network" {
  name                    = "k8s-network"
  auto_create_subnetworks = false
}
resource "google_compute_subnetwork" "subnet" {
  name                    = "k8s-subnet"
  ip_cidr_range = local.cluster_cidr
  network = google_compute_network.network.id
}

resource "google_compute_router" "router" {
  name    = "router"
  network = google_compute_network.network.id
}

resource "google_compute_router_nat" "nat" {
  name                               = "nat"
  nat_ip_allocate_option             = "AUTO_ONLY"
  source_subnetwork_ip_ranges_to_nat = "ALL_SUBNETWORKS_ALL_IP_RANGES"
  router                             = google_compute_router.router.name

  log_config {
    enable = false
    filter = "ERRORS_ONLY"
  }
}

resource "google_compute_firewall" "bastion_ssh" {
  name    = "bastion-ssh"
  network = google_compute_network.network.id

  allow {
    protocol = "tcp"
    ports    = ["22"]
  }

  source_ranges = ["0.0.0.0/0"]
  target_tags   = [local.tag]
}
resource "google_compute_firewall" "inter_nodes" {
  name    = "k8s-internodes"
  network = google_compute_network.network.id

  allow {
    protocol = "tcp"
  }

  source_tags = [local.tag]
  target_tags = [local.tag]
}

resource "google_dns_managed_zone" "dns_zone" {
  name     = "k8s-dns-zone"
  dns_name = local.dns_zone 
  labels = {
    name = local.tag 
  }
  visibility = "private"
  private_visibility_config {
    networks {
      network_url = google_compute_network.network.self_link
    }
  }
}

resource "ansible_host" "bastion" {
  name   = "bastion"
  groups = ["bastion"]

  variables = {
    ansible_host = module.bastion.external_ip
  }
}
resource "ansible_host" "server" {
  name   = "server"
  groups = [ansible_group.k8s_internal_nodes.name, "control-plane"]

  variables = {
    ansible_host = module.server.internal_ip 
    subnet = module.server.pod_ip_cidr
  }
}
resource "ansible_host" "node" {
  for_each = module.worker_nodes
  name   = each.value.name
  groups = [ansible_group.worker_nodes.name, ansible_group.k8s_internal_nodes.name]

  variables = {
    ansible_host = each.value.internal_ip
    subnet       = each.value.pod_ip_cidr
  }
}

resource "ansible_group" "worker_nodes" {
  name = "worker-nodes"
}

resource "ansible_group" "k8s_internal_nodes" {
  name = "k8s_internal_nodes"
  variables = {
    # This might not be necessary to pass `-i id_ed25519` since the ansible.cfg already has it
    ansible_ssh_common_args = "-o StrictHostKeyChecking=accept-new -o ProxyCommand=\"ssh -i id_ed25519 -o StrictHostKeyChecking=accept-new -p 22 -W %h:%p -q ${module.bastion.external_ip}\""
    pod_cidr = local.pod_cidr
  }
}
