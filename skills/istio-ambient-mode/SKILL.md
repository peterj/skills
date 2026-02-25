---
name: istio-ambient-mode
description: Guide for installing Istio in ambient mode and understanding ztunnel traffic redirection. Use when working with Istio ambient mesh, ztunnel proxies, in-pod traffic capture, ambient mode installation, or debugging ambient mesh traffic redirection.
---

# Istio Ambient Mode

## Quick start: Install Istio in ambient mode

1. Download the Istio CLI:

```bash
curl -L https://istio.io/downloadIstio | sh -
cd istio-*
export PATH=$PWD/bin:$PATH
```

2. Verify the CLI:

```bash
istioctl version
```

3. Install Istio with the `ambient` profile:

```bash
istioctl install --set profile=ambient --skip-confirmation
```

Expected output:

```
✔ Istio core installed
✔ Istiod installed
✔ CNI installed
✔ Ztunnel installed
✔ Installation complete
```

4. Install Kubernetes Gateway API CRDs (required for traffic routing):

```bash
kubectl get crd gateways.gateway.networking.k8s.io &> /dev/null || \
  kubectl apply -f https://github.com/kubernetes-sigs/gateway-api/releases/latest/download/standard-install.yaml
```

## Key concepts

### Traffic redirection

In ambient mode, **traffic redirection** intercepts traffic to/from ambient-enabled workloads and routes it through **ztunnel** node proxies. This is security-critical — if ztunnel can be bypassed, authorization policies can be bypassed.

### In-pod redirection model

The ztunnel proxy captures traffic inside the Linux network namespace of each workload pod. This is achieved through cooperation between `istio-cni` node agent and the ztunnel node proxy. This model works with any Kubernetes CNI plugin transparently.

### How a pod joins the mesh

When a pod is created in (or added to) an ambient-enabled namespace:

1. **`istio-cni` node agent** detects the event (via CNI plugin for new pods, or Kubernetes API for existing pods)
2. **`istio-cni` enters the pod's network namespace** and sets up iptables redirection rules to intercept traffic and redirect it to ztunnel on well-known ports (15008, 15006, 15001)
3. **`istio-cni` notifies ztunnel** over a Unix domain socket, providing a file descriptor for the pod's network namespace
4. **Ztunnel creates listening sockets** inside the pod's network namespace (ports 15008, 15006, 15001) using Linux's low-level socket API
5. **Traffic flows through ztunnel** — all traffic is encrypted with mTLS by default

### Ztunnel ports

| Port  | Purpose |
|-------|---------|
| 15001 | Egress — outbound TCP traffic redirected here for HBONE encapsulation |
| 15006 | Ingress plaintext — inbound non-HBONE traffic |
| 15008 | Ingress HBONE — inbound HBONE-encrypted traffic |

## Debugging traffic redirection

For detailed troubleshooting, start with the ztunnel debugging guide at `/docs/ambient/usage/troubleshoot-ztunnel/`.

### Check ztunnel logs

Confirm in-pod redirection is enabled and the proxy received the pod's network namespace:

```bash
kubectl logs ds/ztunnel -n istio-system | grep inpod
```

Key log entries to look for:
- `inpod_enabled: true` — redirection mode is enabled
- `pod ... received netns, starting proxy` — ztunnel received namespace info and started proxying
- `pod delete request, draining proxy` — pod removed from mesh

### Confirm listening sockets

Verify ports 15001, 15006, and 15008 are open inside the pod:

```bash
kubectl debug $(kubectl get pod -l app=<APP_LABEL> -n <NAMESPACE> -o jsonpath='{.items[0].metadata.name}') \
  -it -n <NAMESPACE> --image nicolaka/netshoot -- ss -ntlp
```

Expected output should show LISTEN state on ports 15006, 15001, and 15008.

### Check iptables rules

Inspect the redirection rules inside a pod's network namespace:

```bash
kubectl debug $(kubectl get pod -l app=<APP_LABEL> -n <NAMESPACE> -o jsonpath='{.items[0].metadata.name}') \
  -it --image gcr.io/istio-release/base --profile=netadmin -n <NAMESPACE> -- iptables-save
```

Look for `ISTIO_PRERT` and `ISTIO_OUTPUT` chains in the mangle and nat tables. The rules should show:
- Inbound plaintext (port != 15008) → TPROXY to port 15006
- Inbound HBONE (port == 15008) → TPROXY to port 15008
- Outbound TCP → REDIRECT to port 15001

## Additional resources

- For debug commands reference, see [references/debugging-commands.md](references/debugging-commands.md)
