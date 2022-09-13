#!/bin/bash
## ----------------------------------------------------------------------
## Requirement:
##   o User must configure gcloud cli environment properly.
## ----------------------------------------------------------------------

set -e

env_name=${1?you must provide a GCP environment as the first argument}

## ----------------------------------------------------------------------
## Retrieve bosh director vm instance. This will fail if the gcloud
## cli environmenet isn't configured properly.
## ----------------------------------------------------------------------

bosh_director_vm="$(gcloud compute instances list --filter="networkInterfaces.networkIP~10.0.0.5 AND networkInterfaces.network~${env_name}-pcf-network" --format="value(NAME)")"

if [ -z "${bosh_director_vm}" ]; then
    echo "FATAL: bosh_director VM not found. Check your gcloud cli environment"
    gcloud config list
    exit 2
fi

## ----------------------------------------------------------------------
## Apply network tag to bosh director and ops manager instances
## ----------------------------------------------------------------------

gcloud compute instances add-tags \
       "${bosh_director_vm}" \
       --tags "${env_name}-management"

gcloud compute instances add-tags "${env_name}-ops-manager" \
       --tags "${env_name}-management"

## ----------------------------------------------------------------------
## create firewall EGRESS rules to restrict outgoing traffic
## ----------------------------------------------------------------------

gcloud compute firewall-rules create "${env_name}-internetless-management-egress" \
       --network="${env_name}-pcf-network"     \
       --direction=egress \
       --destination-ranges=0.0.0.0/0 \
       --action=allow \
       --rules=all \
       --priority=0 \
       --target-tags="${env_name}-management"

gcloud compute firewall-rules create "${env_name}-internetless-intra-pcf-vm-egress-allow" \
       --network="${env_name}-pcf-network"     \
       --direction=egress \
       --destination-ranges="$(gcloud compute addresses list  --filter "${env_name}-cf" --format="value[terminator=','](address)")"10.0.0.0/26,10.0.4.0/24,10.0.8.0/24 \
       --action=allow \
       --rules=all \
       --priority=100

gcloud compute firewall-rules create "${env_name}-internetless-egress-deny" \
       --network="${env_name}-pcf-network"     \
       --direction=egress \
       --destination-ranges=0.0.0.0/0 \
       --action=deny \
       --rules=all \
       --priority=1000

gcloud compute firewall-rules create "${env_name}-internetless-dns-egress" \
       --network="${env_name}-pcf-network"     \
       --direction=egress \
       --destination-ranges=8.8.8.8 \
       --action=allow \
       --rules=all \
       --priority=4

cat <<EOF
======================================================================
The following firewall EGRESS rules have been created
----------------------------------------------------------------------

EOF

gcloud compute firewall-rules list --filter="${env_name}-internetless-"
