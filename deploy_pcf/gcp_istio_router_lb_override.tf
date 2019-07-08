resource "google_compute_firewall" "cf-mesh" {
  name    = "${var.env_name}-cf-mesh"
  network = "${google_compute_network.pcf-network.name}"

  allow {
    protocol = "tcp"
    ports    = ["80", "443"]
  }

  target_tags = ["${var.env_name}-cf-mesh"]
}

resource "google_compute_address" "cf-mesh" {
  name = "${var.env_name}-cf-mesh"
}

resource "google_compute_http_health_check" "cf-mesh" {
  name                = "${var.env_name}-cf-mesh"
  port                = 8002
  check_interval_sec  = 5
  timeout_sec         = 3
  healthy_threshold   = 3
  unhealthy_threshold = 3
}

resource "google_compute_target_pool" "cf-mesh" {
  name = "${var.env_name}-cf-mesh"

  health_checks = [
    "${google_compute_http_health_check.cf-mesh.name}",
  ]
}

resource "google_compute_forwarding_rule" "cf-mesh-https" {
  name        = "${var.env_name}-cf-mesh-https"
  target      = "${google_compute_target_pool.cf-mesh.self_link}"
  port_range  = "443"
  ip_protocol = "TCP"
  ip_address  = "${google_compute_address.cf-mesh.address}"
}

resource "google_compute_forwarding_rule" "cf-mesh-http" {
  name        = "${var.env_name}-cf-mesh-http"
  target      = "${google_compute_target_pool.cf-mesh.self_link}"
  port_range  = "80"
  ip_protocol = "TCP"
  ip_address  = "${google_compute_address.cf-mesh.address}"
}

resource "google_dns_record_set" "wildcard-mesh-apps-dns" {
  name = "*.mesh.apps.${google_dns_managed_zone.env_dns_zone.dns_name}"
  type = "A"
  ttl  = 300

  managed_zone = "${google_dns_managed_zone.env_dns_zone.name}"

  rrdatas = ["${google_compute_address.cf-mesh.address}"]
}

output "mesh_router_pool" {
  value = "${google_compute_firewall.cf-mesh.name}"
}
