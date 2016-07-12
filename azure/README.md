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

Update the terraform script at the top, underneath the 'UPDATE BELOW' header paying head to the following guidelines:

* environment name: should be between 1 and 22 characters, all of which are lowercase or numbers; this is due to naming limits of the storage account which will be created as *environment_name+sa*.
* devbox username: be advised that there are some reserved usernames which are disallowed, such as "admin".
* devbox password: must contain at least one from each set: uppercase letter, lowercase letter, special character and number.

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

We currently need to manually create the storage table (see: https://github.com/hashicorp/terraform/issues/7257). **Update:** This feature should be included in the terraform 0.7 release.

Run the following commands:

```
azure login # Follow the instructions to login
```

Ensure you have the 'arm' mode configured with your azure CLI:

```
azure config mode arm
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

# Deploying a BOSH director in your Azure environment

## Prerequisites

Set the variables required to generate your deployment manifest:

```
# From the terraform working dir

terraform output variables.yml > variables.yml



# it should look like the following:

---
vnet_name: 'sample'
subnet_name: 'sample'
subscription_id: 'sample'
client_id: 'sample'
client_secret: 'sample'
tenant_id: 'sample'
resource_group_name: 'sample'
storage_account_name: 'sample'
default_security_group: 'sample'
bosh_pub_key: 'REPLACE_WITH_YOUR_BOSH_PUB_KEY'
bosh_private_key_path: 'REPLACE_WITH_YOUR_BOSH_PRIVATE_KEY_PATH' # Path is relative to where your manifest will be on the dev box
...

```

**Be sure to set your the variables that are tagged with 'REPLACE'**



## Generating the director manifest

We use the `mustache` command to generate our bosh director manifest:

```
bundle
bundle exec mustache variables.yml bosh_template.yml.mustache > bosh.yml
```

## Deploying the bosh director from your dev box

* Ensure your bosh private key is on the dev box in the path that is specified in the manifest
* Feel free to update the release versions

```
scp bosh.yml <devbox_username>@<devboxpublicip>:~/

ssh <devbox_username>@<devboxpublicip>
bosh-init deploy bosh.yml
```

**Make sure you check in your deployment manifests!**

# Deploying CF in your Azure environment

## Prerequisites

We need to know the bosh director UUID when deploying CF.

In the terraform working directory:

```
mustache variables.yml add_bosh_director_uuid.sh.mustache > add_bosh_director_uuid.sh
chmod +x add_bosh_director_uuid.sh
./add_bosh_director_uuid.sh >> variables.yml
```

We also need to upload the release and stemcell we wish to use:

```
bosh upload release https://bosh.io/d/github.com/cloudfoundry/cf-release?v=231
bosh upload release https://bosh.io/d/github.com/cloudfoundry-incubator/garden-linux-release?v=0.333.0
bosh upload release https://bosh.io/d/github.com/cloudfoundry-incubator/etcd-release?v=36
bosh upload release https://bosh.io/d/github.com/cloudfoundry-incubator/diego-release?v=0.1454.0
bosh upload stemcell https://bosh.io/d/stemcells/bosh-azure-hyperv-ubuntu-trusty-go_agent?v=3232.11
```

## Generating your CF manifest

Generate your cf manifest using mustache:

```
bundle exec mustache variables.yml cf_template.yml > cf.yml
```

Put your wildcard SSL cert and key in the cf.yml (search for 'REPLACE_WITH_SSL_CERT_AND_KEY'). If you are just generating a new one, you can use the following command:

```
openssl genrsa -out ~/haproxy.key 2048 &&
  echo -e "\n\n\n\n\n\n\n" | openssl req -new -x509 -days 365 -key ~/haproxy.key -out ~/haproxy_cert.pem &&
  cat ~/haproxy_cert.pem ~/haproxy.key > ~/haproxy.ssl &&
  awk -vr="$(sed -e '2,$s/^/        /' ~/haproxy.ssl)" '(sub("REPLACE_WITH_SSL_CERT_AND_KEY.*$",r))1' cf.yml > tmp &&
  mv -f tmp cf.yml
```

## Deploying CF

```
scp cf.yml <devbox_username>@<devboxpublicip>:~/

ssh <devbox_username>@<devboxpublicip>
bosh target <YOUR BOSH DIRECTOR>
bosh deployment cf.yml
bosh deploy
```


## Enable Diagnostics in all VM

Enables the diagnostics extension on all VMs in a resource group.
assumes you have a file called PrivateConfig.json with your storage account credentials ([documentation here](https://azure.microsoft.com/en-us/documentation/articles/virtual-machines-linux-classic-diagnostic-extension/))

```
./enable_diagnostics.sh YOUR_RG_NAME PATH_TO_YOUR_PRIVATE_CONFIG_FILE
```

The above command runs in parallel; if you want it to run serially, run it as:

```
./enable_diagnostics.sh YOUR_RG_NAME PATH_TO_YOUR_PRIVATE_CONFIG_FILE serial
```