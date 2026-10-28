# Runbook: restore the database from a disk snapshot

**When to use:** the site's SQLite database (`/var/lib/legion/legion.db`) is corrupted or data was lost.
**Backups:** daily disk snapshots (`default-schedule-1`, managed in `terraform/snapshots.tf`),
taken around 05:00 UTC and kept for 14 days. They survive deletion of the disk.

| Objective | Value |
|---|---|
| RPO (max data loss) | up to 24 hours (one snapshot per day) |
| RTO (time to recover, manual) | about 15–30 minutes |

Snapshots are **crash-consistent** (`guest_flush = false`), so always run the integrity check below.

## 1. Pick the snapshot
```bash
gcloud compute snapshots list --sort-by=~creationTimestamp --limit=5
```

## 2. Restore it to a new disk (the live disk is not touched)
```bash
gcloud compute disks create restore-drill --source-snapshot=<SNAPSHOT> \
  --zone=us-central1-f --type=pd-standard --labels=purpose=restore-drill
```

## 3. Attach it to the server read-only
```bash
gcloud compute instances attach-disk ivth-legion --disk=restore-drill --mode=ro --zone=us-central1-f
```

## 4. On the server: mount read-only and copy the database
```bash
lsblk                                            # the new disk is sdb, the data partition is the largest one
sudo mkdir -p /mnt/restore && sudo mount -o ro,noload /dev/sdb1 /mnt/restore
mkdir -p /tmp/drill && sudo cp /mnt/restore/var/lib/legion/legion.db* /tmp/drill/   # .db, -wal and -shm (WAL mode)
```

## 5. Verify the restored database
`PRAGMA integrity_check` must return `ok`; compare row counts with the live database
(the live one is opened read-only).
```bash
sudo node -e 'const {DatabaseSync}=require("node:sqlite");for(const [n,f,ro] of [["RESTORED","/tmp/drill/legion.db",false],["LIVE","/var/lib/legion/legion.db",true]]){const d=new DatabaseSync(f,{readOnly:ro});const c=t=>d.prepare("select count(*) c from "+t).get().c;console.log(n.padEnd(9),"integrity:",d.prepare("PRAGMA integrity_check").get().integrity_check,"| users:",c("users"),"| audit:",c("audit"))}'
```

## 6. Real recovery only: swap the database
```bash
sudo systemctl stop legion
sudo cp /var/lib/legion/legion.db* /root/legion-broken-$(date +%F)/   # keep the broken copy (create the folder first)
sudo cp /tmp/drill/legion.db* /var/lib/legion/ && sudo chown legion:legion /var/lib/legion/legion.db*
sudo systemctl start legion && systemctl is-active legion
```

## 7. Clean up (part of the procedure, not optional)
Order matters: unmount **before** detaching.
```bash
sudo umount /mnt/restore && sudo rmdir /mnt/restore && rm -rf /tmp/drill   # on the server: the copy holds user data
gcloud compute instances detach-disk ivth-legion --disk=restore-drill --zone=us-central1-f
gcloud compute disks delete restore-drill --zone=us-central1-f
terraform plan                                                              # must show: No changes
```

## Drill log

| Date | Snapshot | Disk restore | Integrity | Row counts vs live | Notes |
|---|---|---|---|---|---|
| 2026-10-28 | ivth-legion-…-20261028055150 | ~25 s | ok | identical (5 users, 116 audit rows) | Detached before unmounting, which left a stale mount; fixed with `umount -l`. Order corrected in step 7. |
