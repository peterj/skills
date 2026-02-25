# SPIRE Kubernetes Deployment

## Table of contents

- [Prerequisites](#prerequisites)
- [Server deployment](#server-deployment)
  - [Create namespace](#create-namespace)
  - [Create server service account](#create-server-service-account)
  - [Create server bundle configmap and RBAC](#create-server-bundle-configmap-and-rbac)
  - [Create server configmap](#create-server-configmap)
  - [Create server statefulset](#create-server-statefulset)
  - [Create server service](#create-server-service)
- [Agent deployment](#agent-deployment)
  - [Create agent service account](#create-agent-service-account)
  - [Create agent configmap](#create-agent-configmap)
  - [Create agent daemonset](#create-agent-daemonset)
- [Volume reference](#volume-reference)

## Prerequisites

Obtain the required YAML files by cloning `https://github.com/spiffe/spire-tutorials` and using files from `spire-tutorials/k8s/quickstart`.

All `kubectl` commands must be run from the directory containing the YAML files.

## Server deployment

### Create namespace

```bash
kubectl apply -f spire-namespace.yaml
kubectl get namespaces  # verify 'spire' is listed
```

### Create server service account

```bash
kubectl apply -f server-account.yaml
kubectl get serviceaccount --namespace spire  # verify 'spire-server'
```

### Create server bundle configmap and RBAC

The server needs to generate certificates and update a configmap for agents to verify server identity.

```bash
# Create the bundle configmap
kubectl apply -f spire-bundle-configmap.yaml
kubectl get configmaps --namespace spire | grep spire  # verify 'spire-bundle'

# Create ClusterRole and ClusterRoleBinding
kubectl apply -f server-cluster-role.yaml
kubectl get clusterroles --namespace spire | grep spire  # verify 'spire-server-trust-role'
```

### Create server configmap

The server configuration is stored in a ConfigMap. Key directories: `/run/spire/data` and `/run/spire/config`.

```bash
kubectl apply -f server-configmap.yaml
```

### Create server statefulset

```bash
kubectl apply -f server-statefulset.yaml
```

Verify:

```bash
kubectl get statefulset --namespace spire
# NAME           READY   AGE
# spire-server   1/1     86m

kubectl get pods --namespace spire
# NAME             READY   STATUS    RESTARTS   AGE
# spire-server-0   1/1     Running   0          86m
```

A livenessProbe is automatically configured on the SPIRE server's GRPC port.

**Server volumes:**

| Volume | Description | Mount Location |
|---|---|---|
| spire-config | Reference to server configmap | /run/spire/config |
| spire-data | hostPath for SQLite database and keys | /run/spire/data |

### Create server service

```bash
kubectl apply -f server-service.yaml
kubectl get services --namespace spire
# NAME           TYPE       CLUSTER-IP      EXTERNAL-IP   PORT(S)          AGE
# spire-server   NodePort   10.107.205.29   <none>        8081:30337/TCP   88m
```

## Agent deployment

Agents are deployed as a DaemonSet — one per Kubernetes worker node.

### Create agent service account

```bash
kubectl apply -f agent-account.yaml

# Create ClusterRole for kubelet API access (workload attestation)
kubectl apply -f agent-cluster-role.yaml
kubectl get clusterroles --namespace spire | grep spire  # verify
```

### Create agent configmap

```bash
kubectl apply -f agent-configmap.yaml
```

Key directories: `/run/spire/sockets` and `/run/spire/config`.

### Create agent daemonset

```bash
kubectl apply -f agent-daemonset.yaml
```

Verify:

```bash
kubectl get daemonset --namespace spire
# NAME          DESIRED   CURRENT   READY   UP-TO-DATE   AVAILABLE   AGE
# spire-agent   1         1         1       1            1           6m45s

kubectl get pods --namespace spire
# NAME                           READY   STATUS    RESTARTS   AGE
# spire-agent-88cpl              1/1     Running   0          6m45s
# spire-server-0                 1/1     Running   0          103m
```

**Agent volumes:**

| Volume | Description | Mount Location |
|---|---|---|
| spire-config | Agent configmap | /run/spire/config |
| spire-sockets | hostPath shared with workload pods; contains UNIX domain socket for Workload API | /run/spire/sockets |

## Volume reference

All SPIRE components in Kubernetes use mounted volumes for configuration and runtime data. The UNIX domain socket at `/run/spire/sockets` is how workloads communicate with the SPIRE Agent's Workload API.
