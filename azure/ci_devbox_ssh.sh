#!/bin/bash
set -x

TOP=$PWD

help() {
  echo "USAGE:"
  echo "  $0 <env_dir> [command..]"
  exit 1
}
[ -n "$1" ] || help

cd $1
shift

chmod 0600 id_rsa_bosh

devboxpublicip=$(grep devbox_public_ip variables.yml | awk '{print $NF}' | tr -d "'")
devboxusername=$(grep devbox_username variables.yml | awk '{print $NF}' | tr -d "'")

ssh -i id_rsa_bosh -o StrictHostKeyChecking=no ${devboxusername}@${devboxpublicip} "$@"
