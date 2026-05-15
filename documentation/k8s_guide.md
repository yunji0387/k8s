# Kubernetes (k8s) Guide
> Based on Dell OptiPlex 7060 Micro running Ubuntu Server with k3s

---

## 1. What is Kubernetes (k8s)?

**Kubernetes** (abbreviated **k8s** — 8 letters between K and s) is an open-source container orchestration system that:
- Runs containers (Docker/containerd) across one or more machines
- Restarts failed containers automatically
- Scales apps up/down (more/fewer replicas)
- Load balances traffic between container instances
- Rolls out updates without downtime

**k3s** is a lightweight distribution of Kubernetes — same API, same `kubectl` commands, but smaller and easier to run on a single machine.

---

## 2. Setting Up Ubuntu Server

### Fix regional mirror 403 errors
```bash
sudo sed -i 's|http://my.archive.ubuntu.com/ubuntu|http://archive.ubuntu.com/ubuntu|g' /etc/apt/sources.list.d/ubuntu.sources
sudo apt update && sudo apt upgrade
```

### After kernel upgrade — reboot required
```bash
sudo reboot
uname -r  # verify new kernel is loaded
```

---

## 3. Installing k3s

```bash
curl -sfL https://get.k3s.io | sh -
```

### Verify installation
```bash
sudo systemctl status k3s
sudo kubectl get nodes
sudo kubectl get pods -A
```

### Set up kubectl without sudo
```bash
mkdir -p ~/.kube
sudo cp /etc/rancher/k3s/k3s.yaml ~/.kube/config
sudo chown $USER:$USER ~/.kube/config
echo 'export KUBECONFIG=~/.kube/config' >> ~/.bashrc
source ~/.bashrc
```

### Verify
```bash
kubectl get nodes
kubectl get pods -A
```

---

## 4. Core Concepts

### Resource hierarchy
```
Deployment → manages → ReplicaSet → manages → Pod → runs → Container
```

| Concept | What it does |
|---|---|
| **Pod** | Smallest unit — one or more containers |
| **Deployment** | Manages pods, handles restarts & scaling |
| **Service** | Exposes pods on the network |
| **ConfigMap** | Inject config/env vars into pods |
| **PersistentVolume** | Storage that survives pod restarts |
| **Ingress** | HTTP routing |
| **Namespace** | Logical isolation between workloads |
| **Secret** | Stores sensitive data (passwords, tokens) |

### Multi-container pod patterns

| Pattern | Purpose |
|---|---|
| **Sidecar** | Helper that enhances the main container (logging, metrics) |
| **Ambassador** | Proxy that handles network on behalf of main container |
| **Init container** | Runs before the main container to do setup |

---

## 5. Essential kubectl Commands

```bash
# View resources
kubectl get nodes
kubectl get pods -A                        # all namespaces
kubectl get pods -n <namespace>
kubectl get svc -n <namespace>
kubectl get all -n <namespace>

# Inspect
kubectl describe pod <pod-name> -n <namespace>
kubectl logs <pod-name> -n <namespace>
kubectl logs <pod-name> -c <container> -n <namespace>  # multi-container pod

# Execute into a pod
kubectl exec -it <pod-name> -n <namespace> -- bash

# Apply/delete manifests
kubectl apply -f <file.yaml>
kubectl apply -f <folder>/
kubectl delete -f <file.yaml>

# Scale
kubectl scale deployment <name> -n <namespace> --replicas=3

# Generate YAML without applying
kubectl create deployment nginx --image=nginx --dry-run=client -o yaml
```

### kubectl apply vs kubectl create

| Command | Behaviour |
|---|---|
| `kubectl apply` | Create if not exists, update if already exists (idempotent) |
| `kubectl create` | Create only — errors if already exists |

---

## 6. YAML Manifests

### Deployment example
```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: nginx
  namespace: homelab
spec:
  replicas: 1
  selector:
    matchLabels:
      app: nginx
  template:
    metadata:
      labels:
        app: nginx
    spec:
      containers:
      - name: nginx
        image: nginx
```

