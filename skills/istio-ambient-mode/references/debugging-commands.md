# Ambient Mode Debugging Commands Reference

## Table of contents

- [Ztunnel log inspection](#ztunnel-log-inspection)
- [Socket verification](#socket-verification)
- [Iptables rules inspection](#iptables-rules-inspection)
- [Iptables rules explained](#iptables-rules-explained)

## Ztunnel log inspection

Check ztunnel logs for in-pod redirection status:

```bash
kubectl logs ds/ztunnel -n istio-system | grep inpod
```

Example output showing healthy operation:

```
inpod_enabled: true
inpod_uds: /var/run/ztunnel/ztunnel.sock
inpod_port_reuse: true
inpod_mark: 1337
2024-02-21T22:01:49.916037Z  INFO ztunnel::inpod::workloadmanager: handling new stream
2024-02-21T22:01:49.919944Z  INFO ztunnel::inpod::statemanager: pod WorkloadUid("1e054806-e667-4109-a5af-08b3e6ba0c42") received netns, starting proxy
2024-02-21T22:01:49.925997Z  INFO ztunnel::inpod::statemanager: pod received snapshot sent
```

Key log fields:
- `inpod_enabled: true` — in-pod redirection is active
- `inpod_uds` — Unix domain socket path for istio-cni ↔ ztunnel communication
- `inpod_mark: 1337` — the fwmark used for traffic marking
- `received netns, starting proxy` — ztunnel successfully received the pod network namespace
- `pod delete request, draining proxy` — pod is being removed from mesh

## Socket verification

Confirm ztunnel listening sockets exist inside a pod:

```bash
kubectl debug $(kubectl get pod -l app=curl -n ambient-demo -o jsonpath='{.items[0].metadata.name}') \
  -it -n ambient-demo --image nicolaka/netshoot -- ss -ntlp
```

Expected output:

```
State  Recv-Q Send-Q Local Address:Port  Peer Address:Port Process
LISTEN 0      128        127.0.0.1:15080      0.0.0.0:*
LISTEN 0      128                *:15006            *:*
LISTEN 0      128                *:15001            *:*
LISTEN 0      128                *:15008            *:*
```

If any of ports 15001, 15006, or 15008 are missing, ztunnel has not successfully set up its listening sockets in the pod's network namespace.

## Iptables rules inspection

View the full iptables configuration inside a pod:

```bash
kubectl debug $(kubectl get pod -l app=curl -n ambient-demo -o jsonpath='{.items[0].metadata.name}') \
  -it --image gcr.io/istio-release/base --profile=netadmin -n ambient-demo -- iptables-save
```

## Iptables rules explained

The `istio-cni` agent installs rules in two netfilter tables:

### Mangle table (ISTIO_PRERT chain)

Handles inbound traffic using TPROXY:

| Rule | Purpose |
|------|---------|
| `-m mark --mark 0x539/0xfff -j CONNMARK --set-xmark 0x111/0xfff` | Mark connections from ztunnel (mark 0x539 = 1337) |
| `-s 169.254.7.127/32 -p tcp -j ACCEPT` | Accept traffic from ztunnel's internal address |
| `-p tcp --dport 15008 -m mark ! --mark 0x539/0xfff -j TPROXY --on-port 15008` | Redirect inbound HBONE traffic to ztunnel port 15008 |
| `! -d 127.0.0.1/32 -p tcp -m mark ! --mark 0x539/0xfff -j TPROXY --on-port 15006` | Redirect other inbound TCP to ztunnel plaintext port 15006 |

### NAT table (ISTIO_OUTPUT chain)

Handles outbound traffic using REDIRECT:

| Rule | Purpose |
|------|---------|
| `-d 169.254.7.127/32 -p tcp -j ACCEPT` | Accept traffic to ztunnel's internal address |
| `-p tcp -m mark --mark 0x111/0xfff -j ACCEPT` | Allow traffic already processed by ztunnel |
| `! -d 127.0.0.1/32 -p tcp -m mark ! --mark 0x539/0xfff -j REDIRECT --to-ports 15001` | Redirect outbound TCP to ztunnel egress port 15001 |
