---
name: kubernetes-cluster-architecture
description: Provides reference knowledge about Kubernetes cluster architecture, including control plane components (kube-apiserver, etcd, kube-scheduler, kube-controller-manager, cloud-controller-manager), node components (kubelet, kube-proxy, container runtime), addons (DNS, Dashboard, monitoring, logging, network plugins), and architecture variations. Use when discussing Kubernetes cluster design, component responsibilities, control plane vs worker node distinctions, or deployment topology decisions.
---

# Kubernetes Cluster Architecture

A Kubernetes cluster consists of a **control plane** plus a set of **worker nodes** that run containerized applications. Every cluster needs at least one worker node to run Pods.

- The **control plane** manages worker nodes and Pods in the cluster.
- **Worker nodes** host Pods that make up the application workload.
- In production, the control plane typically runs across multiple machines for fault-tolerance and high availability.

## Control plane components

These make global decisions about the cluster (scheduling, responding to events).

| Component | Role |
|---|---|
| **kube-apiserver** | Front end for the Kubernetes control plane. Exposes the Kubernetes API. Designed to scale horizontally. |
| **etcd** | Consistent, highly-available key-value store used as the backing store for all cluster data. |
| **kube-scheduler** | Watches for newly created Pods with no assigned node, and selects a node for them to run on. |
| **kube-controller-manager** | Runs controller processes (Node controller, Job controller, EndpointSlice controller, ServiceAccount controller, and others). |
| **cloud-controller-manager** | Runs controllers with cloud provider dependencies (Node, Route, Service controllers). Only present when running on a cloud provider. |

## Node components

Run on every node, maintaining running Pods and providing the runtime environment.

| Component | Role |
|---|---|
| **kubelet** | Agent on each node ensuring containers are running in a Pod. |
| **kube-proxy** | Network proxy on each node implementing Service networking. Optional if using a network plugin that provides its own proxy implementation. |
| **Container runtime** | Software responsible for running containers. |

## Addons

| Addon | Purpose |
|---|---|
| **Cluster DNS** | DNS server for Kubernetes services. All clusters should have it; containers automatically include it in DNS searches. |
| **Dashboard** | General-purpose web UI for managing and troubleshooting clusters and applications. |
| **Container Resource Monitoring** | Records time-series metrics about containers in a central database. |
| **Cluster-level Logging** | Saves container logs to a central log store with search/browsing. |
| **Network plugins** | Implement CNI specification — allocate IP addresses to Pods and enable intra-cluster communication. |

Addon resources belong in the `kube-system` namespace.

## Architecture variations

For details on deployment options, workload placement, management tools, and customization, see [architecture-variations.md](architecture-variations.md).
