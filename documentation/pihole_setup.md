# Pi-hole Setup Documentation

## Overview

Pi-hole is deployed as a Kubernetes workload on the `area87` cluster (optiplex7060) in the `homelab` namespace. It acts as a network-wide DNS sinkhole, blocking ads and trackers for all devices on the LAN.

- **Pi-hole DNS IP:** `192.168.100.251` (assigned via MetalLB)
- **Pi-hole Admin UI:** http://pihole-optiplex.area87.uk or http://192.168.100.251/admin
- **Node:** optiplex7060 (`192.168.100.60`)

---

## Components

### 1. Pi-hole Deployment (`clusters/area87/homelab/pihole/pihole.yaml`)

- Runs the `pihole/pihole:latest` container in the `homelab` namespace
- Persistent storage via `hostPath` volumes at `/data/pihole/` on the node
- Admin password stored in a Kubernetes secret (`pihole-secret`)
- Two Kubernetes Services expose Pi-hole externally:
  - `pihole` (LoadBalancer) — port 80 (web UI) + port 53 TCP (DNS)
  - `pihole-dns-udp` (LoadBalancer) — port 53 UDP (DNS)
  - Both share external IP `192.168.100.251` via MetalLB's `allow-shared-ip` annotation

> **Note:** Two separate services are required because k3s does not support mixed TCP/UDP protocols on the same LoadBalancer service port.

### 2. MetalLB (`clusters/area87/metallb/metallb-config.yaml`)

MetalLB provides LoadBalancer IP assignment for bare-metal Kubernetes clusters.

- **IP pool:** `192.168.100.250–192.168.100.254`
- **Mode:** Layer 2 (ARP-based), advertising on interface `eno1`
- Install command:
  ```bash
  kubectl apply -f https://raw.githubusercontent.com/metallb/metallb/v0.14.9/config/manifests/metallb-native.yaml
  kubectl apply -f clusters/area87/metallb/metallb-config.yaml
  ```

### 3. k3s Configuration (`/etc/systemd/system/k3s.service` on optiplex7060)

k3s's built-in ServiceLB (klipper-lb) was disabled to prevent conflicts with MetalLB:

```ini
ExecStart=/usr/local/bin/k3s \
    server \
    --disable=servicelb \
```

Apply changes:
```bash
sudo systemctl daemon-reload
sudo systemctl restart k3s
```

---

## Router Configuration

### Setting the DNS Server

To route all LAN devices through Pi-hole, set the DNS server in your router's DHCP settings:

1. Log into your router admin page — typically `http://192.168.100.1`
2. Navigate to **LAN** → **DHCP Settings** (exact path varies by router model)
3. Set **Primary DNS** to `192.168.100.251`
4. Set **Secondary DNS** to a fallback (e.g. `1.1.1.1` or `8.8.8.8`) in case Pi-hole is unavailable
5. Save and apply

Devices will use the new DNS after their DHCP lease renews. To force immediate update on a device, disconnect and reconnect from Wi-Fi or run `ipconfig /release && ipconfig /renew` on Windows.

### DHCP IP Range Change

The DHCP range end address was changed to free up IPs for MetalLB:

| Setting | Before | After |
|--------|--------|-------|
| DHCP End IP | `192.168.100.254` | `192.168.100.249` |

MetalLB uses `192.168.100.250–192.168.100.254` (outside DHCP range).

---

## Testing Pi-hole is Blocking

Run from any device on the LAN (with VPN disabled):

```powershell
# Windows PowerShell
nslookup doubleclick.net 192.168.100.251
```

Expected output (blocked):
```
Name:    doubleclick.net
Addresses:  ::
          0.0.0.0
```

`0.0.0.0` confirms the domain is being blocked.

Check live query logs at: http://pihole-optiplex.area87.uk/admin

---

## Restoring Router to Default State

> Use this if you need to undo the Pi-hole DNS configuration and return to normal router behaviour.

### Option 1: Revert DNS settings manually

1. Log into router admin at `http://192.168.100.1`
2. Navigate to **LAN** → **DHCP Settings**
3. Clear the **Primary DNS** field (or set it back to your ISP's DNS or `1.1.1.1`)
4. Set **Secondary DNS** back to empty or `8.8.8.8`
5. Restore **DHCP End IP** to `192.168.100.254` if desired
6. Save and apply

### Option 2: Full factory reset

> **Warning:** This will erase all router settings including Wi-Fi passwords, port forwards, and any custom configuration.

1. Locate the **Reset** button on the back/bottom of the router (usually a small pinhole)
2. With the router powered on, hold the reset button for **10–15 seconds** using a pin or paperclip
3. Release when the lights flash/change — the router will reboot to factory defaults
4. Reconnect using the default Wi-Fi credentials printed on the router label
5. Reconfigure your router settings from scratch

---

## Troubleshooting

| Issue | Check |
|-------|-------|
| DNS queries timing out | Ensure VPN is disabled — VPNs intercept port 53 traffic |
| `EXTERNAL-IP` stuck as `<pending>` | Check MetalLB pods: `kubectl get pods -n metallb-system` |
| Pi-hole pod not starting | Check PV/PVC: `kubectl get pv,pvc -n homelab` |
| Queries not blocked | Verify device is using `192.168.100.251` as DNS; check Pi-hole blocklists in admin UI |
| Pi-hole unreachable after reboot | Check pod status: `kubectl get pods -n homelab` |
