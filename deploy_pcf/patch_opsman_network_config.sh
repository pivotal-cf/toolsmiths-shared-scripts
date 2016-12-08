#!/bin/bash


uaac target "https://pcf.${ENV_NAME}.cf-app.com/uaa" --skip-ssl-validation
echo "Getting token ..."
uaac token owner get opsman $OPSMAN_USERNAME -s '' -p $OPSMAN_PASSWORD
UAA_ACCESS_TOKEN=$(uaac context | grep access_token | xargs | cut -f2 -d" ")
echo "Token: ${UAA_ACCESS_TOKEN}"
BOSH_GUID=$(curl -k "https://pcf.undercity.cf-app.com/api/v0/staged/products" -X GET -H "Authorization: Bearer $UAA_ACCESS_TOKEN" | jq '.[] | select(.installation_name=="p-bosh")' | jq -r .guid)
echo "BOSH_GUID: ${BOSH_GUID}"
curl -v -k "https://pcf.${ENV_NAME}.cf-app.com/api/v0/staged/products/${BOSH_GUID}/networks_and_azs" \
    -X PUT \
    -H "Authorization: Bearer ${UAA_ACCESS_TOKEN}" \
    -H "Content-type: application/json" \
    --data '{"networks_and_azs":{"singleton_availability_zone":{"name":"default"},"other_availability_zones":[{"name: "default"}],"network":{"name":"default"}}}'
