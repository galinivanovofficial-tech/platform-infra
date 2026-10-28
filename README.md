# platform-infra

Infrastructure for a production membership web platform (Node.js) running on Google Cloud.

| Level | What | Status |
|---|---|---|
| 1 | Terraform: the existing VM, firewall and static IP adopted into code, state in GCS | done |
| 2 | Containerised app, image in a registry | planned |
| 3 | CI/CD: tests, build, deploy, smoke test, rollback | planned |
| 4 | Monitoring and alerting | planned |
| 5 | Backups and restore drills | snapshots in Terraform, first restore drill passed ([runbook](docs/runbook-restore.md)) |

## Level 1: Infrastructure as Code

The server was first created by hand in the Cloud console. Level 1 brings it under Terraform
**without recreating it**, using `import` blocks, so the live site is never interrupted.

```bash
cd terraform
cp terraform.tfvars.example terraform.tfvars   # fill in project, zone, VM name
terraform init -backend-config="bucket=<state-bucket>"
terraform plan -generate-config-out=generated.tf   # Terraform writes the config from the real VM
terraform plan                                     # must show: 0 to add, 0 to change, 0 to destroy
```

### What level 1 found and fixed

A read-only audit before the import found three risks. Each was fixed through Terraform,
one reviewed plan at a time, and verified afterwards:

| Risk | Fix | Verified by |
|---|---|---|
| Ephemeral public IP: a stop/start could change it and break DNS | Promoted the existing IP to a static address (same IP, no downtime) | address `IN_USE` by the VM, site still responding |
| Default rule allowing RDP (3389) from anywhere on a Linux server | Removed the rule | port 3389 no longer answers from outside; 22 and 443 still do |
| No deletion protection on the production VM | `deletion_protection = true` (Google) plus `prevent_destroy` (Terraform) | `terraform plan -destroy` refuses to destroy the VM |
