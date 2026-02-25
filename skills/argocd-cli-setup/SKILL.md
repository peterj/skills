---
name: argocd-cli-setup
description: Guides installation of the Argo CD CLI across Linux, WSL, macOS (Apple Silicon), and Windows. Also covers Argo CD core concepts such as Application, Sync, Target State, Live State, Refresh, and Health. Use when setting up the argocd CLI, troubleshooting argocd installation, or when the user needs to understand Argo CD terminology and GitOps concepts.
---

# Argo CD CLI Installation & Core Concepts

## Quick start — Install the CLI

### Homebrew (Linux, WSL, macOS)

```bash
brew install argocd
```

### Linux / WSL — curl (latest stable)

```bash
VERSION=$(curl -L -s https://raw.githubusercontent.com/argoproj/argo-cd/stable/VERSION)
curl -sSL -o argocd-linux-amd64 https://github.com/argoproj/argo-cd/releases/download/v$VERSION/argocd-linux-amd64
sudo install -m 555 argocd-linux-amd64 /usr/local/bin/argocd
rm argocd-linux-amd64
```

### macOS Apple Silicon — curl

```bash
VERSION=$(curl --silent "https://api.github.com/repos/argoproj/argo-cd/releases/latest" | grep '"tag_name"' | sed -E 's/.*"([^"]+)".*/\1/')
curl -sSL -o argocd https://github.com/argoproj/argo-cd/releases/download/$VERSION/argocd-darwin-arm64
sudo install -m 555 argocd /usr/local/bin/argocd
rm argocd
```

### Windows — PowerShell

```powershell
$version = (Invoke-RestMethod https://api.github.com/repos/argoproj/argo-cd/releases/latest).tag_name
$url = "https://github.com/argoproj/argo-cd/releases/download/" + $version + "/argocd-windows-amd64.exe"
Invoke-WebRequest -Uri $url -OutFile argocd.exe
[Environment]::SetEnvironmentVariable("Path", "$env:Path;C:\Path\To\ArgoCD-CLI", "User")
```

Replace `C:\Path\To\ArgoCD-CLI` with the actual directory containing `argocd.exe`.

### ArchLinux

```bash
pacman -S argocd
```

### Download a specific version (Linux)

Set `VERSION` to the desired Git tag:

```bash
VERSION=<TAG>
curl -sSL -o argocd-linux-amd64 https://github.com/argoproj/argo-cd/releases/download/$VERSION/argocd-linux-amd64
sudo install -m 555 argocd-linux-amd64 /usr/local/bin/argocd
rm argocd-linux-amd64
```

Browse tags at <https://github.com/argoproj/argo-cd/releases>.

## Core concepts

| Term | Meaning |
|---|---|
| **Application** | A group of Kubernetes resources defined by a manifest (a CRD). |
| **Application source type** | The **Tool** used to build the application. |
| **Target state** | The desired state of an application, represented by files in a Git repository. |
| **Live state** | The actual deployed state of the application (pods, services, etc.). |
| **Sync status** | Whether the live state matches the target state. |
| **Sync** | The process of making an application move to its target state (e.g., applying changes to a cluster). |
| **Sync operation status** | Whether a sync succeeded. |
| **Refresh** | Comparing the latest code in Git with the live state to find differences. |
| **Health** | Whether the application is running correctly and can serve requests. |
| **Tool** | A tool to create manifests from a directory of files (e.g., Kustomize). Also called **Configuration management tool**. |
| **Configuration management plugin** | A custom tool for manifest generation. |

## Additional resources

- For detailed per-platform installation steps and notes, see [installation.md](installation.md)
