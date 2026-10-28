output "server_ip" {
  description = "Public static IP of the web server"
  value       = google_compute_address.web.address
}

output "server_name" {
  description = "Name of the web server VM"
  value       = google_compute_instance.web.name
}

output "ssh_command" {
  description = "Command to connect to the server over SSH"
  value       = "ssh -i ~/.ssh/oracle_legion ubuntu@${google_compute_address.web.address}"
}