### Service (NodePort) example
```yaml
apiVersion: v1
kind: Service
metadata:
  name: nginx
  namespace: homelab
spec:
  selector:
    app: nginx
  ports:
  - port: 80
    targetPort: 80
    nodePort: 30080
  type: NodePort
```

### PersistentVolumeClaim example
```yaml
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: app-pvc
  namespace: homelab
spec:
  accessModes:
    - ReadWriteOnce
  resources:
    requests:
      storage: 10Gi
```

### Secret example
```yaml
apiVersion: v1
kind: Secret
metadata:
  name: app-secret
  namespace: homelab
type: Opaque
stringData:
  PASSWORD: changeme123
```

> **Never commit secret.yaml to Git.**

---

## 7. Namespaces

### When to use namespaces vs separate clusters

| Situation | Use |
|---|---|
| Different apps, same env | Namespaces |
| homelab vs dev vs prod | Separate clusters |
| Single machine | Namespaces (less overhead) |

### Create namespaces
```yaml
apiVersion: v1
kind: Namespace
metadata:
  name: homelab
---
apiVersion: v1
kind: Namespace
metadata:
  name: storage
```

```bash
kubectl apply -f namespaces.yaml
```

---

## 8. Storage

k3s ships with **local-path provisioner** — automatically creates `hostPath` volumes from PVCs. No setup needed.

Container images are stored at:
```
/var/lib/rancher/k3s/agent/containerd/
```

List cached images:
```bash
sudo k3s crictl images
```

### Future: Longhorn (recommended for homelab)
- Distributed block storage
- Snapshot/backup support
- Web UI for volume management
- Install into `storage` namespace

---

## 9. Folder Structure

```
~/k8s/
├── .gitignore
└── clusters/
    └── area87/                  # your homelab cluster
        ├── namespaces.yaml
        ├── homelab/
        │   ├── nextcloud/
        │   │   ├── secret.yaml          # NOT committed to git
        │   │   ├── mariadb.yaml
        │   │   ├── nextcloud.yaml
        │   │   └── ingress.yaml         # cloud-optiplex.area87.uk
        │   ├── jellyfin/                # planned — waiting for SATA SSD
        │   └── stirling-pdf/
        │       └── stirling-pdf.yaml    # pdf-optiplex.area87.uk
        └── storage/
```

### .gitignore
```
*secret*.yaml
*secrets*.yaml
*.env
kubeconfigs/
```

---

## 10. Git & GitHub

### Setup
```bash
sudo apt install -y git
git config --global user.name "Your Name"
git config --global user.email "you@example.com"
```

### SSH authentication (recommended)
```bash
ssh-keygen -t ed25519 -C "you@example.com"
cat ~/.ssh/id_ed25519.pub   # add this to GitHub Settings > SSH keys
ssh -T git@github.com       # test connection
```

### Initialize and push
```bash
cd ~/k8s
git init
git add .
git status   # verify secret.yaml is NOT listed
git commit -m "initial homelab manifests"
git remote add origin git@github.com:yourusername/homelab-infra.git
git push -u origin main
```

---

## 11. Deploying Nextcloud

### File structure
```
clusters/area87/homelab/nextcloud/
├── secret.yaml      # passwords — never commit
├── mariadb.yaml     # database deployment + service + PVC
├── nextcloud.yaml   # nextcloud deployment + service + PVC
└── ingress.yaml     # Traefik ingress → cloud-optiplex.area87.uk
```

### Apply order
```bash
kubectl apply -f secret.yaml
kubectl apply -f mariadb.yaml
kubectl apply -f nextcloud.yaml
kubectl apply -f ingress.yaml
```

### Watch pods come up
```bash
kubectl get pods -n homelab -w
```

### Access
```
https://cloud-optiplex.area87.uk   # public via Cloudflare Tunnel
http://<server-ip>:30080        # local network only
```

