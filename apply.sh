#!/bin/bash
# ================================================================================
# Deploy Azure Virtual Desktop environment
# --------------------------------------------------------------------------------
# Runs prerequisite validation, discovers the default Entra ID domain,
# and applies the Terraform configuration for the AVD environment.
# ================================================================================
#
# Steps
#   1. Validate required tools and environment settings.
#   2. Query Microsoft Graph for the default Entra ID domain.
#   3. Run terraform init and terraform apply in the AVD module.
# ================================================================================

set -euo pipefail

# ================================================================================
# Validate local environment
# --------------------------------------------------------------------------------
# Runs the environment validation script before any deployment steps.
# The script exits immediately if validation fails.
# ================================================================================
./check_env.sh

# ================================================================================
# Discover default Entra ID domain
# --------------------------------------------------------------------------------
# Queries Microsoft Graph for the tenant's default domain. This value is
# passed into Terraform so user principal names can be built correctly.
# ================================================================================
default_domain=$(
  az rest \
    --method get \
    --url "https://graph.microsoft.com/v1.0/domains" \
    --query "value[?isDefault].id" \
    --output tsv
)

echo "NOTE: Default domain for account is ${default_domain}"

# ================================================================================
# Apply Terraform configuration
# --------------------------------------------------------------------------------
# Initializes Terraform in the AVD module directory and applies the
# deployment using the discovered default Entra ID domain.
# ================================================================================
cd 01-avd
terraform init
terraform apply \
  -var="azure_domain=${default_domain}" \
  -auto-approve
cd ..