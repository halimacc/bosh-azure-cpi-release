#!/usr/bin/env bash

set -e

source bosh-cpi-release/ci/tasks/utils.sh

check_param AZURE_SUBSCRIPTION_ID
check_param AZURE_CLIENT_ID
check_param AZURE_CLIENT_SECRET
check_param AZURE_TENANT_ID
check_param AZURE_GROUP_NAME_FOR_VMS
check_param AZURE_GROUP_NAME_FOR_NETWORK
check_param AZURE_STORAGE_ACCOUNT_NAME
check_param AZURE_VNET_NAME_FOR_LIFECYCLE
check_param AZURE_BOSH_SUBNET_NAME
check_param AZURE_DEFAULT_SECURITY_GROUP
check_param SSH_PUBLIC_KEY

export BOSH_AZURE_SUBSCRIPTION_ID=${AZURE_SUBSCRIPTION_ID}
export BOSH_AZURE_TENANT_ID=${AZURE_TENANT_ID}
export BOSH_AZURE_CLIENT_ID=${AZURE_CLIENT_ID}
export BOSH_AZURE_CLIENT_SECRET=${AZURE_CLIENT_SECRET}
export BOSH_AZURE_STORAGE_ACCOUNT_NAME=${AZURE_STORAGE_ACCOUNT_NAME}
export BOSH_AZURE_RESOURCE_GROUP_NAME_FOR_VMS=${AZURE_GROUP_NAME_FOR_VMS}
export BOSH_AZURE_RESOURCE_GROUP_NAME_FOR_NETWORK=${AZURE_GROUP_NAME_FOR_NETWORK}
export BOSH_AZURE_VNET_NAME=${AZURE_VNET_NAME_FOR_LIFECYCLE}
export BOSH_AZURE_SUBNET_NAME=${AZURE_BOSH_SUBNET_NAME}
export BOSH_AZURE_SSH_PUBLIC_KEY=${SSH_PUBLIC_KEY}
export BOSH_AZURE_DEFAULT_SECURITY_GROUP=${AZURE_DEFAULT_SECURITY_GROUP}
export BOSH_AZURE_STEMCELL_ID="bosh-stemcell-00000000-0000-0000-0000-0AZURECPICI0"

azure login --service-principal -u ${AZURE_CLIENT_ID} -p ${AZURE_CLIENT_SECRET} --tenant ${AZURE_TENANT_ID}
azure config mode arm

export BOSH_AZURE_PRIMARY_PUBLIC_IP=$(azure network public-ip show ${AZURE_GROUP_NAME_FOR_VMS} AzureCPICI-cf-lifecycle --json | jq '.ipAddress' -r)
export BOSH_AZURE_SECONDARY_PUBLIC_IP=$(azure network public-ip show ${AZURE_GROUP_NAME_FOR_NETWORK} AzureCPICI-cf-lifecycle --json | jq '.ipAddress' -r)

export AZURE_STORAGE_ACCOUNT=${AZURE_STORAGE_ACCOUNT_NAME}
export AZURE_STORAGE_ACCESS_KEY=$(azure storage account keys list ${AZURE_STORAGE_ACCOUNT_NAME} -g ${AZURE_GROUP_NAME_FOR_VMS} --json | jq '.[0].value' -r)

# Always upload the latest stemcell for lifecycle test
tar -xf ${PWD}/stemcell/*.tgz -C /mnt/
tar -xf /mnt/image -C /mnt/
azure storage blob upload --quiet --blobtype PAGE /mnt/root.vhd stemcell ${BOSH_AZURE_STEMCELL_ID}.vhd

source /etc/profile.d/chruby.sh
chruby 2.2.4

pushd bosh-cpi-release/src/bosh_azure_cpi
  bundle install
  bundle exec rspec spec/integration
popd
