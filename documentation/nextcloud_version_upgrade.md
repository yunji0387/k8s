# Nextcloud Version Upgrade Guide
> Homelab — OptiPlex k3s cluster

---

## Current State

| Field | Value |
|---|---|
| Starting version | Hub 8 (NC 29.0.16) |
| Target version | NC 31 (latest stable) |
| Upgrade path | 29 → 30 → 31 |

Check live version at any time:
```bash
POD=$(kubectl get pod -n homelab -l app=nextcloud -o jsonpath='{.items[0].metadata.name}')
kubectl exec -n homelab "$POD" -- su -s /bin/sh www-data -c "php occ status"
```

---

## Rules

- **Never skip a major version.** Nextcloud's database migrations are incremental — jumping from 27 → 30 will corrupt the DB.
- **Wait for each upgrade to fully complete** before bumping again. Watch logs until the pod is Running and healthy.
- **Back up the PVC data before starting.** See pre-upgrade checklist below.
- **Pin image tags** — never use `nextcloud:latest` during an upgrade sequence.

---

## Pre-Upgrade Checklist

Run before the very first upgrade and optionally before each step:

```bash
# 1. Check pod is healthy
kubectl get pods -n homelab

# 2. Check for any background jobs stuck
kubectl exec -n homelab "$POD" -- su -s /bin/sh www-data -c "php occ background:job-worker --help"

# 3. Enable maintenance mode (prevents writes during upgrade)
kubectl exec -n homelab "$POD" -- su -s /bin/sh www-data -c "php occ maintenance:mode --on"

# 4. Back up the Nextcloud PVC (local-path data)
sudo tar -czf ~/nextcloud-backup-$(date +%Y%m%d).tar.gz \
  /var/lib/rancher/k3s/storage/

# 5. Turn maintenance mode back off if aborting, or leave on during upgrade
kubectl exec -n homelab "$POD" -- su -s /bin/sh www-data -c "php occ maintenance:mode --off"
```

---

## Upgrade Steps (repeat for each version)

### 1. Edit `nextcloud.yaml` — bump the image tag

```yaml
containers:
  - name: nextcloud
    image: nextcloud:28   # change this each time
```

### 2. Apply and watch

```bash
kubectl apply -f ~/k8s/clusters/area87/homelab/nextcloud/nextcloud.yaml
kubectl get pods -n homelab -w
```

The pod will restart, run DB migrations, then reach `Running`. This can take a few minutes.

### 3. Verify

```bash
kubectl exec -n homelab "$POD" -- su -s /bin/sh www-data -c "php occ status"
kubectl exec -n homelab "$POD" -- su -s /bin/sh www-data -c "php occ upgrade"
kubectl exec -n homelab "$POD" -- su -s /bin/sh www-data -c "php occ db:add-missing-indices"
```

### 4. Check the web UI

Open `https://cloud-optiplex.area87.uk` — confirm login works and files are intact.

### 5. Repeat for the next version

---

## Upgrade Journal

| Date | From | To | Result | Notes |
|---|---|---|---|---|
| | 29 | 30 | | |
| | 30 | 31 | | |

---

## Post-Upgrade Cleanup

After reaching the target version:

```bash
# Disable maintenance mode if left on
kubectl exec -n homelab "$POD" -- su -s /bin/sh www-data -c "php occ maintenance:mode --off"

# Run any missing DB migrations
kubectl exec -n homelab "$POD" -- su -s /bin/sh www-data -c "php occ db:add-missing-indices"
kubectl exec -n homelab "$POD" -- su -s /bin/sh www-data -c "php occ db:convert-filecache-bigint"

# Update all apps
kubectl exec -n homelab "$POD" -- su -s /bin/sh www-data -c "php occ app:update --all"
```

---

## Rollback

If an upgrade breaks the pod:

```bash
# Revert the image tag in nextcloud.yaml to the previous version, then:
kubectl apply -f ~/k8s/clusters/area87/homelab/nextcloud/nextcloud.yaml

# Restore PVC data from backup if needed
sudo tar -xzf ~/nextcloud-backup-<date>.tar.gz -C /
```
