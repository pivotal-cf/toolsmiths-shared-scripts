#!/bin/bash
set -ex

AZURE_TEMPLATES=$PWD/toolsmiths-shared-scripts/azure

help() {
  echo "USAGE:"
  echo "  $0 <env_dir>"
  exit 1
}
[ -n "$1" ] || help

# Clone deployments-toolsmiths for update
git config --global user.email "${GIT_EMAIL}"
git config --global user.name "${GIT_NAME}"
git clone ${PWD}/azure_environments ${PWD}/environment
cd ${PWD}/environment/${1}

chmod 0600 id_rsa_bosh

devboxpublicip=$(grep devbox_public_ip variables.yml | awk '{print $NF}' | tr -d "'")
devboxusername=$(grep devbox_username variables.yml | awk '{print $NF}' | tr -d "'")
boshadminpassword=$(grep bosh_admin_password variables.yml | awk '{print $NF}' | tr -d "'")

ssh -i id_rsa_bosh -o StrictHostKeyChecking=no ${devboxusername}@${devboxpublicip} "bosh-init deploy ~/bosh.yml"

bosh_director_uuid=$(ssh -i id_rsa_bosh -o StrictHostKeyChecking=no ${devboxusername}@${devboxpublicip} "bosh -n -q target 10.0.0.4 && bosh -q login admin ${boshadminpassword} && bosh status | grep UUID | awk '{print \$2}'")
echo "bosh_director_uuid: $bosh_director_uuid" >> variables.yml

export BUNDLE_GEMFILE=${AZURE_TEMPLATES}/Gemfile
bundle
bundle exec mustache variables.yml ${AZURE_TEMPLATES}/mysql.yml.mustache > mysql.yml
bundle exec mustache variables.yml ${AZURE_TEMPLATES}/cf.yml.mustache > cf.yml
bundle exec mustache variables.yml ${AZURE_TEMPLATES}/diego.yml.mustache > diego.yml

${AZURE_TEMPLATES}/generate_cf_certs_and_keys.sh -n ./certs_and_keys $ENV_NAME
${AZURE_TEMPLATES}/insert_certs_and_keys_to_manifest.rb ./certs_and_keys/cf cf.yml

${AZURE_TEMPLATES}/generate_diego_certs_and_keys.sh -n ./certs_and_keys
${AZURE_TEMPLATES}/insert_certs_and_keys_to_manifest.rb ./certs_and_keys/diego diego.yml

sed -i -e "s/PASSWORDHERE/$boshadminpassword/" ${AZURE_TEMPLATES}/devbox_upload_bosh_releases.sh
chmod +x ${AZURE_TEMPLATES}/devbox_upload_bosh_releases.sh

scp -i id_rsa_bosh -o StrictHostKeyChecking=no ${AZURE_TEMPLATES}/devbox_upload_bosh_releases.sh mysql.yml cf.yml diego.yml ${devboxusername}@${devboxpublicip}:~/

ssh -i id_rsa_bosh -o StrictHostKeyChecking=no ${devboxusername}@${devboxpublicip} "~/devbox_upload_bosh_releases.sh"

git add .
git commit -m "Generates deployment ymls for ${ENV_NAME}"
