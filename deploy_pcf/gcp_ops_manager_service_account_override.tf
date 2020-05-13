resource "google_service_account" "opsman_service_account" {
  count = 0
  account_id   = "${var.env_name}-opsman"
  display_name = "${var.env_name} Ops Manager VM Service Account"
}

resource "google_service_account_key" "opsman_service_account_key" {
  count = 0
  service_account_id = "${google_service_account.opsman_service_account.id}"
}

resource "google_compute_instance" "ops-manager" {
  name         = "${var.env_name}-ops-manager"
  machine_type = "${var.opsman_machine_type}"
  zone         = "${element(var.zones, 1)}"
  tags         = ["${var.env_name}-ops-manager-external"]

  timeouts {
    create = "10m"
  }

  boot_disk {
    initialize_params {
      image = "${google_compute_image.ops-manager-image.self_link}"
      size  = 150
      type = "pd-ssd"
    }
  }

  network_interface {
    subnetwork = "${google_compute_subnetwork.management-subnet.name}"

    access_config {
      nat_ip = "${google_compute_address.ops-manager-ip.address}"
    }
  }

  service_account {
    scopes = ["cloud-platform"]
  }

  metadata = {
    ssh-keys               = "${format("ubuntu:%s", tls_private_key.ops-manager.public_key_openssh)}"
    block-project-ssh-keys = "TRUE"
  }
}

output "service_account_email" {
  value = "${element(concat(google_service_account.opsman_service_account.*.email, list("")), 0)}"
}

