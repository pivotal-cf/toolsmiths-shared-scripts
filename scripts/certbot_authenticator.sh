#!/bin/bash

# authenticate to the GCP Project
echo $GCP_SERVICE_ACCOUNT_KEY > account_key.json
gcloud auth activate-service-account --key-file account_key.json

# Create TXT record
gcloud dns record-sets transaction start --zone=${ENV_NAME}-zone
gcloud dns record-sets transaction add "$CERTBOT_VALIDATION" --name=_acme-challenge.${ENV_NAME}.cf-app.com. --ttl=300 --type=TXT --zone=${ENV_NAME}-zone
gcloud dns record-sets transaction execute --zone=${ENV_NAME}-zone

# Sleep to make sure the change has time to propagate over to DNS
sleep 300
