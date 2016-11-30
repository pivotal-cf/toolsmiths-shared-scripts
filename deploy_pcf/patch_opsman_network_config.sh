#!/bin/bash

export OM_USERNAME="$OPSMAN_USERNAME"
export OM_PASSWORD="$OPSMAN_PASSWORD"

uaac target "https://pcf.${ENV_NAME}.cf-app.com/uaa" --skip-ssl-validation
uaac token owner get opsman $OM_USERNAME -s '' -p $OM_PASSWORD
UAA_ACCESS_TOKEN=$(uaac context | grep access_token | xargs | cut -f2 -d" ")

BOSH_GUID=$(curl -k "https://pcf.undercity.cf-app.com/api/v0/staged/products" -X GET -H "Authorization: Bearer $UAA_ACCESS_TOKEN" | jq '.[] | select(.installation_name=="p-bosh")' | jq -r .guid)

curl -k "https://pcf.undercity.cf-app.com/api/v0/staged/products/${BOSH_GUID}/networks_and_azs" \
    -X PUT \
    -H "Authorization: Bearer $UAA_ACCESS_TOKEN" \
    -H "Content-type: application/json" \
    --data '{"networks_and_azs":{"singleton_availability_zone":{"name":"default"},"other_availability_zones":[],"network":{"name":"default"}}}'
