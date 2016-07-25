#!/bin/bash
set -x

TOP=$PWD
dir=$PWD

help() {
  echo "USAGE:"
  echo "  $0 [-d env_dir] destroy"
  echo "  $0 [-d env_dir] apply"
  echo "  $0 [-d env_dir] recreate"
}


# Generate the azure.tf
generate_config() {
  # Generate new devbox password if needed
  [ -f devbox_password.txt ] || date | md5sum | awk '{print $1;}' > devbox_password.txt
  git add devbox_password.txt

  # Generate SSH keypair
  [ -f id_rsa_bosh ] || ssh-keygen -t rsa -b 2048 -N "" -f id_rsa_bosh
  [ -f id_rsa_bosh.pub ] || ssh-keygen -y -f id_rsa_bosh > id_rsa_bosh.pub
  git add id_rsa_bosh id_rsa_bosh.pub

  # [Re-]generate the azure.tf
  DEVBOX_PASSWORD=$(cat devbox_password.txt)
  BOSH_SSH_PUBLIC_KEY=$(cat id_rsa_bosh.pub)

  cp $TOP/toolsmiths-shared-scripts/azure/azure.tf .
  sed -i -e "s/your-subscription-id/${AZURE_SUBSCRIPTION}/" \
    -e "s/your-client-id/${AZURE_CLIENT_ID}/" \
    -e "s/your-client-secret/${AZURE_CLIENT_SECRET}/" \
    -e "s/your-tenant-id/${AZURE_TENANT_ID}/" \
    -e "s/your-environment-name/${ENV_NAME}/" \
    -e "s/your-devbox-admin-user/${DEVBOX_USERNAME}/" \
    -e "s/your-devbox-admin-password/${DEVBOX_PASSWORD}/" \
    -e "s^public key string^${BOSH_SSH_PUBLIC_KEY}^" \
    azure.tf
  git add azure.tf
}

# Generate all the necessary configs, keys, etc for the environment
generate_details() {
  terraform output variables.yml > variables.yml

  sed -i -e "s^REPLACE_WITH_YOUR_BOSH_PUB_KEY^${BOSH_SSH_PUBLIC_KEY}^" \
    -e "s^REPLACE_WITH_YOUR_BOSH_PRIVATE_KEY_PATH^./id_rsa_bosh^" \
    -e "s^REPLACE_WITH_YOUR_SYSTEM_DOMAIN^${SYSTEM_DOMAIN}^" \
    variables.yml
  git add variables.yml

  export BUNDLE_GEMFILE=${TOP}/toolsmiths-shared-scripts/azure/Gemfile
  bundle
  bundle exec mustache variables.yml $TOP/toolsmiths-shared-scripts/azure/bosh.yml.mustache > bosh.yml
  git add bosh.yml
}

retry() {
  local try=1
  local tries=$1
  shift
  local cmd=$@

  while [ ${try} -le ${tries} ]
  do
    $cmd
    [ $? -eq 0 ] && return
    try=$(( $try + 1 ))
  done

  exit 1
}


while true
do
  case $1 in
    -d)
      dir=$2
      shift 2
      ;;
    *)
      break
      ;;
  esac
done


# Clone deployments-toolsmiths for update
git config --global user.email "${GIT_EMAIL}"
git config --global user.name "${GIT_NAME}"
git clone ${TOP}/azure_environments ${TOP}/environment
cd ${TOP}/environment/${dir}

[ -f terraform.tfstate ] && terraform refresh

if [ $1 = destroy ]
then
  if [ -f terraform.tfstate ]
  then
    echo "Destroying environment."
    retry 3 terraform destroy -force
  else
    echo "There does not seem to be anything to destroy."
    exit 0
  fi
elif [ $1 = apply ]
then
  echo "Applying changes to environment."
  generate_config
  retry 3 terraform apply
  generate_details
elif [ $1 = recreate ]
then
  echo "[Re-]creating environment."
  [ -f terraform.tfstate ] && terraform destroy -force
  generate_config
  retry 3 terraform apply
  generate_details
else
  help
  exit 1
fi

git add terraform.tfstate
git commit -m "Concourse Azure pipeline: terraform ${ENV_NAME}"
