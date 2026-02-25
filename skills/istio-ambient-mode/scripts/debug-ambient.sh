#!/usr/bin/env bash
# debug-ambient.sh — Check ztunnel logs, listening sockets, and iptables rules
# for an ambient-enrolled pod.
#
# Usage: bash scripts/debug-ambient.sh <APP_LABEL> <NAMESPACE>
# Example: bash scripts/debug-ambient.sh curl ambient-demo

set -euo pipefail

APP_LABEL="${1:-}"
NAMESPACE="${2:-default}"

if [ -z "$APP_LABEL" ]; then
  echo "Usage: $0 <APP_LABEL> [NAMESPACE]"
  echo "Example: $0 curl ambient-demo"
  exit 1
fi

POD_NAME=$(kubectl get pod -l "app=${APP_LABEL}" -n "${NAMESPACE}" -o jsonpath='{.items[0].metadata.name}' 2>/dev/null || true)

if [ -z "$POD_NAME" ]; then
  echo "ERROR: No pod found with label app=${APP_LABEL} in namespace ${NAMESPACE}"
  exit 1
fi

echo "========================================"
echo "Target pod: ${POD_NAME} (namespace: ${NAMESPACE})"
echo "========================================"

# --- Step 1: Check ztunnel logs ---
echo ""
echo "--- Step 1: Ztunnel inpod logs ---"
echo "Looking for inpod-related log entries..."
echo ""
kubectl logs ds/ztunnel -n istio-system 2>/dev/null | grep -i inpod || echo "WARNING: No inpod log entries found. Is ztunnel running?"

# --- Step 2: Check listening sockets ---
echo ""
echo "--- Step 2: Listening sockets in pod ${POD_NAME} ---"
echo "Expecting ports 15001, 15006, 15008 in LISTEN state."
echo ""
kubectl debug "${POD_NAME}" -it -n "${NAMESPACE}" \
  --image=nicolaka/netshoot \
  -- ss -ntlp 2>/dev/null || echo "WARNING: Could not check sockets. Ensure debug containers are allowed."

# --- Step 3: Check iptables rules ---
echo ""
echo "--- Step 3: iptables rules in pod ${POD_NAME} ---"
echo "Expecting ISTIO_PRERT and ISTIO_OUTPUT chains."
echo ""
kubectl debug "${POD_NAME}" -it -n "${NAMESPACE}" \
  --image=gcr.io/istio-release/base \
  --profile=netadmin \
  -- iptables-save 2>/dev/null || echo "WARNING: Could not check iptables. Ensure debug containers with netadmin profile are allowed."

echo ""
echo "========================================"
echo "Debug checks complete."
echo "========================================"
