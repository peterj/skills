---
name: spire
description: Guide for installing, configuring, and deploying SPIRE servers and agents. Use when working with SPIRE, SPIFFE, workload identity, trust domains, node attestation, workload attestation, service identity, or X.509/JWT SVIDs on Kubernetes or Linux.
---

# SPIRE Deployment and Configuration

## Quick start — Linux installation

1. Download and extract SPIRE:

```bash
wget https://github.com/spiffe/spire/releases/download/<TAG>/<TARBALL>
tar zvxf <TARBALL>
sudo cp -r spire-<VERSION>/. /opt/spire/
```

2. Add binaries to PATH:

```bash
sudo ln -s /opt/spire/bin/spire-server /usr/bin/spire-server
sudo ln -s /opt/spire/bin/spire-agent /usr/bin/spire-agent
```

3. Configure the server at `/opt/spire/conf/server/server.conf` and agent at `/opt/spire/conf/agent/agent.conf`. Use `--config` flag to specify an alternate path.

4. Configuration files are loaded once at startup — restart after any changes.

## Key concepts

### Configuration files

- **Server**: `conf/server/server.conf` (default)
- **Agent**: `conf/agent/agent.conf` (default)
- Format: HCL or JSON (HCL preferred)
- Override location: `--config <path>`
- In Kubernetes: store config in a ConfigMap mounted into the container

### Trust domain

The trust domain is the trust root of a SPIFFE identity provider. Configured in both server and agent via `trust_domain` in their respective config stanzas. Must match between server and agent.

```hcl
trust_domain = "prod.acme.com"
```

- Takes DNS name form (e.g., `prod.acme.com`), does not need actual DNS infrastructure
- Each server is associated with a single trust domain
- Agent trust domain must match the server it connects to

### Server bind port

Default: `8081`. Change via `bind_port` in `server.conf`:

```hcl
bind_port = "9090"
```

If changed on the server, agents must also be updated.

### Data directory

Set via `data_dir` in both configs. Use absolute paths for production:

```hcl
data_dir = "/opt/spire/data"
```

Ensure the running user has read permissions. Use `data_dir` as the base for other data paths (e.g., KeyManager disk directory, SQLite connection string).

## Node attestation

Configured on both server and agent. At least one node attestor required on the server; exactly one on each agent.

| Method | Environment | Server Plugin | Agent Plugin |
|---|---|---|---|
| **PSAT** (Projected Service Account Token) | Kubernetes | `k8s_psat` | `k8s_psat` |
| **Join Token** | Any Linux | `join_token` | `join_token` |
| **X.509 Certificate** (x509pop) | Linux / Datacenter | `x509pop` | `x509pop` |
| **SSH Certificate** (sshpop) | Linux with SSH certs | `sshpop` | `sshpop` |
| **GCP IIT** | Google Compute Engine | `gcp_iit` | `gcp_iit` |
| **AWS IID** | Amazon EC2 | `aws_iid` | `aws_iid` |
| **Azure MSI** | Azure VMs | `azure_msi` | `azure_msi` |

**Join Token example** (server config):

```hcl
NodeAttestor "join_token" {
    plugin_data {
    }
}
```

Generate token: `spire-server token generate [-spiffeID <id>]`
Start agent with token: `spire-agent run -joinToken <token>`

> SAT-based node attestation is no longer supported as of SPIRE 1.12.0. Use PSAT instead.

> For Azure MSI: the default resource is scoped to `https://management.azure.com`. Consider using a custom resource ID for narrower scope. If custom resource ID is set on the agent, matching custom resource IDs must be specified per tenant on the server.

## Workload attestation

Configured on the agent only. Multiple workload attestors can be combined for a single workload.

| Attestor | Use case | Key selectors |
|---|---|---|
| **Kubernetes** | K8s pods | namespace, service account, labels |
| **Docker** | Docker containers | image, environment variables |
| **Unix** | Linux processes | unix group, process metadata |

## Server datastore

Configured via `DataStore "sql"` plugin in `server.conf`.

**SQLite** (default, testing only):

```hcl
DataStore "sql" {
    plugin_data {
        database_type = "sqlite3"
        connection_string = "/opt/spire/data/server/datastore.sqlite3"
    }
}
```

**MySQL** (production):

```hcl
DataStore "sql" {
    plugin_data {
        database_type = "mysql"
        connection_string = "username:password@tcp(localhost:3306)/dbname?parseTime=true"
    }
}
```

**Postgres** (production):

```hcl
DataStore "sql" {
    plugin_data {
        database_type = "postgres"
        connection_string = "dbname=mydb user=myuser password=mypass host=localhost port=5432"
    }
}
```

## Key management

Both server and agent support:

- **Memory**: keys stored in-memory only; lost on restart, agent must re-attest
- **Disk**: keys stored on disk; survive restarts but require file access protection

## Upstream authority (signing key)

Configured via `UpstreamAuthority` in `server.conf`. Options:

- **disk**: load CA credentials from disk
- **awssecret**: AWS Secrets Manager
- **aws_pca**: AWS Certificate Manager Private CA
- **spire**: another SPIRE installation (Nested SPIRE)

Generate on-disk root key and cert:

```bash
sudo openssl req \
    -subj "/C=/ST=/L=/O=/CN=acme.com" \
    -newkey rsa:2048 -nodes -keyout /opt/spire/conf/root.key \
    -x509 -days 365 -out /opt/spire/conf/root.crt
```

> The signing key is extremely sensitive — compromise allows impersonation of the SPIRE Server.

## Telemetry

Export metrics to Prometheus, DogStatsD, StatsD, or M3. Configured in the `telemetry` block:

```hcl
telemetry {
    Prometheus {
        port = 9988
    }
    DogStatsd = [
        { address = "localhost:8125" },
    ]
    Statsd = [
        { address = "localhost:1337" },
    ]
    M3 = [
        { address = "localhost:9000" env = "prod" },
    ]
    InMem {
        enabled = false
    }
}
```

## Logging

- `log_file`: path to log file (default: STDOUT)
- `log_level`: one of `DEBUG`, `INFO`, `WARN`, `ERROR`

## Kubernetes deployment

For Kubernetes-specific installation steps (namespaces, service accounts, configmaps, statefulsets, daemonsets), see [references/kubernetes-deployment.md](references/kubernetes-deployment.md).

## Additional resources

- For Kubernetes deployment details, see [references/kubernetes-deployment.md](references/kubernetes-deployment.md)
