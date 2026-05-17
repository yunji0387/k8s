# Homelab k8s Roadmap

## Current State
```
OptiPlex (k3s, single node)
└── homelab namespace
    ├── nextcloud ✅
    ├── mariadb ✅
    ├── stirling-pdf ✅
    ├── jellyfin ✅
    └── pihole ✅
```

---

## Phase 1 — SSH via Cloudflare (Do this now)
**Goal**: Secure remote SSH access without opening router ports

- [x] Install cloudflared on OptiPlex as systemd service
- [x] Create Cloudflare tunnel
- [x] Route `ssh.domain.com` → `localhost:22`
- [x] Install cloudflared on client machines
- [x] Set up Zero Trust Access policy (restrict to your email)

**Result**: SSH from anywhere securely

---

## Phase 2 — Expose Apps via Cloudflare *(in progress)*
**Goal**: Access Nextcloud and future apps from the internet

- [x] Add app routes to cloudflared config (`cloud-optiplex.area87.uk` → Traefik) — see `cloudflared-config.yaml`
- [x] Create Traefik Ingress for Nextcloud — see `nextcloud/nextcloud-ingress.yaml`
- [x] Update Nextcloud trusted domain to `cloud-optiplex.area87.uk` — see `nextcloud/nextcloud-trusted-domain.sh`
- [x] Deploy Jellyfin (`jellyfin-optiplex.area87.uk`) — see `jellyfin.yaml`
- [x] Deploy Stirling PDF (`pdf-optiplex.area87.uk`) — see `stirling-pdf.yaml`
- [x] Deploy Pi-hole - see `pihole.yaml`

**Result**: All apps accessible via clean domain names

---

## Phase 2.1 — Update Nextcloud Version
**Goal**: Bring Nextcloud Hub 8 (NC 29.0.16) up to latest stable

> Must upgrade **one major version at a time** — skipping versions corrupts the database.

- [ ] Confirm current version (`php occ status`) — currently Hub 8 (NC 29.0.16)
- [ ] Upgrade NC 29 → 30
- [ ] Upgrade NC 30 → 31
- [ ] Verify all apps/data intact after each upgrade

See `nextcloud/nextcloud-version-upgrade.md` for full steps and journal.

---

## Phase 3 — Harden & Organize (Ongoing)
**Goal**: Production-grade homelab practices

- [ ] Set up Sealed Secrets (safe credential storage in Git)
- [ ] Install Longhorn (proper persistent storage with UI + backups)
- [ ] Set up monitoring (Prometheus + Grafana)
- [ ] Automate backups for Nextcloud data
- [ ] Move cloudflared into k8s deployment (prep for multi-node)

---

## Phase 4 — Multi-node Expansion (When you have hardware)
**Goal**: True distributed Kubernetes cluster

- [ ] Provision new machine with Ubuntu Server
- [ ] Join as k3s worker node
- [x] Install MetalLB (LoadBalancer for bare metal)
- [ ] Migrate cloudflared to k8s pod (point to Traefik cluster service)
- [ ] Configure Longhorn to replicate volumes across nodes
- [ ] Consider kube-vip for HA control plane (2+ control plane nodes)

**Join command (when ready):**
```bash
# On OptiPlex — get token
sudo cat /var/lib/rancher/k3s/server/node-token

# On new node
curl -sfL https://get.k3s.io | K3S_URL=https://<control-plane-ip>:6443 K3S_TOKEN=<token> sh -
```

---

## Target Architecture (Phase 4)
```
Internet
    ↓
Cloudflare Tunnel
    ↓
cloudflared pod (k8s)
    ↓
Traefik (Ingress Controller)
    ↓
┌──────────────────────────┐
│  k3s Cluster             │
│  ┌─────────┐ ┌────────┐  │
│  │OptiPlex │ │Node 2  │  │
│  │(control)│ │(worker)│  │
│  └─────────┘ └────────┘  │
│  Longhorn (shared storage)│
└──────────────────────────┘
```
