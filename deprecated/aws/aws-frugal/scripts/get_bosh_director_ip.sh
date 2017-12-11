#!/bin/bash

install_packages() {
  echo "Installing packages"
  gem install cf-uaac
  gem install aws-sdk-v1
  gem install httparty

  uname_result=$(uname)
  echo {} | jq .
  if [ $? -ne 0 ]; then
    case $uname_result in
      Linux) sudo apt-get install jq;;
      Darwin) brew install jq;;
      FreeBSD) pkg install jq;;
      *) >&2 echo "Unable to install jq" && exit 1;;
    esac
  fi
}
install_packages
if [ "$#" -ne 3 ]; then
  echo "Usage: ./get_bosh_director_ip.sh <ops-manager-hostname> <ops-manager-username> <ops-manager-password>"
  exit 1
fi

OPS_MANAGER_HOSTNAME=$1
OPS_MANAGER_USERNAME=$2
OPS_MANAGER_PASSWORD=$3
#echo "HOSTNAME:${OPS_MANAGER_HOSTNAME}, USERNAME:${OPS_MANAGER_USERNAME}, PASS:${OPS_MANAGER_PASSWORD}"
uaac --no-trace --no-debug target "https://${OPS_MANAGER_HOSTNAME}/uaa" --skip-ssl-validation
uaac token owner get opsman ${OPS_MANAGER_USERNAME} -s '' -p ${OPS_MANAGER_PASSWORD}
PCF_AUTH_HEADER="Authorization: Bearer $(uaac context | grep access_token | awk '{ print $2 }')"
mkdir bosh_data
curl -s -k "https://${OPS_MANAGER_HOSTNAME}/api/v0/staged/director/manifest" -k -H "$(echo $PCF_AUTH_HEADER)" > bosh_data/BOSH_DIRECTOR_DATA.json
cat bosh_data/BOSH_DIRECTOR_DATA.json | jq -r .manifest.jobs[0].properties.director.address > bosh_data/BOSH_DIRECTOR_DATA.txt
cat bosh_data/BOSH_DIRECTOR_DATA.json | jq -r .manifest.jobs[0].properties.uaa.scim.users[0] >> bosh_data/BOSH_DIRECTOR_DATA.txt
