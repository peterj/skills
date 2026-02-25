# Security Troubleshooting

## Table of contents

- [End-user authentication (JWT) failures](#end-user-authentication)
- [Authorization policy issues](#authorization-policy-issues)
- [Verifying Istiod processes policies](#verify-istiod)
- [Verifying proxy enforcement](#verify-proxy-enforcement)
- [Keys and certificates inspection](#keys-and-certificates)
- [Mutual TLS errors](#mutual-tls-errors)

## End-user authentication {#end-user-authentication}

Troubleshoot `RequestAuthentication` policies:

1. **Verify `jwksUri`**: If not set, the JWT issuer must be a URL where `<issuer>/.well-known/openid-configuration` is accessible.

2. **Validate the JWT token**: Ensure it's not expired. Use [jwt.io](https://jwt.io/) to decode and inspect.

3. **Check Envoy proxy config**:
   ```bash
   POD=$(kubectl get pod -l app=httpbin -n foo -o jsonpath={.items..metadata.name})
   istioctl proxy-config listener ${POD} -n foo --port 80 --type HTTP -o json
   ```
   Look for `envoy.filters.http.jwt_authn` filter with correct issuer and JWKS settings.

## Authorization policy issues {#authorization-policy-issues}

### YAML list semantics (common mistake)

Multiple `-` entries under `rules` create separate rules with OR semantics, not AND.

**Overly permissive** (two rules — path `/foo` OR namespace `foo`):
```yaml
rules:
- to:
  - operation:
      paths: ["/foo"]
- from:
  - source:
      namespaces: ["foo"]
```

**Correct** (one rule — path `/foo` AND namespace `foo`):
```yaml
rules:
- to:
  - operation:
      paths: ["/foo"]
  from:
  - source:
      namespaces: ["foo"]
```

### HTTP-only fields on TCP ports

HTTP-only fields (`host`, `path`, `headers`, JWT) don't exist in raw TCP connections:
- In `ALLOW` policies: these fields never match → more restrictive.
- In `DENY`/`CUSTOM` policies: these fields are always matched → more restrictive.

**Fix**: Ensure the port name has an `http-` prefix if using HTTP-only fields.

### Policy targeting

Verify correct workload selector and namespace. Check effective policies:
```bash
istioctl x authz check POD-NAME.POD-NAMESPACE
```

### Action evaluation order

- Default action is `ALLOW` if not specified.
- When `CUSTOM`, `ALLOW`, and `DENY` are all applied, all must be satisfied. Any deny → request denied.
- `AUDIT` never denies requests.

## Verify Istiod processes policies {#verify-istiod}

1. Enable debug logging:
   ```bash
   istioctl admin log --level authorization:debug
   ```

2. Check Istiod logs (re-apply policies to generate debug output):
   ```bash
   kubectl logs $(kubectl -n istio-system get pods -l app=istiod -o jsonpath='{.items[0].metadata.name}') -c discovery -n istio-system
   ```

3. Look for lines like:
   ```
   debug authorization Processed authorization policy for httpbin-xxx.foo with details:
       * found 1 DENY actions, 0 ALLOW actions, 0 AUDIT actions
       * generated config from rule ns[foo]-policy[deny-path-headers]-rule[0] on HTTP filter chain successfully
   ```

## Verify proxy enforcement {#verify-proxy-enforcement}

1. Get proxy config dump:
   ```bash
   kubectl exec $(kubectl get pods -l app=httpbin -o jsonpath='{.items[0].metadata.name}') -c istio-proxy -- pilot-agent request GET config_dump
   ```
   Look for `envoy.filters.http.rbac` filter with expected rules.

2. Enable RBAC debug logging:
   ```bash
   istioctl proxy-config log deploy/httpbin --level "rbac:debug"
   ```

3. Send test requests and check proxy logs:
   ```bash
   kubectl logs $(kubectl get pods -l app=httpbin -o jsonpath='{.items[0].metadata.name}') -c istio-proxy
   ```
   - `enforced allowed` — request permitted
   - `enforced denied, matched policy ns[foo]-policy[name]-rule[N]` — request denied by specific policy
   - `shadow denied` — dry-run mode would have denied
   - `no engine, allowed by default` — no enforcing policy, allowed

## Keys and certificates {#keys-and-certificates}

Inspect certificates on any pod:
```bash
istioctl proxy-config secret POD-NAME
```

View full certificate details:
```bash
istioctl proxy-config secret POD-NAME -o json | \
  jq '[.dynamicActiveSecrets[] | select(.name == "default")][0].secret.tlsCertificate.certificateChain.inlineBytes' -r | \
  base64 -d | openssl x509 -noout -text
```

Verify that `Subject Alternative Name` is `URI:spiffe://cluster.local/ns/<namespace>/sa/<service-account>`.

## Mutual TLS errors {#mutual-tls-errors}

1. Ensure Istiod is healthy.
2. Verify keys/certificates are delivered to sidecars (see above).
3. Verify correct authentication policy and destination rules are applied.
4. Check the [Grafana Workload dashboard](https://istio.io/docs/ops/integrations/grafana/) — outbound requests show whether mTLS is used.