### Fix trusted domains (if already installed)

> Note: `NEXTCLOUD_TRUSTED_DOMAINS` env var only applies on first install. After that, use `occ`.

```bash
POD=$(kubectl get pod -n homelab -l app=nextcloud -o jsonpath='{.items[0].metadata.name}')

# Set trusted domain
kubectl exec -n homelab "$POD" -- su -s /bin/sh www-data -c "php occ config:system:set trusted_domains 1 --value=cloud-optiplex.area87.uk"

# Verify
kubectl exec -n homelab "$POD" -- su -s /bin/sh www-data -c "php occ config:system:get trusted_domains"
```

---

## 12. Cloudflare Tunnel + Traefik Ingress

k3s ships with Traefik as the default Ingress controller. Combined with a Cloudflare Tunnel (`cloudflared`), this gives public HTTPS access to apps without opening any router ports.

### How it works
```
Internet → Cloudflare → cloudflared (systemd on host) → Traefik (k3s) → Service → Pod
```

### cloudflared config (`/etc/cloudflared/config.yml`)
```yaml
tunnel: optiplex-tunnel
credentials-file: /etc/cloudflared/<tunnel-id>.json

ingress:
  - hostname: ssh-optiplex.area87.uk
    service: ssh://localhost:22
  - hostname: cloud-optiplex.area87.uk
    service: http://localhost:80
  - hostname: pdf-optiplex.area87.uk
    service: http://localhost:80
  - service: http_status:404  # required catch-all
```

```bash
sudo systemctl restart cloudflared
sudo systemctl status cloudflared
```

### Traefik Ingress manifest template
```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: <app>-ingress
  namespace: homelab
  annotations:
    traefik.ingress.kubernetes.io/router.entrypoints: web
spec:
  rules:
    - host: <app>-optiplex.area87.uk
      http:
        paths:
          - path: /
            pathType: Prefix
            backend:
              service:
                name: <app>
                port:
                  number: 80
```

### Cloudflare DNS (per app)
In Cloudflare dashboard → DNS → Add record:
- Type: `CNAME`
- Name: `<app>-optiplex`
- Target: `<tunnel-id>.cfargotunnel.com`
- Proxy: ✅ Proxied

### Cloudflare Zero Trust Access (per app)
Zero Trust → Access → Applications → Add:
- Type: Self-hosted
- Application URL: `<app>-optiplex.area87.uk`
- Policy: allow your email only

> Create one Access Application per hostname. Using wildcards causes the OIDC callback to land on the wrong subdomain.

---

## 13. Multi-Cluster Kubeconfig

```bash
kubectl config get-contexts      # list clusters
kubectl config use-context <name>  # switch cluster
```

---

## 14. Learning Path

1. ✅ Deploy nginx: `kubectl create deployment nginx --image=nginx`
2. ✅ Expose it: `kubectl expose deployment nginx --port=80 --type=NodePort`
3. ✅ Write YAML manifests
4. ✅ Set up Ingress with Traefik (k3s built-in)
5. ✅ Expose apps publicly via Cloudflare Tunnel
6. Learn Helm (Kubernetes package manager)
7. Set up GitOps with Flux or ArgoCD
8. Add Longhorn for persistent storage (Phase 3 — after SATA SSD)
9. Add TLS with cert-manager

---

## 15. Useful References

- [Kubernetes Docs](https://kubernetes.io/docs/)
- [k3s Docs](https://docs.k3s.io/)
- [Nextcloud Docker Hub](https://hub.docker.com/_/nextcloud)
- [Longhorn](https://longhorn.io/)
- [Cloudflare Tunnel Docs](https://developers.cloudflare.com/cloudflare-one/connections/connect-networks/)
- [Traefik Ingress (k3s)](https://docs.k3s.io/networking/traefik-ingress)
- [Stirling PDF](https://github.com/Stirling-Tools/Stirling-PDF)
