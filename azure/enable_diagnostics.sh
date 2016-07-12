#!/bin/bash

# assumes you have a file called PrivateConfig.json with your storage account credentials (documentation here: https://azure.microsoft.com/en-us/documentation/articles/virtual-machines-linux-classic-diagnostic-extension/)

if [ "$#" -lt 2 ]
then
    echo "enables the diagnostics extension on all VMs in a resource group."
    echo "assumes you have a file called PrivateConfig.json with your storage account credentials (documentation here: https://azure.microsoft.com/en-us/documentation/articles/virtual-machines-linux-classic-diagnostic-extension/)"
    echo ""
    echo "command: ./enable_diagnostics.sh YOUR_RG_NAME PATH_TO_YOUR_PRIVATE_CONFIG_FILE"
    echo ""
    echo "The above command runs in parallel; if you want it to run serially, run it as:"
    echo ""
    echo "command ./enable_diagnostics.sh YOUR_RG_NAME PATH_TO_YOUR_PRIVATE_CONFIG_FILE serial"

    exit 0
fi


resource_group_name=$1
path_to_private_config_file=$2
serial=$3

azure config mode arm

vm_list=$(azure vm list $resource_group_name | grep $resource_group_name | awk '{print $3}')
for vm in $vm_list
do
  azure vm extension get -g $resource_group_name -m $vm | grep -q LinuxDiagnostic
  if [[ $? -eq 1 ]]; then
    if [ "$serial" = "serial" ]
    then
	azure vm extension set -g $resource_group_name -n LinuxDiagnostic -p Microsoft.OSTCExtensions -o 2.3 --private-config-path $path_to_private_config_file -m $vm
    else
	azure vm extension set -g $resource_group_name -n LinuxDiagnostic -p Microsoft.OSTCExtensions -o 2.3 --private-config-path $path_to_private_config_file -m $vm &
    fi
  else
    echo "LinuxDiagnostic has already been enabled on $vm"
  fi
done
