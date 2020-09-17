resource "google_compute_instance" "ops-manager" {
  boot_disk {
    initialize_params {
      image = "${var.opsman_image_url}"
      size = 150
    }
  }
}
