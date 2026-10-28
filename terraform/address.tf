# Static external IP for the web server.
# `address` is set to the IP the VM already uses, so Google promotes the
# existing ephemeral IP to static instead of allocating a new one: the
# address (and DNS) stays the same, and a stop/start can no longer change it.
resource "google_compute_address" "web" {
  name         = "ivth-legion-ip"
  region       = var.region
  address      = "136.71.178.20"
  address_type = "EXTERNAL"
  network_tier = "PREMIUM"
}
