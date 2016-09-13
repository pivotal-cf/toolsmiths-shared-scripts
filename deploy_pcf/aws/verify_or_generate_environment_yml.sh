#! /bin/bash
set -xe
OLDPWD=$PWD
AWS_SCRIPTS_DIR=$PWD/toolsmiths-shared-scripts/deploy_pcf/aws

help() {
  echo "USAGE:"
  echo "  $0 <path_to_environment_folder>"
}

generate_environment_yml() {
  pushd $AWS_SCRIPTS_DIR
    ./generate_enviroment_manifest.rb $OLDPWD
    bundle

    # PCF 1.6 does not have private_subnet2_id
    if cat variable.yml | grep private_subnet2_id; then
      bundle exec mustache variable.yml environment16.yml.mustache > ${OLDPWD}/${AWS_ENVIRONMENT_NAME}.yml
    else
      bundle exec mustache variable.yml environment.yml.mustache > ${OLDPWD}/${AWS_ENVIRONMENT_NAME}.yml
    fi
  popd
  echo "Generated ${AWS_ENVIRONMENT_NAME}.yml:"
  cat ${AWS_ENVIRONMENT_NAME}.yml
}

[ -z $1 ] || help

pushd $1
  generate_environment_yml
popd
