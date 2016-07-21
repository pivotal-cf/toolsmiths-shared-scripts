# Deploying CF to Azure
---

This repo is a collection of tooling to deploy CF on Azure. It is a set of terraform, shell, and ruby scripts to get your CF up and running. Follow the README on how to set up a working CF cluster on your Azure environment. The end result will give you:

* A Dev Box VM in your Azure resource group
* A MySQL cluster used as an external database for cloud controller
* A working CF deployment with Diego

###Table of Contents
1. [Preqrequisites](#prerequisites)
2. [Bootstrapping your Azure environment](#bootstrapping-your-azure-environment)
3. [Setting up your devbox](#setting-up-your-devbox)
4. [Deploying a BOSH director](#deploying-a-bosh-director)
5. [Deploying CF](#deploying-cf)
   1. [MySQL](#mysql)
   1. [CF](#cf)
   1. [Diego](#diego)


---
## Prerequisites

### Set Quotas

You will need an Azure account with the correct quotas enabled. To do this, you should open a support ticket after logging into portal.azure.com

1. In portal.azure.com in the upper right hand corner, click the ?
2. Click on 'New support request'
3. Issue type: Quota
4. Cores per subscription
5. Severity: Recommended B or higher
5. Deployment model: Resource Manager
6. Region: the region you want to use!
7. New quota: 202
You can add additional people to your e-mail, but it's to just send it to your team.

If the Toolsmiths are deploying CF for you, add the 5 Toolsmith Pivots as an owners of your account in the Azure portal, and leave us a nice message in Slack.

### Generate working directory

We recommend creating a working directory for your specific Azure environment. In our readme, we will be using `~/workspace/<ENV>/`

```
mkdir ~/workspace/<ENV>
```

---

## Bootstrapping your Azure environment

### Prerequisites

* You must have terraform 0.6.16+ to use the azurerm resource tooling with this terraform script
* You must have a public ssh key to provision the devbox

### Summary

The terraform script will set up your Azure environment according to the [BOSH CPI Documentation](https://github.com/cloudfoundry-incubator/bosh-azure-cpi-release/blob/master/docs/get-started/manually/deploy-bosh-manually.md).

* create azure resource group
* create a default storage account
* create the 'bosh' and 'stemcell' storage containers
* create a public IP to use for your CF deployment
* creates a virtual network for your environment with 3 subnets (bosh, mysql, cloudfoundry, diego)
* sets up the network security groups:
  * For the BOSH security group:
    * anything within the virtual network
    * ssh (22)
    * bosh-agent (6868)
    * bosh-director (25555)
    * dns (53)
    * http (80)
    * https (443)
    * loggregator (4443)
* create an Ubuntu vm for your use as a dev box to deploy bosh and cf

### Running the terraform script

We recommend you copy the terraform script to your working directory.

```
cp azure.tf ~/workspace/<ENV>/
```

Update the script at the top, underneath the 'UPDATE BELOW' header paying head to the following guidelines:

* environment name: should be between 1 and 22 characters, all of which are lowercase or numbers; this is due to naming limits of the storage account which will be created as *environment_name+sa*.
* devbox username: be advised that there are some reserved usernames which are disallowed, such as "admin".
* devbox password: must contain at least one from each set: uppercase letter, lowercase letter, special character and number.

Inside the terraform script's directory, run `terraform plan` to view the changes that will be made.

Once you are happy with the changes, execute the terraform script by running `terraform apply`.


### Creating the storage table

We currently need to manually create the storage table (see: https://github.com/hashicorp/terraform/issues/7257).**Update:** This feature should be included in the terraform 0.7 release.

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

azure storage table create --account-name $storage_account_name --account-key $storage_account_key --table stemcell
```

---

## Setting up your devbox

Once the terraform script has completed, you will want to install basic tools such as ruby, bosh cli and bosh-init.

In your environment directory, run the following:

```
cd ~/workspace/<ENV>

ssh-add <your_dev_box_private_key>

devboxpublicip=$(terraform output devboxpublicip)
scp ~/workspace/toolsmiths-shared-scripts/azure/set_up_dev_box.sh <devbox_username>@${devboxpublicip}:/tmp

ssh <devbox_username>@${devboxpublicip} "sudo /tmp/set_up_dev_box.sh"

scp ~/workspace/<BOSHPrivateKey> <devbox_username>@${devboxpublicip}:/tmp
```
---

Then set up your system domain. We like to use the Route53 service from AWS for cf-app.com

---

## Deploying a BOSH director

### Prerequisites

Set the variables required to generate your deployment manifest:

```
# From the terraform working dir

terraform output variables.yml > ~/workspace/<ENV>/variables.yml



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

* **bosh_pub_key**: This is your public key for bosh
* **bosh_private_key_path**: This is the full or relative path to where you placed the bosh private key on the dev box
* **system_domain**: This is the wildcard A record that points to your HA proxy. *Be sure to create this record beforehand*



### Generating the director manifest

We use the `mustache` command to generate our bosh director manifest:

```
cd ~/workspace/toolsmiths-shared-scripts/azure
bundle
bundle exec mustache ~/workspace/<ENV>/variables.yml bosh.yml.mustache > ~/workspace/<ENV>/bosh.yml
```

### Deploying the bosh director from your dev box

* Ensure your bosh private key is on the dev box in the path that is specified in the manifest
* Feel free to update the release versions

```
scp bosh.yml <devbox_username>@<devboxpublicip>:

ssh <devbox_username>@<devboxpublicip> "bosh-init deploy bosh.yml"
```

**Make sure you check in your deployment manifests to your teams repo!**

---

## Deploying CF

We will be deploying mysql, cf and diego as three separate deployments.

### Prerequisites

We need to know the bosh director UUID when deploying CF.

In the terraform working directory:

```
cd ~/workspace/toolsmiths-shared-scripts/azure
mustache ~/workspace/<ENV>/variables.yml add_bosh_director_uuid.sh.mustache > ~/workspace/<ENV>/add_bosh_director_uuid.sh
chmod +x ~/workspace/<ENV>/add_bosh_director_uuid.sh
~/workspace/<ENV>/add_bosh_director_uuid.sh >> ~/workspace/<ENV>/variables.yml
```

We also need to upload the releases and stemcell we wish to use:

```
ssh <devboxuser>@<devboxpublicip>

bosh target 10.0.0.4
bosh login admin <password>

# These are the versions we have tested with

bosh upload release https://bosh.io/d/github.com/cloudfoundry/cf-mysql-release?v=24
bosh upload release https://bosh.io/d/github.com/cloudfoundry/cf-release?v=231
bosh upload release https://bosh.io/d/github.com/cloudfoundry-incubator/garden-linux-release?v=0.333.0
bosh upload release https://bosh.io/d/github.com/cloudfoundry-incubator/etcd-release?v=36
bosh upload release https://bosh.io/d/github.com/cloudfoundry-incubator/diego-release?v=0.1454.0
bosh upload stemcell https://bosh.io/d/stemcells/bosh-azure-hyperv-ubuntu-trusty-go_agent?v=3232.11
```

## MySQL

The mysql deployment is used as a standalone mysql cluster to be used as an external database by the cloud controller.

### Generating your Mysql manifest

Generate your mysql manifest using mustache:

```
mustache ~/workspace/<ENV>/variables.yml mysql.yml.mustache > ~/workspace/<ENV>/mysql.yml
```

SCP your the mysql deployment manifest onto the devbox

```
scp ~/workspace/<ENV>/mysql.yml <devbox_username>@<devboxpublicip>:
```

### Deploying your Mysql cluster

Set your deployment manifest and deploy your mysql cluster from the devbox:

```
ssh <devbox_username>@<devboxpublicip> "bosh deployment mysql.yml && bosh deploy"
``` 

## CF

This is the CF release without any DEA cells. We will be using Diego for our CF cluster.

### Generating your CF manifest

Generate your cf manifest using mustache:

```
bundle exec mustache ~/workspace/<ENV>/variables.yml cf.yml.mustache > ~/workspace/<ENV>/cf.yml
```

Generate keys and certs if necessary

```
./generate_cf_certs_and_keys.sh ~/workspace/<ENV>/cert_and_keys
```

This will create the following keys and certs in the directory:

```
~/workspace/<ENV>/cert_and_keys/
└── cf
    ├── ha_proxy_ssl_pem
    ├── jwt_signing_key
    ├── jwt_verification_key
    └── loginha_proxy_ssl_pem
```

Insert the certificates and keys into the deployment manifest:

```
./insert_certs_and_keys_to_manifest.rb ~/workspace/<ENV>/cert_and_keys/cf ~/workspace/<ENV>/cf.yml
```

SCP the cf manifest to your dev box vm

```
scp ~/workspace/<ENV>/cf.yml <devbox_username>@<devboxpublicip>:
```

### Deploy your CF cluster

```
ssh <devbox_username>@<devboxpublicip> "bosh deployment cf.yml && bosh deploy"
```

## Diego

Generate your diego manifest using mustache:

```
bundle exec mustache ~/workspace/<ENV>/variables.yml diego.yml.mustache > ~/workspace/<ENV>/diego.yml
```

Generate keys and certs if necessary

```
./generate_diego_certs_and_keys.sh ~/workspace/<ENV>/cert_and_keys
```

This will create the following keys and certs in the directory:

```
~/workspace/<ENV>/cert_and_keys/
└── diego
    ├── bbs_client_cert
    ├── bbs_client_key
    ├── bbs_server_cert
    ├── bbs_server_key
    ├── diego_ca_cert
    ├── diego_ca_key
    ├── etcd_client_cert
    ├── etcd_client_key
    ├── etcd_peers_cert
    ├── etcd_peers_key
    ├── etcd_server_cert
    ├── etcd_server_key
    ├── etcdpeers_ca_cert
    ├── etcdpeers_ca_key
    └── ssh_proxy_key
```

Insert the certificates and keys into the deployment manifest:

```
./insert_certs_and_keys_to_manifest.rb ~/workspace/<ENV>/cert_and_keys/diego ~/workspace/<ENV>/diego.yml
```

SCP the cf manifest to your dev box vm

```
scp ~/workspace/<ENV>/diego.yml <devbox_username>@<devboxpublicip>:
```

### Deploy your Diego cluster

```
ssh <devbox_username>@<devboxpublicip> "bosh deployment diego.yml && bosh deploy"
```
