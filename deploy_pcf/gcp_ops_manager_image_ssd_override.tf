resource "google_compute_image" "ops-manager-image" {
  boot_disk {
    initialize_params {
      image = "${google_compute_image.ops-manager-image.self_link}"
      type  = "pd-ssd"
      size  = 150
    }
  }
}
