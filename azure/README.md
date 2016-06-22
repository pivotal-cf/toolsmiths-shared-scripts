# Bootstrapping your Azure environment

### Prerequisites

* You must have terraform 0.6.16+ to use the azurerm resource tooling with this terraform script
* You must have a public ssh key to provision the devbox

### Summary

The terraform script will set up your Azure environment according to the [BOSH CPI Documentation](https://github.com/cloudfoundry-incubator/bosh-azure-cpi-release/blob/master/docs/get-started/manually/deploy-bosh-manually.md).

* create azure resource group
* create a default storage account
* create the 'bosh' and 'stemcell' storage containers
* create a public IP to use for your CF deployment
* creates a virtual network for your environment with 3 subnets (bosh, cloudfoundry, diego)
* sets up the network security groups:
  * For the BOSH subnet:
    * ssh (22)
    * bosh-agent (6868)
    * bosh-director (25555)
    * dns (53)
  * For the Cloudfoundry subnet:
    * cf-https (443)
    * cf-log (4443)
* create an Ubuntu vm for your use as a dev box to deploy bosh and cf

### Running the terraform script

Update the terraform script at the top, underneath the 'UPDATE BELOW' header.
Inside the terraform script's directory, run `terraform plan` to view the changes that will be made.

Once you are happy with the changes, execute the terraform script by running `terraform apply`.

### Setting up your devbox

Once the terraform script has completed, you will want to install basic tools such as ruby, bosh cli and bosh-init.

In this directory, run the following:

```
ssh-add <your_dev_box_private_key>

scp set_up_dev_box.sh <devbox_username>@<devboxpublicip>:/tmp

ssh <devbox_username>@<devboxpublicip>
  sudo su
  /tmp/set_up_dev_box.sh
exit

```

### Notes

We currently need to manually create the storage table (see: https://github.com/hashicorp/terraform/issues/7257):

Run the following commands:

```
azure login # Follow the instructions to login
```

To fetch your storage account key, run the following commands and copy the 'Primary' key.

```
resource_group_name=<your-env-name>
storage_account_name=<your-env-name>sa

azure storage account keys list --resource-group $resource_group_name $storage_account_name
```
You can also get the storage account key via the Azure Portal

Sample Output:

```
info:    Executing command storage account keys list
Resource group name: bosh-res-group
+ Getting storage account keys
data:    Primary: XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX
data:    Secondary: XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX
info:    storage account keys list command OK
```

Create your storage table:

```
storage_account_key=<your-storage-account-key>
storage_account_name=<your-env-name>sa
azure storage table create --account-name $storage_account_name --account-key $storage_account_key --table stemcell
```

