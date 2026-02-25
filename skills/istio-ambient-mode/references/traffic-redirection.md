# Traffic Redirection Architecture

## Table of contents

- [Overview](#overview)
- [Pod enrollment sequence](#pod-enrollment-sequence)
- [Ztunnel ports](#ztunnel-ports)
- [Iptables rules reference](#iptables-rules-reference)

## Overview

Traffic redirection (also called traffic capture) intercepts traffic sent to and from ambient-enabled workloads, routing it through ztunnel node proxies. This is security-critical: if ztunnel can be bypassed, authorization policies can be bypassed.

The core design principle is that ztunnel performs data path capture **inside the Linux network namespace** of the workload pod, via cooperation between `istio-cni` and ztunnel. This works alongside any Kubernetes CNI plugin transparently.

## Pod enrollment sequence

When a pod is started in (or added to) an ambient-enabled namespace:

1. **`istio-cni` detects the pod** — either via the chained CNI plugin (new pod) or by watching the Kubernetes API server (existing pod gets ambient label).

2. **`istio-cni` enters the pod's network namespace** — establishes iptables redirection rules so packets entering/leaving the pod are transparently redirected to ztunnel on ports 15008, 15006, and 15001.

3. **`istio-cni` notifies ztunnel** — over a Unix domain socket (`/var/run/ztunnel/ztunnel.sock`), providing a Linux file descriptor for the pod's network namespace.

4. **ztunnel creates listening sockets** — inside the pod's network namespace (using low-level Linux socket APIs that allow cross-namespace socket creation). A dedicated logical proxy instance is spun up for the pod (within the same ztunnel process).

5. **Pod is in the mesh** — traffic flows through ztunnel with mTLS encryption. Data enters and leaves the pod network namespace encrypted.

## Ztunnel ports

| Port  | Purpose |
|-------|-------------------------------------------|
| 15001 | Outbound egress capture |
| 15006 | Inbound plaintext traffic capture |
| 15008 | Inbound HBONE (mTLS) traffic capture |
| 15080 | Local listener (127.0.0.1 only) |

## Iptables rules reference

When a pod is enrolled, `istio-cni` adds chains to the **mangle** and **nat** tables inside the pod's network namespace.

### Mangle table

```
*mangle
:ISTIO_PRERT - [0:0]
:ISTIO_OUTPUT - [0:0]
-A PREROUTING -j ISTIO_PRERT
-A OUTPUT -j ISTIO_OUTPUT

# Restore connection marks for outbound
-A ISTIO_OUTPUT -m connmark --mark 0x111/0xfff -j CONNMARK --restore-mark

# Mark connections coming from ztunnel
-A ISTIO_PRERT -m mark --mark 0x539/0xfff -j CONNMARK --set-xmark 0x111/0xfff

# Accept traffic from ztunnel's internal IP
-A ISTIO_PRERT -s 169.254.7.127/32 -p tcp -m tcp -j ACCEPT

# Accept loopback non-localhost traffic
-A ISTIO_PRERT ! -d 127.0.0.1/32 -i lo -p tcp -j ACCEPT

# TPROXY HBONE traffic (port 15008) to ztunnel HBONE listener
-A ISTIO_PRERT -p tcp -m tcp --dport 15008 -m mark ! --mark 0x539/0xfff -j TPROXY --on-port 15008 --on-ip 0.0.0.0 --tproxy-mark 0x111/0xfff

# Accept established/related connections
-A ISTIO_PRERT -p tcp -m conntrack --ctstate RELATED,ESTABLISHED -j ACCEPT

# TPROXY remaining inbound plaintext to port 15006
-A ISTIO_PRERT ! -d 127.0.0.1/32 -p tcp -m mark ! --mark 0x539/0xfff -j TPROXY --on-port 15006 --on-ip 0.0.0.0 --tproxy-mark 0x111/0xfff
```

### NAT table

```
*nat
:ISTIO_OUTPUT - [0:0]
-A OUTPUT -j ISTIO_OUTPUT

# Accept traffic to ztunnel's internal IP
-A ISTIO_OUTPUT -d 169.254.7.127/32 -p tcp -m tcp -j ACCEPT

# Accept already-marked traffic (from ztunnel)
-A ISTIO_OUTPUT -p tcp -m mark --mark 0x111/0xfff -j ACCEPT

# Accept loopback non-localhost traffic
-A ISTIO_OUTPUT ! -d 127.0.0.1/32 -o lo -j ACCEPT

# REDIRECT all other outbound TCP to ztunnel egress port 15001
-A ISTIO_OUTPUT ! -d 127.0.0.1/32 -p tcp -m mark ! --mark 0x539/0xfff -j REDIRECT --to-ports 15001
```

### Key marks

| Mark | Meaning |
|------|----------------------------------------------|
| `0x539` | Traffic originating from ztunnel (exempt from redirect) |
| `0x111` | Traffic already processed / marked by ztunnel |
