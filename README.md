# platform-infra

Infrastructure for a production membership web platform (Node.js) running on Google Cloud.

| Level | What | Status |
|---|---|---|
| 1 | Terraform: the existing VM, firewall and static IP adopted into code, state in GCS | in progress |
| 2 | Containerised app, image in a registry | planned |
| 3 | CI/CD: tests, build, deploy, smoke test, rollback | planned |
| 4 | Monitoring and alerting | planned |
| 5 | Backups and restore drills | planned |

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
