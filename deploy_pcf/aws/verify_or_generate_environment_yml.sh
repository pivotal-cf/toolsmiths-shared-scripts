#! /bin/bash
set -x

AWS_SCRIPTS_DIR=$PWD/toolsmiths-shared-scripts/deploy_pcf/aws

help() {
  echo "USAGE:"
  echo "  $0 <path_to_environment_folder>"
}

generate_environment_yml() {
  pushd $AWS_SCRIPTS_DIR
    ./generate_enviroment_manifest.rb
    bundle
    bundle exec mustache variable.yml environment.yml.mustache > ${OLDPWD}/${AWS_ENVIRONMENT_NAME}.yml
  popd

  /usr/bin/env ruby <<-EORUBY
require 'yaml'
private_key = File.read(Dir.glob('id_rsa*').first)
env_yaml = File.read(Dir.glob("#{ENV.fetch('AWS_ENVIRONMENT_NAME')}.yml"))
yaml_string = YAML.dump({"ssh_private_key" => private_key})
yaml_string = yaml_string.gsub(/^---/,'')
yaml_string = yaml_string.gsub('ssh_private_key:', 'ssh_private_key: &ssh_private_key')
yaml_string =  yaml_string + "\n\n" + env_yaml
File.open("#{ENV.fetch('AWS_ENVIRONMENT_NAME')}.yml", 'w') { |f| f.puts yaml_string }
EORUBY

  echo "Generated ${AWS_ENVIRONMENT_NAME}.yml:"
  cat ${AWS_ENVIRONMENT_NAME}.yml
}

[ -z $1 ] || help

pushd $1
  [ -f $AWS_ENVIRONMENT_NAME.yml ] || generate_environment_yml
popd
