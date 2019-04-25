resource "google_service_account" "opsman_service_account" {
  count = 0
  account_id   = "${var.env_name}-opsman"
  display_name = "${var.env_name} Ops Manager VM Service Account"
}

resource "google_service_account_key" "opsman_service_account_key" {
  count = 0
  service_account_id = "${google_service_account.opsman_service_account.id}"
}

output "service_account_email" {
  value = "${element(concat(google_service_account.opsman_service_account.email, list("")), 0)}"
}

