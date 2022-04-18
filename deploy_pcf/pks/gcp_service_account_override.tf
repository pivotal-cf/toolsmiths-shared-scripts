// do not create service accounts and service account keys for PKS, because of terraform failure.
resource "google_service_account" "pks_master_node_service_account" {
  count        = 0
  account_id   = "${var.env_name}-pks-master-node"
  display_name = "${var.env_name} PKS Service Account"
}

resource "google_service_account" "pks_worker_node_service_account" {
  count        = 0
  account_id   = "${var.env_name}-pks-worker-node"
  display_name = "${var.env_name} PKS Service Account"
}
resource "google_service_account_key" "pks_master_node_service_account_key" {
  count              = 0
  service_account_id = "${google_service_account.pks_master_node_service_account.id}"
}

resource "google_service_account_key" "pks_worker_node_service_account_key" {
  count              = 0
  service_account_id = "${google_service_account.pks_worker_node_service_account.id}"
}
