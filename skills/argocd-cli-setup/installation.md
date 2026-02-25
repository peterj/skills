# Argo CD CLI Installation Reference

All releases are available at <https://github.com/argoproj/argo-cd/releases/latest>.

## Table of contents

- [Linux and WSL](#linux-and-wsl)
- [macOS Apple Silicon](#macos-apple-silicon)
- [Windows](#windows)

---

## Linux and WSL

### ArchLinux

```bash
pacman -S argocd
```

### Homebrew

```bash
brew install argocd
```

### Curl — latest version

```bash
curl -sSL -o argocd-linux-amd64 https://github.com/argoproj/argo-cd/releases/latest/download/argocd-linux-amd64
sudo install -m 555 argocd-linux-amd64 /usr/local/bin/argocd
rm argocd-linux-amd64
```

### Curl — specific version

Replace `<TAG>` with the desired release tag from <https://github.com/argoproj/argo-cd/releases>.

```bash
VERSION=<TAG>
curl -sSL -o argocd-linux-amd64 https://github.com/argoproj/argo-cd/releases/download/$VERSION/argocd-linux-amd64
sudo install -m 555 argocd-linux-amd64 /usr/local/bin/argocd
rm argocd-linux-amd64
```

### Curl — latest stable version

```bash
VERSION=$(curl -L -s https://raw.githubusercontent.com/argoproj/argo-cd/stable/VERSION)
curl -sSL -o argocd-linux-amd64 https://github.com/argoproj/argo-cd/releases/download/v$VERSION/argocd-linux-amd64
sudo install -m 555 argocd-linux-amd64 /usr/local/bin/argocd
rm argocd-linux-amd64
```

---

## macOS Apple Silicon

### Homebrew

```bash
brew install argocd
```

### Curl

Fetch the latest version tag:

```bash
VERSION=$(curl --silent "https://api.github.com/repos/argoproj/argo-cd/releases/latest" | grep '"tag_name"' | sed -E 's/.*"([^"]+)".*/\1/')
```

Download and install:

```bash
curl -sSL -o argocd https://github.com/argoproj/argo-cd/releases/download/$VERSION/argocd-darwin-arm64
sudo install -m 555 argocd /usr/local/bin/argocd
rm argocd
```

---

## Windows

### PowerShell

Fetch the latest version tag:

```powershell
$version = (Invoke-RestMethod https://api.github.com/repos/argoproj/argo-cd/releases/latest).tag_name
```

Download the binary:

```powershell
$url = "https://github.com/argoproj/argo-cd/releases/download/" + $version + "/argocd-windows-amd64.exe"
$output = "argocd.exe"
Invoke-WebRequest -Uri $url -OutFile $output
```

Add to PATH (adjust the directory to where you placed `argocd.exe`):

```powershell
[Environment]::SetEnvironmentVariable("Path", "$env:Path;C:\Path\To\ArgoCD-CLI", "User")
```

---

After installation on any platform, verify with:

```bash
argocd version --client
```
