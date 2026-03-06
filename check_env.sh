#!/bin/bash
# ================================================================================
# Environment validation for AVD deployment
# --------------------------------------------------------------------------------
# Verifies required tools, environment variables, and Azure authentication
# before running the Terraform deployment.
#
# Validation steps
#   1. Confirm required CLI tools are available.
#   2. Confirm required Azure authentication environment variables exist.
#   3. Authenticate to Azure using the configured service principal.
#   4. Verify required Entra ID role permissions.
#   5. Ensure required Azure resource providers are registered.
# ================================================================================

set -euo pipefail

# ================================================================================
# Validate required CLI tools
# --------------------------------------------------------------------------------
# Confirms that required commands are available in the system PATH.
#
# Required tools
#   az         Azure CLI
#   terraform  Terraform CLI
#   jq         JSON processor
# ================================================================================
echo "NOTE: Validating that required commands are found in your PATH."

commands=("az" "terraform" "jq")
all_found=true

for cmd in "${commands[@]}"; do
  if ! command -v "$cmd" >/dev/null 2>&1; then
    echo "ERROR: $cmd is not found in the current PATH."
    all_found=false
  else
    echo "NOTE: $cmd is found in the current PATH."
  fi
done

if [ "$all_found" = true ]; then
  echo "NOTE: All required commands are available."
else
  echo "ERROR: One or more required commands are missing."
  exit 1
fi

# ================================================================================
# Validate required environment variables
# --------------------------------------------------------------------------------
# Confirms that required Azure service principal credentials are defined.
#
# Required variables
#   ARM_CLIENT_ID
#   ARM_CLIENT_SECRET
#   ARM_SUBSCRIPTION_ID
#   ARM_TENANT_ID
# ================================================================================
echo "NOTE: Validating that required environment variables are set."

required_vars=(
  "ARM_CLIENT_ID"
  "ARM_CLIENT_SECRET"
  "ARM_SUBSCRIPTION_ID"
  "ARM_TENANT_ID"
)

all_set=true

for var in "${required_vars[@]}"; do
  if [ -z "${!var:-}" ]; then
    echo "ERROR: $var is not set or is empty."
    all_set=false
  else
    echo "NOTE: $var is set."
  fi
done

if [ "$all_set" = true ]; then
  echo "NOTE: All required environment variables are set."
else
  echo "ERROR: One or more required environment variables are missing."
  exit 1
fi

# ================================================================================
# Authenticate to Azure
# --------------------------------------------------------------------------------
# Logs into Azure using the provided service principal credentials.
# ================================================================================
echo "NOTE: Logging in to Azure using Service Principal..."

az login \
  --service-principal \
  --username "$ARM_CLIENT_ID" \
  --password "$ARM_CLIENT_SECRET" \
  --tenant "$ARM_TENANT_ID" \
  >/dev/null 2>&1

echo "NOTE: Successfully logged into Azure."

# ================================================================================
# Validate Entra ID role permissions
# --------------------------------------------------------------------------------
# Ensures the current identity has the Global Administrator role
# required for some Entra ID operations.
# ================================================================================
ROLE_CHECK=$(
  az rest \
    --method GET \
    --url "https://graph.microsoft.com/v1.0/directoryRoles" \
    --query "value[?displayName=='Global Administrator'].id" \
    --output tsv
)

if [ -z "$ROLE_CHECK" ]; then
  echo "ERROR: 'Global Administrator' Entra role is NOT assigned."
  exit 1
else
  echo "NOTE: 'Global Administrator' Entra role is assigned."
fi

# ================================================================================
# Validate required Azure provider registration
# --------------------------------------------------------------------------------
# Waits until the required Azure resource provider is registered.
# Some resources cannot deploy until the provider is registered.
# ================================================================================
while [[ "$(az provider show \
  --namespace Microsoft.App \
  --query "registrationState" \
  --output tsv)" != "Registered" ]]; do

  echo "NOTE: Waiting for Microsoft.App provider registration..."
  sleep 10
done

echo "NOTE: Microsoft.App provider is registered."