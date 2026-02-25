# Multicluster Traffic Management

## Table of contents

- [Cluster-local traffic with MeshConfig](#cluster-local-traffic-with-meshconfig)
- [Partitioning services by cluster](#partitioning-services-by-cluster)
- [Cluster-local routing via VirtualService](#cluster-local-routing-via-virtualservice)
- [Trade-offs](#trade-offs)

## Cluster-local traffic with MeshConfig

Use `MeshConfig.serviceSettings` to mark hostnames or wildcards as `clusterLocal`.

### Per service

```yaml
serviceSettings:
- settings:
    clusterLocal: true
  hosts:
  - "mysvc.myns.svc.cluster.local"
```

### Per namespace

```yaml
serviceSettings:
- settings:
    clusterLocal: true
  hosts:
  - "*.myns.svc.cluster.local"
```

### Global

```yaml
serviceSettings:
- settings:
    clusterLocal: true
  hosts:
  - "*"
```

### Global with exceptions

Set global cluster-local and add explicit overrides:

```yaml
serviceSettings:
- settings:
    clusterLocal: true
  hosts:
  - "*"
- settings:
    clusterLocal: false
  hosts:
  - "*.myns.svc.cluster.local"
```

## Partitioning services by cluster

Use `DestinationRule.subsets` with the built-in label `topology.istio.io/cluster` to create per-cluster subsets:

```yaml
apiVersion: networking.istio.io/v1
kind: DestinationRule
metadata:
  name: mysvc-per-cluster-dr
spec:
  host: mysvc.myns.svc.cluster.local
  subsets:
  - name: cluster-1
    labels:
      topology.istio.io/cluster: cluster-1
  - name: cluster-2
    labels:
      topology.istio.io/cluster: cluster-2
```

These subsets can be used for mirroring, traffic shifting, and other routing rules.

## Cluster-local routing via VirtualService

Combine per-cluster subsets with a `VirtualService` to route traffic to the local cluster:

```yaml
apiVersion: networking.istio.io/v1
kind: VirtualService
metadata:
  name: mysvc-cluster-local-vs
spec:
  hosts:
  - mysvc.myns.svc.cluster.local
  http:
  - name: "cluster-1-local"
    match:
    - sourceLabels:
        topology.istio.io/cluster: "cluster-1"
    route:
    - destination:
        host: mysvc.myns.svc.cluster.local
        subset: cluster-1
  - name: "cluster-2-local"
    match:
    - sourceLabels:
        topology.istio.io/cluster: "cluster-2"
    route:
    - destination:
        host: mysvc.myns.svc.cluster.local
        subset: cluster-2
```

## Trade-offs

**MeshConfig approach** (`serviceSettings`):
- Simple, declarative
- Clean separation of topology policy from service policy

**Subset-based routing approach** (`DestinationRule` + `VirtualService`):
- More granular control
- Downside: mixes service-level policy with topology-level policy
- A rule sending 10% of traffic to `v2` would need twice the subsets (e.g., `cluster-1-v2`, `cluster-2-v2`)
- Best limited to situations requiring fine-grained cluster-based routing
