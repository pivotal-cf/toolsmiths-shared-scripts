#!/bin/bash
set -xe

exit_func() {
  exit_code=$?

  # Try to ensure that terraform state is preserved
  [ -f terraform.tfstate ] && git add terraform.tfstate
  if [ -n "$(git status -s | grep -v ^?)" ]
  then
    git commit -m "Concourse Azure pipeline: terraform ${1} ${ENV_NAME}"
  else
    echo "Skipping commit; no changes to tracked files."
  fi

  if [ ${exit_code} -eq 0 ]
  then
    exit
  else
    echo "[ERROR] Unexpected progam exit (code: $exit_code)"
  fi
}
trap exit_func EXIT

TOP=$PWD
EXIT_CODE=0

help() {
  echo "USAGE:"
  echo "  $0 [-d env_dir] destroy"
  echo "  $0 [-d env_dir] apply"
  echo "  $0 [-d env_dir] recreate"
}


die() {
  echo "[ERROR] $*"
  exit 1
}


# Generate the azure.tf
generate_config() {
  # Generate new devbox password if needed
  [ -f devbox_password.txt ] || date | md5sum | awk '{print $1;}' > devbox_password.txt
  git add devbox_password.txt

  # Generate SSH keypair
  [ -f id_rsa_bosh ] || ssh-keygen -t rsa -b 2048 -N "" -C "bosh key for ${ENV_NAME}" -f id_rsa_bosh
  [ -f id_rsa_bosh.pub ] || ssh-keygen -y -f id_rsa_bosh > id_rsa_bosh.pub
  git add id_rsa_bosh id_rsa_bosh.pub

  # [Re-]generate the azure.tf
  DEVBOX_PASSWORD=$(cat devbox_password.txt)
  BOSH_SSH_PUBLIC_KEY=$(cat id_rsa_bosh.pub)

  cp $TOP/toolsmiths-shared-scripts/azure/azure.tf .
  sed -i -e "s/your-location/${AZURE_REGION}/" \
    -e "s/your-subscription-id/${AZURE_SUBSCRIPTION}/" \
    -e "s/your-client-id/${AZURE_CLIENT_ID}/" \
    -e "s^your-client-secret^${AZURE_CLIENT_SECRET}^" \
    -e "s/your-tenant-id/${AZURE_TENANT_ID}/" \
    -e "s/your-aws-access-key/${AWS_SHARED_DNS_ACCESS_KEY}/" \
    -e "s^your-aws-secret-key^${AWS_SHARED_DNS_ACCESS_SECRET}^" \
    -e "s/your-route53-zone-id/${AWS_ROUTE53_ZONE_ID}/" \
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
  local cmd="$@"

  while [ ${try} -le ${tries} ]
  do
    if $cmd
    then
      return
    else
      try=$(( $try + 1 ))
    fi
  done

  return 1
}


dir=.
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


# Clone deployments-toolsmiths for state update.
git config --global user.email "${GIT_EMAIL}"
git config --global user.name "${GIT_NAME}"
git clone ${TOP}/azure_environments ${TOP}/environment
cd ${TOP}/environment

# Ensure that the environment state tracking directory is exists
if [ ! -d "${TOP}/environment/${dir}" ]
then
  mkdir -p "${TOP}/environment/${dir}" || die "cannot create state directory: ${TOP}/environment/${dir}"
  git add "${TOP}/environment/${dir}"
fi
cd ${TOP}/environment/${dir}
git status >/dev/null 2>&1 || die "Not in a git repository"

# Ensure that we have an upto date state file
if [ -f terraform.tfstate ]
then
  if terraform refresh
  then
    echo "Terraform refresh complete."
  else
    echo "Terraform refresh failed."
  fi
fi

if [ $1 = destroy ]
then
  if [ -f terraform.tfstate ]
  then
    echo "Destroying environment."
    if ! retry 3 terraform destroy -force
    then
      EXIT_CODE=1
    fi
  else
    echo "There does not seem to be anything to destroy."
  fi
elif [ $1 = apply ]
then
  echo "Applying changes to environment."
  generate_config
  if retry 3 terraform apply
  then
    generate_details
  else
    EXIT_CODE=1
  fi
elif [ $1 = recreate ]
then
  echo "[Re-]creating environment."
  [ -f terraform.tfstate ] && terraform destroy -force
  generate_config
  retry 3 terraform apply
  EXIT_CODE=$?
  generate_details
else
  help
  exit 1
fi

exit ${EXIT_CODE}
