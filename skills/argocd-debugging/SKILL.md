---
name: argocd-debugging
description: Provides guidance for debugging Argo CD components both locally and in remote environments. Use when setting up IDE debug configurations for Argo CD (VSCode, GoLand), running individual Argo CD components for debugging, or using Telepresence to debug remote Argo CD deployments.
---

# Argo CD Debugging

Two approaches for debugging Argo CD: **local debugging** (run one component in your IDE while others run via local toolchain) and **remote debugging** (intercept a remote cluster service with Telepresence).

## Local Debugging

### Overview

Run all Argo CD components except the one you want to debug using the local toolchain, then run that single component from your IDE with breakpoints.

### Step 1: Extract config from Procfile

The `Procfile` in the repo root contains run configuration for every component. For the component you want to debug, extract:
- **Environment variables**: everything before `$COMMAND` in the `sh -c` section
- **CLI arguments**: everything after `$COMMAND`

### Step 2: Create an env file

Create an env file (e.g., `api-server.env`) with the variables from the Procfile:

```bash
ARGOCD_BINARY_NAME=argocd-server
ARGOCD_FAKE_IN_CLUSTER=true
ARGOCD_GNUPGHOME=/tmp/argocd-local/gpg/keys
ARGOCD_GPG_DATA_PATH=/tmp/argocd-local/gpg/source
ARGOCD_GPG_ENABLED=false
ARGOCD_LOG_FORMAT_ENABLE_FULL_TIMESTAMP=1
ARGOCD_SSH_DATA_PATH=/tmp/argocd-local/ssh
ARGOCD_TLS_DATA_PATH=/tmp/argocd-local/tls
ARGOCD_TRACING_ENABLED=1
FORCE_LOG_COLORS=1
KUBECONFIG=/Users/<YOUR_USERNAME>/.kube/config  # Must be absolute path
```

Install the **DotENV** (VSCode) or **EnvFile** (GoLand) plugin to load it.

### Step 3: Configure IDE launch

See [ide-configurations.md](ide-configurations.md) for complete VSCode and GoLand launch configuration examples.

**Key args for api-server** (adapt from Procfile for other components):
```
--loglevel debug --redis localhost:6379 --repo-server localhost:8081 --dex-server http://localhost:5556 --port 8080 --insecure
```

### Step 4: Run remaining components

Three options to run everything except the debugged component (using api-server as example):

| Method | Command |
|---|---|
| `make start-local` (whitelist) | `make start-local ARGOCD_START="notification applicationset-controller repo-server redis dex controller ui"` |
| `make run` (blacklist) | `make run exclude=api-server` |
| `goreman start` (whitelist) | `goreman start notification applicationset-controller repo-server redis dex controller ui` |

> **Auth note**: By default api-server runs with auth disabled. To test auth: `export ARGOCD_E2E_DISABLE_AUTH='false' && make start-local`

### Step 5: Launch from IDE

Start the component in your IDE. Ensure each component runs exactly once (either via toolchain or IDE) to avoid port conflicts.

## Remote Debugging with Telepresence

### Step 1: Install ArgoCD on cluster

```shell
kubectl create ns argocd
curl -sSfL https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml | kubectl apply -n argocd -f -
```

### Step 2: Connect and intercept

```shell
kubectl config set-context --current --namespace argocd
telepresence helm install --set-json agent.securityContext={}
telepresence connect
telepresence intercept argocd-server --port 8080:http --env-file .envrc.remote
```

- `--port 8080:http` — forwards remote HTTP traffic to local port 8080 (use `8080:https` if TLS termination is on argocd-server)
- `--env-file .envrc.remote` — captures remote pod env vars into a local file

Traffic hitting argocd-server in the cluster is now forwarded to localhost:8080.

### Step 3: Run locally

**Terminal:**
```shell
make server
./dist/argocd-server
```

**VSCode:** Use a launch config pointing to `${workspaceFolder}/cmd/main.go` with `envFile` set to `.envrc.remote` and `ARGOCD_BINARY_NAME=argocd-server`. See [ide-configurations.md](ide-configurations.md).

### Step 4: Cleanup

```shell
telepresence leave argocd-server
telepresence helm uninstall
```

### Telepresence v1

```shell
telepresence --swap-deployment argocd-server --namespace argocd --env-file .envrc.remote --expose 8080:8080 --expose 8083:8083 --run bash
```

### Status check

```shell
telepresence status
```

## Important

- Always check the **latest Procfile** — component configuration changes over time.
- Each component must run exactly once. Duplicates cause port conflicts or debugging the wrong process.
- The `.envrc.remote` file from Telepresence lets the local process connect to remote configmaps, secrets, and microservices transparently.
