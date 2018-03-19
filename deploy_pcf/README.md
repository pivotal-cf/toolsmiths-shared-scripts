# Deploy PCF files
In this directory, we maintain files that we use to automate the deploy of PCFs to vSphere and GCP.

### Creating NS records in AWS Route53
- We use the `aws_dns_delegate_ns.json.erb` file to delegate NS records to AWS Route53

### Configuring BOSH director/OpsManager
- We use the following files to configure the BOSH director for GCP
  - `gcp_azs.json.erb`
  - `gcp_iaas.json.erb`
  - `gcp_network_assignment.json.erb`
  - `gcp_networks.json.erb`
- We use the following file to configure the VM settings for the OpsManager on vSphere
  - `opsman_settings.json.erb`
- We use the following files to configure the BOSH director for vSphere
  - `networks.json.erb`
  - `iaas.json.erb`

### Custom Terraform variables to be used with `terraforming-gcp`
- We use the `terraform.tfvar.erb` file to send custom variables to the `terraforming-gcp` scripts.

### Configuring ERT
- We have a `default` folder that houses the default configuration files for the different versions of ERT from 1.8 - 2.1
- Inside the folder, there are files for both vSphere and GCP. The vSphere files start with `ert-` where as the GCP files start with `gcp_cf_` 
- To override the defaults, create a folder for the version of ERT (eg. `2.1`) and put a copy of the file to be overridden inside it.
