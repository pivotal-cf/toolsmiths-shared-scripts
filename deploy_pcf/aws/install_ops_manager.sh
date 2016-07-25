#! /bin/bash

set -xe
git clone ./environment-ymls output/environment-ymls
export ENV_DIRECTORY=$PWD/output/environment-ymls/$ENV_FOLDER
OLDPWD=$PWD

function install_ops_manager() {
  pushd p-runtime
  bundle install
  bundle exec rake opsmgr:install[${AWS_ENVIRONMENT_NAME},${OLDPWD}/ami/amis.yml]
  popd

}

function add_public_ip() {
  PUBLIC_IP=$(aws ec2 describe-instances --filter "Name=tag:Name,Values=ops-manager-${AWS_ENVIRONMENT_NAME}" | jq -r .Reservations[].Instances[].NetworkInterfaces[].Association.PublicIp)
  sed -i "s/ops_manager_public_ip_willbereplaced/${PUBLIC_IP}/" $ENV_DIRECTORY/*.yml
  echo "Public IP added in manifest"
}

function commit_changes(){
  pushd output/environment-ymls
  git config --global user.email ${GIT_EMAIL}
  git config --global user.name ${GIT_USER}
  git add .
  git commit -m"Adding ops_manager public_ip to ${AWS_ENVIRONMENT_NAME} manifest"
  popd
}

install_ops_manager
add_public_ip
commit_changes
