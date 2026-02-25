---
name: argocd-pagerduty-notifications
description: Configures PagerDuty v1 and v2 notification services for Argo CD. Use when setting up PagerDuty incident creation or event triggering from Argo CD notifications, including secrets, ConfigMaps, templates, and annotations for PagerDuty integrations.
---

# Argo CD PagerDuty Notifications

Argo CD supports two PagerDuty notification services: **PagerDuty v1** (incident creation via API token) and **PagerDuty v2** (event triggering via Events API v2 integration keys).

## PagerDuty v1 (Incident Creation)

### Required Parameters

- `pagerdutyToken` — PagerDuty auth token
- `from` — email address of a valid user associated with the account
- `serviceID` — the ID of the PagerDuty service (provided via annotation)

### Setup

1. Create a Secret with the auth token:

```yaml
apiVersion: v1
kind: Secret
metadata:
  name: <secret-name>
stringData:
  pagerdutyToken: <pd-api-token>
```

2. Configure the service in `argocd-notifications-cm`:

```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: argocd-notifications-cm
data:
  service.pagerduty: |
    token: $pagerdutyToken
    from: <emailid>
```

3. Create a notification template:

```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: argocd-notifications-cm
data:
  template.rollout-aborted: |
    message: Rollout {{.rollout.metadata.name}} is aborted.
    pagerduty:
      title: "Rollout {{.rollout.metadata.name}}"
      urgency: "high"
      body: "Rollout {{.rollout.metadata.name}} aborted "
      priorityID: "<priorityID of incident>"
```

> **Note:** `priorityID` is only available on PagerDuty Standard and Enterprise plans.

4. Annotate the resource to subscribe:

```yaml
apiVersion: argoproj.io/v1alpha1
kind: Rollout
metadata:
  annotations:
    notifications.argoproj.io/subscribe.on-rollout-aborted.pagerduty: "<serviceID for PagerDuty>"
```

## PagerDuty v2 (Events API v2)

### Required Parameters

- `serviceKeys` — a dictionary mapping service names to secret references containing PagerDuty Events API v2 integration keys

To create an integration key, add an Events API v2 integration to the desired PagerDuty service.

### Setup

1. Create a Secret with the integration key:

```yaml
apiVersion: v1
kind: Secret
metadata:
  name: <secret-name>
stringData:
  pagerduty-key-my-service: <pd-integration-key>
```

2. Configure the service in `argocd-notifications-cm`:

```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: argocd-notifications-cm
data:
  service.pagerdutyv2: |
    serviceKeys:
      my-service: $pagerduty-key-my-service
```

To alert multiple Argo apps to different PagerDuty services, create an integration key per service and add each to the `serviceKeys` dictionary.

3. Create a notification template:

```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: argocd-notifications-cm
data:
  template.rollout-aborted: |
    message: Rollout {{.rollout.metadata.name}} is aborted.
    pagerdutyv2:
      summary: "Rollout {{.rollout.metadata.name}} is aborted."
      severity: "critical"
      source: "{{.rollout.metadata.name}}"
```

4. Annotate the resource to subscribe:

```yaml
apiVersion: argoproj.io/v1alpha1
kind: Rollout
metadata:
  annotations:
    notifications.argoproj.io/subscribe.on-rollout-aborted.pagerdutyv2: "<serviceID for PagerDuty>"
```

### v2 Template Parameters

All parameters are strings. The template payload maps to the Events API v2 endpoint.

| Parameter | Required | Description |
|-----------|----------|-------------|
| `summary` | Yes | Brief text summary; used for alert titles |
| `severity` | Yes | `critical`, `warning`, `error`, or `info` |
| `source` | Yes | Unique location of affected system (hostname/FQDN) |
| `component` | No | Component of the source machine responsible |
| `group` | No | Logical grouping of service components |
| `class` | No | Class/type of the event |
| `url` | No | URL for "View in ArgoCD" link in PagerDuty |
| `dedupKey` | No | Deduplication string; same key groups into one incident |

> **Note:** `timestamp` and `custom_details` parameters are not currently supported.

## v1 vs v2 Quick Reference

| Aspect | v1 (`service.pagerduty`) | v2 (`service.pagerdutyv2`) |
|--------|--------------------------|----------------------------|
| Auth | API token (`$pagerdutyToken`) | Integration keys per service |
| Action | Creates incidents | Triggers events |
| Config key | `token` + `from` | `serviceKeys` dictionary |
| Template key | `pagerduty` | `pagerdutyv2` |
| Annotation service | `.pagerduty` | `.pagerdutyv2` |
| Multi-service | Single token | One integration key per service |
