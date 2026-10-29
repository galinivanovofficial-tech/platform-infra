# platform-infra

Infrastructure for a production membership web platform (Node.js) running on Google Cloud.

| Level | What | Status |
|---|---|---|
| 1 | Terraform: the existing VM, firewall and static IP adopted into code, state in GCS | done |
| 2 | Containerised app: Docker image in a private Artifact Registry, deployed with a health check and automatic rollback | done |
| 3 | CI/CD: every push is built, smoke-tested and deployed automatically, with keyless auth and automatic rollback | done |
| 4 | Monitoring and alerting: uptime checks from several regions, email alerts for site down, missing backups and high CPU | done |
| 5 | Backups and restore drills | daily disk snapshots + hourly database backups to Cloud Storage, both restore-tested ([runbook](docs/runbook-restore.md)) |

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

## Level 3: CI/CD

```
git push (dev) ─► GitHub Actions: build ─► smoke test ─► push image :<commit>
                                              │ fails: nothing is pushed
                                              ▼
server timer (every 2 min) ─► newer image? ─► legion-deploy: pull, swap, health check
                                                 │ fails: roll back, never retry that tag
```

- **Keyless auth** (`terraform/ci.tf`): GitHub Actions gets a short-lived OIDC token that Google
  exchanges through Workload Identity Federation. Only the site repository is accepted, and the
  `github-ci` account can do one thing: push images to the `web` registry. No keys are stored anywhere.
- **Pull-based deploy** (`server/autodeploy.sh` + `legion-autodeploy.timer`): the server checks the
  registry itself, so CI has no credentials or network access to production.
- **Three safety gates**: the smoke test stops an image that does not start; `legion-deploy` rolls back
  if the new container fails its health check; a tag that failed is remembered and not retried.

Tested on 2026-10-29:

| Test | Result |
|---|---|
| Normal change pushed | live in about 1 min 45 s, no manual steps |
| Commit with a broken start command | build passed, smoke test failed, push skipped, site stayed up |
| `git revert` of the broken commit | shipped automatically, site healthy |

Known trade-offs: every push to `dev` goes to production (no staging environment yet); the smoke
test only checks that the site loads; the deploy timer runs as root because it controls Docker.

## Level 5: Hourly database backups

Daily disk snapshots alone meant up to 24 hours of data could be lost. An hourly,
application-level backup brings that down to one hour.

- `server/db-backup.sh`: SQLite's online backup makes a clean copy while the site keeps running,
  `PRAGMA integrity_check` must pass, then the copy is compressed and uploaded to Cloud Storage.
  It authenticates with the VM's own identity from the metadata server, so no keys live on the server.
- `server/legion-db-backup.timer`: runs it every hour as the unprivileged `legion` user, with
  systemd hardening (read-only system, private `/tmp`, no privilege escalation).
- `terraform/backups.tf`: a private, versioned bucket that deletes backups after 30 days.
- `terraform/iam.tf`: the server runs as a dedicated service account that can only **create**
  objects in that bucket, so even a compromised server cannot read or delete the backups.

| | Before | After |
|---|---|---|
| Backup frequency | daily | hourly |
| Max data loss (RPO) | up to 24 hours | up to 1 hour |
| Consistency | crash-consistent disk snapshot | application-consistent copy, integrity-checked |

## Cost: staying inside the free tier

The whole platform is meant to cost $0. `terraform/budget.tf` sets a $1 budget that emails at the
first cent of spend (and at 50% and 100%), so any drift out of the free tier is noticed the same day.
Disk snapshots are kept 7 days (not 14) to stay under the 5 GB snapshot allowance; the hourly
database backups cover the longer history.