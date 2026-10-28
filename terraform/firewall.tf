# Firewall rules for the web server (adopted from the console-created defaults).
# Rules apply only to VMs carrying the matching network tag.

resource "google_compute_firewall" "allow_http" {
  name          = "default-allow-http"
  network       = "default"
  direction     = "INGRESS"
  priority      = 1000
  source_ranges = ["0.0.0.0/0"]
  target_tags   = ["http-server"]

  allow {
    protocol = "tcp"
    ports    = ["80"]
  }
}

resource "google_compute_firewall" "allow_https" {
  name          = "default-allow-https"
  network       = "default"
  direction     = "INGRESS"
  priority      = 1000
  source_ranges = ["0.0.0.0/0"]
  target_tags   = ["https-server"]

  allow {
    protocol = "tcp"
    ports    = ["443"]
  }
}

resource "google_compute_firewall" "allow_ssh" {
  name          = "default-allow-ssh"
  network       = "default"
  description   = "Allow SSH from anywhere"
  direction     = "INGRESS"
  priority      = 65534
  source_ranges = ["0.0.0.0/0"]

  allow {
    protocol = "tcp"
    ports    = ["22"]
  }
}
