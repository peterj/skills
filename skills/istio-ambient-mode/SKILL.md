---
name: istio-ambient-mode
description: Guide for installing, deploying, debugging, and cleaning up Istio's ambient mode mesh. Use when working with Istio ambient mode, ztunnel proxies, ambient mesh traffic redirection, istio-cni, HBONE encryption, Bookinfo sample application deployment, or istioctl commands for ambient profile setup and teardown.
---

# Istio Ambient Mode

Istio's ambient mode provides transparent mTLS encryption and routing for application traffic using ztunnel node proxies — without sidecars. Traffic is intercepted inside pod network namespaces via cooperation between `istio-cni` and `ztunnel`.

## Quick start

### 1. Install Istio with ambient profile

```bash
curl -L https://istio.io/downloadIstio | sh -
cd istio-*
export PATH=$PWD/bin:$PATH

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

### 2. Install Kubernetes Gateway API CRDs

Install the Gateway API CRDs before configuring traffic routing (required for ingress gateway).

### 3. Deploy sample application

```bash
kubectl apply -f samples/bookinfo/platform/kube/bookinfo.yaml
kubectl apply -f samples/bookinfo/platform/kube/bookinfo-versions.yaml
kubectl get pods  # Verify all pods are Running
```

### 4. Deploy ingress gateway

```bash
kubectl apply -f samples/bookinfo/gateway-api/bookinfo-gateway.yaml
kubectl annotate gateway bookinfo-gateway networking.istio.io/service-type=ClusterIP --namespace=default
kubectl get gateway  # Wait for PROGRAMMED=True
```

### 5. Access the application

```bash
kubectl port-forward svc/bookinfo-gateway-istio 8080:80
# Open http://localhost:8080/productpage
```

## Key concepts

### Traffic redirection model

- **`istio-cni` node agent**: Responds to CNI events (pod creation/deletion) and watches the Kubernetes API for ambient label changes. Installs a chained CNI plugin and sets up iptables redirection rules inside pod network namespaces.
- **ztunnel proxy**: Node-local proxy that creates listening sockets inside each enrolled pod's network namespace on ports **15008** (HBONE/mTLS), **15006** (plaintext ingress), and **15001** (egress).
- **Communication**: `istio-cni` informs ztunnel over a Unix domain socket, passing a file descriptor for the pod's network namespace.
- **mTLS by default**: All traffic to/from mesh pods is encrypted. Applications have no awareness of the encryption.

### Traffic flow

| Direction | Port | Purpose |
|-----------|------|---------|
| Inbound plaintext (dst != 15008) | 15006 | Redirected to ztunnel plaintext listener |
| Inbound HBONE (dst == 15008) | 15008 | Redirected to ztunnel HBONE listener |
| Outbound TCP | 15001 | Redirected to ztunnel for egress, sent via HBONE encapsulation |

## Debugging traffic redirection

Run `bash scripts/debug-ambient.sh` to perform all three checks below, or run them manually:

### Check ztunnel logs

```bash
kubectl logs ds/ztunnel -n istio-system | grep inpod
```

Look for:
- `inpod_enabled: true`
- `pod ... received netns, starting proxy`

### Confirm listening sockets in a pod

```bash
kubectl debug $(kubectl get pod -l app=<APP_LABEL> -n <NAMESPACE> -o jsonpath='{.items[0].metadata.name}') \
  -it -n <NAMESPACE> --image nicolaka/netshoot -- ss -ntlp
```

Expect ports 15001, 15006, and 15008 in LISTEN state.

### Check iptables rules in a pod

```bash
kubectl debug $(kubectl get pod -l app=<APP_LABEL> -n <NAMESPACE> -o jsonpath='{.items[0].metadata.name}') \
  -it --image gcr.io/istio-release/base --profile=netadmin -n <NAMESPACE> -- iptables-save
```

Expect `ISTIO_PRERT` and `ISTIO_OUTPUT` chains in mangle and nat tables with TPROXY/REDIRECT rules.

## Clean up

Order matters: remove workloads from ambient data plane **before** uninstalling Istio.

```bash
# 1. Remove waypoint proxies
kubectl label namespace default istio.io/use-waypoint-
istioctl waypoint delete --all

# 2. Remove namespace from ambient data plane
kubectl label namespace default istio.io/dataplane-mode-

# 3. Remove sample application
kubectl delete httproute reviews
kubectl delete authorizationpolicy productpage-viewer
kubectl delete -f samples/curl/curl.yaml
kubectl delete -f samples/bookinfo/platform/kube/bookinfo.yaml
kubectl delete -f samples/bookinfo/platform/kube/bookinfo-versions.yaml
kubectl delete -f samples/bookinfo/gateway-api/bookinfo-gateway.yaml

# 4. Uninstall Istio
istioctl uninstall -y --purge
kubectl delete namespace istio-system

# 5. Remove Gateway API CRDs (if installed)
```

## Additional resources

- For detailed traffic redirection architecture and iptables rules, see [references/traffic-redirection.md](references/traffic-redirection.md)

## Utility scripts

- Run `bash scripts/debug-ambient.sh <APP_LABEL> <NAMESPACE>` to check ztunnel logs, listening sockets, and iptables rules for a pod
