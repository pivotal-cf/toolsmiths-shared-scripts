resource "google_dns_record_set" "wildcard-sys-dns" {
  rrdatas = ["${google_compute_address.cf-ws.address}"]
}

resource "google_dns_record_set" "wildcard-apps-dns" {
  rrdatas = ["${google_compute_address.cf-ws.address}"]
}

