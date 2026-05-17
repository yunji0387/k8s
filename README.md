# homelab-k8s

Personal Kubernetes homelab running on a Dell OptiPlex 7060 Micro with k3s. Includes production-grade homelab apps exposed via Cloudflare Tunnel, with planned expansion into dev/QA clusters and multi-node setup.

---

## Hardware

| Component | Spec |
|---|---|
| Machine | Dell OptiPlex 7060 Micro |
| OS | Ubuntu Server |
| Kubernetes | k3s (single node) |
| Cluster name | `area87` |

---

## Current State

```
area87 (k3s, single node)
└── homelab namespace
    ├── nextcloud + mariadb  ✅  cloud-optiplex.area87.uk
    ├── stirling-pdf         ✅  pdf-optiplex.area87.uk
    ├── jellyfin             ✅  jellyfin-optiplex.area87.uk
    └── pihole               ✅  pihole-optiplex.area87.uk (LAN only)
```

Public access is provided via **Cloudflare Tunnel → Traefik** (k3s built-in ingress controller). No router ports are opened.

---

## Repository Structure

```
clusters/
└── area87/                        # production homelab cluster
    ├── namespaces.yaml
    └── homelab/
        ├── nextcloud/
        │   ├── mariadb.yaml
        │   ├── nextcloud.yaml
        │   ├── nextcloud-ingress.yaml
        │   └── nextcloud-trusted-domain.sh
        ├── jellyfin/
        │   └── jellyfin.yaml
        ├── pihole/
        │   └── pihole.yaml
        └── stirling-pdf/
            └── stirling-pdf.yml

documentation/
├── k8s_guide.md                   # setup & reference notes
├── k8s_roadmap.md                 # phased plan
└── nextcloud_version_upgrade.md   # upgrade journal
```

> **Secrets are never committed.** Files matching `*secret*.yaml`, `*secrets*.yaml`, `*.env` are excluded via `.gitignore`.

---

## Networking

```
Internet → Cloudflare → cloudflared (systemd) → Traefik (k3s) → Service → Pod
```

| Hostname | App |
|---|---|
| `cloud-optiplex.area87.uk` | Nextcloud |
| `pdf-optiplex.area87.uk` | Stirling PDF |
| `jellyfin-optiplex.area87.uk` | Jellyfin |
| `pihole-optiplex.area87.uk` | Pi-hole admin (LAN only) |
| `ssh-optiplex.area87.uk` | SSH (Zero Trust) |

All hostnames are protected by **Cloudflare Zero Trust Access** (email-restricted).

---

## Roadmap

### Phase 2 — Expose Apps *(in progress)*
- [x] Nextcloud via Traefik ingress + Cloudflare Tunnel
- [x] Stirling PDF
- [x] Jellyfin
- [x] Pi-hole (LAN DNS, admin UI local only)
- [ ] Nextcloud version upgrade (29 → 30 → 31, one major at a time)

### Phase 3 — Harden & Observe
- [ ] Sealed Secrets (safe Git credential storage)
- [ ] Longhorn (distributed block storage, snapshots, UI)
- [ ] Prometheus + Grafana monitoring
- [ ] Automated Nextcloud backups
- [ ] Move `cloudflared` into k8s deployment

### Phase 4 — Multi-node Cluster
- [ ] Provision second node, join as k3s worker
- [x] MetalLB for bare-metal LoadBalancer support
- [ ] Longhorn volume replication across nodes
- [ ] kube-vip for HA control plane

### Future — Dev & QA Clusters
- [ ] Separate `dev` cluster for local development workflows
- [ ] Separate `qa` cluster for pre-production testing
- [ ] GitOps with Flux or ArgoCD
- [ ] Helm for app packaging

---

## Quick Reference

```bash
# Apply all manifests for an app
kubectl apply -f clusters/area87/homelab/nextcloud/

# Watch pods
kubectl get pods -n homelab -w

# Logs
kubectl logs -n homelab <pod> --tail=100

# Exec into pod
kubectl exec -it -n homelab <pod> -- bash
```

See [documentation/k8s_guide.md](documentation/k8s_guide.md) for full setup notes and kubectl reference.
