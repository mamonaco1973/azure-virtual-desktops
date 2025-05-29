#!/bin/bash

default_domain=$(az rest --method get --url "https://graph.microsoft.com/v1.0/domains" --query "value[?isDefault].id" --output tsv)
echo "NOTE: Default domain for account is $default_domain"

#-------------------------------------------------------------------------------
# STEP 1: Destroy AVD infrastructure (VNet, Subnet, NICs, NSGs, etc.)
#-------------------------------------------------------------------------------
cd 01-avd                          # Go to base infra config
terraform init                     # Initialize Terraform plugins/modules
terraform destroy -var="azure_domain=$default_domain" -auto-approve    
                                   # Destroy all foundational Azure resources
cd ..                              # Return to root

#-------------------------------------------------------------------------------
# END OF SCRIPT
#-------------------------------------------------------------------------------
