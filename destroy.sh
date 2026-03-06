#!/bin/bash
# ================================================================================
# Destroy Azure Virtual Desktop environment
# --------------------------------------------------------------------------------
# Discovers the default Entra ID domain and runs Terraform destroy to
# remove the deployed AVD infrastructure.
#
# Steps
#   1. Query Microsoft Graph for the tenant's default domain.
#   2. Run terraform init in the AVD module directory.
#   3. Execute terraform destroy to remove all resources.
# ================================================================================

set -euo pipefail

# ================================================================================
# Discover default Entra ID domain
# --------------------------------------------------------------------------------
# Queries Microsoft Graph to determine the default domain for the
# current Azure tenant. This value must match the domain used during
# the Terraform deployment.
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
# Destroy Terraform infrastructure
# --------------------------------------------------------------------------------
# Navigates to the AVD Terraform module and destroys all deployed
# resources using the same variable values used during deployment.
# ================================================================================
cd 01-avd

terraform init

terraform destroy \
  -var="azure_domain=${default_domain}" \
  -auto-approve

cd ..