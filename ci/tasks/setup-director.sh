#!/usr/bin/env bash

set -e

source bosh-cpi-release/ci/tasks/utils.sh

check_param BASE_OS
check_param AZURE_SUBSCRIPTION_ID
check_param AZURE_CLIENT_ID
check_param AZURE_CLIENT_SECRET
check_param AZURE_TENANT_ID
check_param AZURE_GROUP_NAME_FOR_VMS
check_param AZURE_GROUP_NAME_FOR_NETWORK
check_param AZURE_VNET_NAME_FOR_BATS
check_param AZURE_STORAGE_ACCOUNT_NAME
check_param AZURE_BOSH_SUBNET_NAME
check_param AZURE_DEFAULT_SECURITY_GROUP
check_param SSH_PRIVATE_KEY
check_param SSH_PUBLIC_KEY
check_param BAT_NETWORK_GATEWAY
check_param BAT_DIRECTOR_PASSWORD

azure login --service-principal -u ${AZURE_CLIENT_ID} -p ${AZURE_CLIENT_SECRET} --tenant ${AZURE_TENANT_ID}
azure config mode arm

DIRECTOR=$(azure network public-ip show ${AZURE_GROUP_NAME_FOR_NETWORK} AzureCPICI-bosh --json | jq '.ipAddress' -r)

source /etc/profile.d/chruby.sh
chruby 2.2.4

semver=`cat version-semver/number`
cpi_release_name=bosh-azure-cpi
deployment_dir="${PWD}/deployment"
manifest_filename="director-manifest.yml"

mkdir -p $deployment_dir
echo "$SSH_PRIVATE_KEY" > $deployment_dir/bats.pem

cat > "${deployment_dir}/${manifest_filename}"<<EOF
---
name: bosh

releases:
- name: bosh
  url: file://bosh-release.tgz
- name: bosh-azure-cpi
  url: file://bosh-azure-cpi.tgz

networks:
- name: public
  type: vip
  cloud_properties:
    resource_group_name: $AZURE_GROUP_NAME_FOR_NETWORK
- name: private
  type: manual
  subnets:
  - range: 10.0.0.0/24
    gateway: 10.0.0.1
    dns: [168.63.129.16]
    cloud_properties:
      resource_group_name: $AZURE_GROUP_NAME_FOR_NETWORK
      virtual_network_name: $AZURE_VNET_NAME_FOR_BATS
      subnet_name: $AZURE_BOSH_SUBNET_NAME

resource_pools:
- name: vms
  network: private
  stemcell:
    url: file://stemcell.tgz
  cloud_properties:
    instance_type: Standard_D1

disk_pools:
- name: disks
  disk_size: 25_000

jobs:
- name: bosh
  templates:
  - {name: powerdns, release: bosh}
  - {name: nats, release: bosh}
  - {name: postgres, release: bosh}
  - {name: blobstore, release: bosh}
  - {name: director, release: bosh}
  - {name: health_monitor, release: bosh}
  - {name: registry, release: bosh}
  - {name: cpi, release: bosh-azure-cpi}

  instances: 1
  resource_pool: vms
  persistent_disk_pool: disks

  networks:
  - name: private
    static_ips: [10.0.0.10]
    default: [dns, gateway]
  - name: public
    static_ips: [$DIRECTOR]

  properties:
    nats:
      address: 127.0.0.1
      user: nats
      password: nats-password

    postgres: &db
      host: 127.0.0.1
      user: postgres
      password: postgres-password
      database: bosh
      adapter: postgres

    dns:
      address: $DIRECTOR
      db:
        user: postgres
        password: postgres-password
        host: 127.0.0.1
        listen_address: 127.0.0.1
        database: bosh
      user: powerdns
      password: powerdns
      database:
        name: powerdns
      webserver:
        password: powerdns
      replication:
        basic_auth: replication:zxKDUBeCfKYXk
        user: replication
        password: powerdns
      recursor: 168.63.129.16

    # Tells the Director/agents how to contact registry
    registry:
      address: 10.0.0.10
      host: 10.0.0.10
      db: *db
      http: {user: admin, password: $BAT_DIRECTOR_PASSWORD, port: 25777}
      username: admin
      password: $BAT_DIRECTOR_PASSWORD
      port: 25777

    # Tells the Director/agents how to contact blobstore
    blobstore:
      address: 10.0.0.10
      port: 25250
      provider: dav
      director: {user: director, password: director-password}
      agent: {user: agent, password: agent-password}

    director:
      address: 127.0.0.1
      name: bosh
      db: *db
      cpi_job: cpi
      enable_snapshots: true
      timeout: "180s"
      max_threads: 10
      user_management:
        provider: local
        local:
          users:
          - {name: admin, password: $BAT_DIRECTOR_PASSWORD}
          - {name: hm-user, password: $BAT_DIRECTOR_PASSWORD}

    hm:
      director_account: {user: hm-user, password: $BAT_DIRECTOR_PASSWORD}
      resurrector_enabled: true

    azure: &azure
      environment: AzureCloud
      subscription_id: $AZURE_SUBSCRIPTION_ID
      storage_account_name: $AZURE_STORAGE_ACCOUNT_NAME
      resource_group_name: $AZURE_GROUP_NAME_FOR_VMS
      tenant_id: $AZURE_TENANT_ID
      client_id: $AZURE_CLIENT_ID
      client_secret: $AZURE_CLIENT_SECRET
      ssh_user: vcap
      ssh_public_key: $SSH_PUBLIC_KEY
      default_security_group: $AZURE_DEFAULT_SECURITY_GROUP

    # Tells agents how to contact nats
    agent: {mbus: "nats://nats:nats-password@10.0.0.10:4222"}

    ntp: &ntp [0.north-america.pool.ntp.org]

cloud_provider:
  template: {name: cpi, release: bosh-azure-cpi}

  # Tells bosh-init how to SSH into deployed VM
  ssh_tunnel:
    host: $DIRECTOR
    #host: 10.0.0.10
    port: 22
    user: vcap
    private_key: $deployment_dir/bats.pem

  # Tells bosh-init how to contact remote agent
  mbus: https://mbus-user:mbus-password@$DIRECTOR:6868

  properties:
    azure: *azure

    # Tells CPI how agent should listen for bosh-init requests
    agent: {mbus: "https://mbus-user:mbus-password@0.0.0.0:6868"}

    blobstore: {provider: local, path: /var/vcap/micro_bosh/data/cache}

    ntp: *ntp
EOF

cp ./bosh-cpi-dev-artifacts/${cpi_release_name}-${semver}.tgz ${deployment_dir}/${cpi_release_name}.tgz
cp ./stemcell/*.tgz ${deployment_dir}/stemcell.tgz
cp ./bosh-release/release.tgz ${deployment_dir}/bosh-release.tgz

initver=$(cat bosh-init/version)
initexe="$PWD/bosh-init/bosh-init-${initver}-linux-amd64"

chmod +x $initexe
$initexe version

cd $deployment_dir

$initexe deploy $manifest_filename

echo "Final state of director deployment:"
echo "=========================================="
cat director-manifest-state.json
echo "=========================================="
