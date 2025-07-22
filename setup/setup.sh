#!/usr/bin/env bash

set -euo pipefail

# ------------------------------------------------------------
# Helper: run curl, surface HTTP status + response body.
# Returns the body on STDOUT so callers can still capture it,
# and exits non‑zero on non‑2xx to preserve existing logic.
# ------------------------------------------------------------
curl_json() {
  # Execute curl and append HTTP code on a new line
  local response status body
  response=$(curl --silent --show-error --write-out "\n%{http_code}" "$@")
  status=${response##*$'\n'}
  body=${response%$'\n'*}

  # Surface status and error body only when not 200/404
  echo -e ">> HTTP status: ${status}" >&2
  if [[ "${status}" != "200" && "${status}" != "404" ]]; then
    echo "${body}" >&2
  fi

  # Emit body and status (body first, status last) so caller can parse
  printf '%s\n%s\n' "${body}" "${status}"

  # Non‑2xx return non‑zero so callers can still `|| true`
  [[ "${status}" =~ ^2 ]]
}

# Check if k3d cluster 'gdcluster' already exists
if k3d cluster list | grep -q "^gdcluster\s"; then
  echo ">> Cluster 'gdcluster' already exists. To start over, run 'k3d cluster delete gdcluster'."
  exit 0
fi

###
# Find latest GoodData.CN Helm release
###
LATEST_GDCN_CHART_VERSION=$(curl -fs https://artifacthub.io/api/v1/packages/helm/gooddata-cn/gooddata-cn/feed/rss |
  awk -F'[<>]' '/<item>/{getline; if ($3 ~ /^[0-9.]+$/){print $3; exit}}')

# Fallback to previous default if the feed is unreachable or parsing fails
LATEST_GDCN_CHART_VERSION=${LATEST_GDCN_CHART_VERSION:-3.36.0}

###
# Interactive prompts for environment config
###
read -e -rsp ">> GoodData.CN license key: " GDCN_LICENSE_KEY
echo
if [ -z "$GDCN_LICENSE_KEY" ]; then
  echo -e "\n\n>> ERROR: GoodData.CN license key is required" >&2
  exit 1
fi

read -e -p ">> GoodData.CN hostname [default: localhost]: " GDCN_HOSTNAME
GDCN_HOSTNAME=${GDCN_HOSTNAME:-localhost}

read -e -p ">> GoodData.CN organization ID [default: test]: " GDCN_ORG_ID
GDCN_ORG_ID=${GDCN_ORG_ID:-test}

read -e -p ">> GoodData.CN organization display name [default: Test, Inc.]: " GDCN_ORG_NAME
GDCN_ORG_NAME=${GDCN_ORG_NAME:-Test, Inc.}

read -e -p ">> GoodData.CN admin username [default: admin]: " GDCN_ADMIN_USER
GDCN_ADMIN_USER=${GDCN_ADMIN_USER:-admin}

read -rsp ">> GoodData.CN admin password: " GDCN_ADMIN_PASSWORD
echo
if [ -z "$GDCN_ADMIN_PASSWORD" ]; then
  echo -e "\n\n>> ERROR: GoodData.CN admin password is required" >&2
  exit 1
fi
GDCN_ADMIN_HASH=$(openssl passwd -6 "$GDCN_ADMIN_PASSWORD")
GDCN_BOOT_TOKEN_RAW="${GDCN_ADMIN_USER}:bootstrap:${GDCN_ADMIN_PASSWORD}"
GDCN_BOOT_TOKEN=$(printf '%s' "$GDCN_BOOT_TOKEN_RAW" | base64)

read -e -p ">> GoodData.CN admin group [default: adminGroup]: " GDCN_ADMIN_GROUP
GDCN_ADMIN_GROUP=${GDCN_ADMIN_GROUP:-adminGroup}

read -e -p ">> GoodData.CN first user email [default: admin@${GDCN_HOSTNAME}]: " GDCN_DEX_USER_EMAIL
GDCN_DEX_USER_EMAIL=${GDCN_DEX_USER_EMAIL:-admin@$GDCN_HOSTNAME}

read -s -p ">> GoodData.CN first user password: " GDCN_DEX_USER_PASSWORD
echo
if [ -z "$GDCN_DEX_USER_PASSWORD" ]; then
  echo -e "\n\n>> ERROR: GoodData.CN first user password is required" >&2
  exit 1
fi

read -e -p ">> GoodData.CN chart version [default: ${LATEST_GDCN_CHART_VERSION}]: " GDCN_CHART_VERSION
GDCN_CHART_VERSION=${GDCN_CHART_VERSION:-$LATEST_GDCN_CHART_VERSION}

read -e -p ">> (optional) Docker Hub username: " DOCKER_USERNAME
export DOCKER_USERNAME

read -rsp ">> (optional) Docker Hub password or personal access token: " DOCKER_PASSWORD
export DOCKER_PASSWORD

###
# Verify Docker Hub credentials (if both username and password/PAT were provided)
###
if [ -n "${DOCKER_USERNAME:-}" ] && [ -n "${DOCKER_PASSWORD:-}" ]; then
  echo -e "\n\n>> Verifying Docker Hub credentials..."
  TMP_DOCKER_CONFIG=$(mktemp -d)

  # Run docker login in a subshell so 'set -e' doesn't abort the script prematurely.
  if echo "${DOCKER_PASSWORD}" | docker --config "${TMP_DOCKER_CONFIG}" login --username "${DOCKER_USERNAME}" --password-stdin >/dev/null 2>&1; then
    echo ">> Docker Hub credentials verified."
  else
    echo -e "\n\n>> ERROR: Docker Hub authentication failed. Please check your username/password (or PAT if 2FA is enabled)." >&2
    rm -rf "${TMP_DOCKER_CONFIG}"
    exit 1
  fi

  rm -rf "${TMP_DOCKER_CONFIG}"
fi

###
# Create k3d cluster
###
echo -e "\n\n>> Creating k3d cluster 'gdcluster'..."

k3d cluster create \
  -c ./k3d-config.yaml

###
# Switch kubectl context to the new cluster
###
echo -e "\n\n>> Switching kubectl context to k3d-gdcluster..."
kubectl config use-context k3d-gdcluster

###
# Install Ingress NGINX via Helm
###
echo -e "\n\n>> Adding Pulsar Helm repo and installing Pulsar..."
helm repo add ingress-nginx https://kubernetes.github.io/ingress-nginx
helm repo update
helm install ingress-nginx ingress-nginx/ingress-nginx \
  --namespace ingress-nginx --create-namespace \
  --version 4.12.1 \
  -f ./values-ingress.yaml

# Wait for Ingress NGINX controller to be ready
echo -e "\n\n>> Waiting for ingress-nginx-controller Deployment to become available..."
until kubectl -n ingress-nginx get deployment ingress-nginx-controller &>/dev/null; do
  sleep 2
done
kubectl wait --for=condition=available --timeout=300s deployment/ingress-nginx-controller -n ingress-nginx

###
# Install Pulsar via Helm
###
echo -e "\n\n>> Adding Pulsar Helm repo and installing Pulsar..."
helm repo add apache https://pulsar.apache.org/charts
helm repo update
helm install pulsar apache/pulsar \
  --namespace pulsar --create-namespace \
  --version 3.9.0 \
  -f ./values-pulsar.yaml

# Wait for all non-job Pulsar pods to be Running and Ready
echo -e "\n\n>> Waiting for all Pulsar pods (excluding jobs) to be ready..."
kubectl wait --for=condition=Ready --timeout=1800s pod -l '!job-name' -n pulsar

###
# Install GoodData.CN
###

# Create the gooddata-cn namespace
echo -e "\n\n>> Creating gooddata-cn namespace..."
kubectl apply -f ./namespace-gdcn.yaml

# Generate encryption keyset and create secret
echo -e "\n\n>> Generating encryption keyset..."

# Output keyset
rm -f ./output_keyset.json
tinkey create-keyset --key-template AES256_GCM --out ./output_keyset.json 2>/dev/null

echo -e "\n\n>> Creating gdcn-encryption secret..."
kubectl -n gooddata-cn create secret generic gdcn-encryption --from-file keySet=./output_keyset.json

# Create license secret (replace the literal with your actual license)
echo -e "\n\n>> Creating gooddata-cn-license secret..."
kubectl -n gooddata-cn create secret generic gooddata-cn-license --from-literal=license="$GDCN_LICENSE_KEY"

# Install GoodData.CN using Helm
echo -e "\n\n>> Installing GoodData.CN chart version ${GDCN_CHART_VERSION}..."
helm repo add gooddata https://charts.gooddata.com/
helm repo update
helm install gooddata-cn gooddata/gooddata-cn \
  --namespace gooddata-cn \
  --version "${GDCN_CHART_VERSION}" \
  --set-string dex.ingress.authHost="${GDCN_HOSTNAME}" \
  -f ./values-gdcn.yaml

# Prompt user to check pod status
echo -e "\n\n>> Waiting for all GoodData.CN pods to be ready..."
kubectl wait --for=condition=ready --timeout=1800s pod -l '!job-name' -n gooddata-cn
echo -e "\n\n>> All GoodData.CN pods are running and ready."

###
# Create GoodData.CN Organization
###
echo -e "\n\n>> Applying Organization to Kubernetes..."
kubectl -n gooddata-cn apply -f - <<EOF
apiVersion: controllers.gooddata.com/v1
kind: Organization
metadata:
  name: ${GDCN_ORG_ID}-org
spec:
  id: ${GDCN_ORG_ID}
  name: "${GDCN_ORG_NAME}"
  hostname: ${GDCN_HOSTNAME}
  adminGroup: ${GDCN_ADMIN_GROUP}
  adminUser: ${GDCN_ADMIN_USER}
  adminUserToken: "${GDCN_ADMIN_HASH}"
EOF

###
# Create Dex user and update GoodData admin
###
echo -e "\n\n>> Creating first GoodData.CN user..."
# Doing multiple retries since it can take a moment for the Organization API to become available
for i in {1..200}; do
  full=$(curl_json -X POST "http://host.docker.internal/api/v1/auth/users" \
    -H "Host: ${GDCN_HOSTNAME}" \
    -H "Authorization: Bearer ${GDCN_BOOT_TOKEN}" \
    -H "Content-type: application/json" \
    -d '{
          "email": "'"${GDCN_DEX_USER_EMAIL}"'",
          "password": "'"${GDCN_DEX_USER_PASSWORD}"'",
          "displayName": "'"${GDCN_ADMIN_USER}"'"
        }') || true
  http_status=$(printf '%s\n' "${full}" | tail -n1)
  dex_response=$(printf '%s\n' "${full}" | sed '$d')

  # Fatal on 400 without retry
  if [[ "${http_status}" == "400" ]]; then
    echo -e "\n\n>> ERROR: Received 400 error from API. Correct the problem and try again." >&2
    exit 1
  fi

  # Break on success (2xx)
  if [[ "${http_status}" =~ ^2 ]]; then
    break
  fi

  echo -e "\n\n>> GoodData.CN authentication endpoint not ready. Retrying in 5s..."
  sleep 5
done
if [ -z "${dex_response:-}" ]; then
  echo -e "\n\n>> ERROR: Failed to create first user after multiple attempts" >&2
  exit 1
fi
dex_auth_id=$(echo "$dex_response" | grep -oP '"authenticationId"\s*:\s*"\K[^"]+')

echo -e "\n\n>> Configuring first user in organization..."
full=$(curl_json -X PATCH "http://host.docker.internal/api/v1/entities/users/${GDCN_ADMIN_USER}" \
  -H "Host: ${GDCN_HOSTNAME}" \
  -H "Authorization: Bearer ${GDCN_BOOT_TOKEN}" \
  -H "Content-Type: application/vnd.gooddata.api+json" \
  -d '{
      "data": {
          "id": "'"${GDCN_ADMIN_USER}"'",
          "type": "user",
          "attributes": {
              "authenticationId": "'"${dex_auth_id}"'",
              "email": "'"${GDCN_DEX_USER_EMAIL}"'",
              "firstname": "'"$(echo "${GDCN_DEX_USER_EMAIL}" | cut -d'@' -f1)"'",
              "lastname": ""
          }
      }
  }')

echo -e "\n\n\n>> Organization and user setup complete."
echo -e ">> Log in at http://${GDCN_HOSTNAME} with ${GDCN_DEX_USER_EMAIL} and your chosen password."
echo -e ">> If you need to make API calls, you can use this bearer token: ${GDCN_BOOT_TOKEN}"
