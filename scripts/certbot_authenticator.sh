#!/bin/bash

# authenticate to the GCP Project
echo $GCP_SERVICE_ACCOUNT_KEY > account_key.json
gcloud auth activate-service-account --key-file account_key.json

# Create TXT record
gcloud dns record-sets transaction start --zone=${ENV_NAME}-zone
challenge_record=$(gcloud dns record-sets list -z ${ENV_NAME}-zone | grep "_acme-challenge.${CERTBOT_DOMAIN}.")
if [ -n "$challenge_record" ]; then
	echo "found the TXT record: ${challenge_record}"
	r_name=$(echo $challenge_record | awk '{print $1}')
	r_type=$(echo $challenge_record | awk '{print $2}')
	r_ttl=$(echo $challenge_record | awk '{print $3}')
	r_data=$(echo $challenge_record | awk '{print $4}')
	gcloud dns record-sets transaction remove ${r_data} --name=${r_name} --type=${r_type} --ttl=${r_ttl} --zone=${ENV_NAME}-zone
fi

# pass positional arg as data after -- to dodge issus with challenge strings starting with hyphens
# see https://issuetracker.google.com/issues/193054503?pli=1
gcloud dns record-sets transaction add --name=_acme-challenge.${CERTBOT_DOMAIN}. --ttl=300 --type=TXT --zone=${ENV_NAME}-zone -- "$CERTBOT_VALIDATION" 
gcloud dns record-sets transaction execute --zone=${ENV_NAME}-zone

# Sleep to make sure the change has time to propagate over to DNS
sleep 120
