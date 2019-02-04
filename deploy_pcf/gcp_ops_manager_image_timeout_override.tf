resource "google_compute_image" "ops-manager-image" {
  timeouts {
    create = "90m"
  }
}
