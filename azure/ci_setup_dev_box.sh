#!/bin/bash
set -x

TOP=$PWD

help() {
  echo "USAGE:"
  echo "  $0 <env_dir>"
  exit 1
}
[ -n "$1" ] || help

cd $1

chmod 0600 id_rsa_bosh

devboxpublicip=$(grep devbox_public_ip variables.yml | awk '{print $NF}' | tr -d "'")
devboxusername=$(grep devbox_username variables.yml | awk '{print $NF}' | tr -d "'")

scp -i id_rsa_bosh -o StrictHostKeyChecking=no $TOP/toolsmiths-shared-scripts/azure/set_up_dev_box.sh id_rsa_bosh bosh.yml ${devboxusername}@${devboxpublicip}:~/

ssh -i id_rsa_bosh -o StrictHostKeyChecking=no ${devboxusername}@${devboxpublicip} "sudo ~/set_up_dev_box.sh"
