############################## UPDATE BELOW #################################

# Follow instructions here to get credentials: http://bosh.io/docs/azure-resources.html
variable "azure_credentials" {
  default = {
    subscription_id = "your-subscription-id"
    client_id       = "your-client-id"
    client_secret   = "your-client-secret"
    tenant_id       = "your-tenant-id"
  }
}

variable "aws" {
  default = {
    access_key = "your-aws-access-key"
    secret_key = "your-aws-secret-key"
    route_53_zone = "your-route53-zone-id"
  }
}

variable "credentials" {
  default = {
    bosh_admin_password= "admin"
    ccdb = "admin"
    uaadb = "admin"
    cf_api = "admin"
    ccdb_encryption_key = "c1oudc0w"
    bulk_api_password = "c1oudc0w"
    ccadmin = "c1oudc0w"
    uaaadmin = "c1oudc0w"
    doppler_shared_secret = "c1oudc0w"
    nats = "c1oudc0w"
    router = "c1oudc0w"
    smoketests = "c1oudc0w"
    mysql_admin_password = "c1oudc0w"
    mysql_proxy_password = "c1oudc0w"
    uaa_admin_client_secret = "c1oudc0w"
    uaa_cc_client_secret = "c1oudc0w"
    uaa_cc_service_dashboard= "c1oudc0w"
    uaa_cc_routing = "c1oudc0w"
    uaa_cc_username_lookup = "c1oudc0w"
    uaa_datadog_firehoze_nozzle = "c1oudc0w"
    uaa_gorouter = "c1oudc0w"
    uaa_doppler = "c1oudc0w"
    uaa_identity = "c1oudc0w"
    uaa_login = "c1oudc0w"
    uaa_notifications = "c1oudc0w"
    uaa_portal = "c1oudc0w"
    uaa_ssh_proxy = "c1oudc0w"
    uaa_tcp_emitter = "c1oudc0w"
    uaa_tcp_router = "c1oudc0w"
    bbs_encryption = "c1oudc0w"
  }
}

variable "environment_name" {
  default = "your-environment-name"
}

variable "location" {
  default = "your-location"
}

variable "dns" {
    default = "168.63.129.16"
}

variable "address_space" {
  default = "10.0.0.0/16"
}

variable "subnets" {
  default = {
    bosh = "10.0.0.0/24"
    cloudfoundry =  "10.0.16.0/24"
    diego = "10.0.32.0/24"
    mysql = "10.0.48.0/24"
  }
}

variable "devbox_configs" {
  default = {
    private_ip = "10.0.0.100"
    username = "your-devbox-admin-user"
    password = "your-devbox-admin-password"
    publickey = "public key string"
  }
}

######################################################################################

provider "azurerm" {
  subscription_id = "${var.azure_credentials.subscription_id}"
  client_id       = "${var.azure_credentials.client_id}"
  client_secret   = "${var.azure_credentials.client_secret}"
  tenant_id       = "${var.azure_credentials.tenant_id}"
}

provider "aws" {
  alias = "aws"
  access_key = "${var.aws.access_key}"
  secret_key = "${var.aws.secret_key}"
  region = "us-east-1"
}


resource "azurerm_resource_group" "resourcegroup" {
    name     = "${var.environment_name}"
    location = "${var.location}"
}

resource "azurerm_storage_account" "storageaccount" {
    name = "${var.environment_name}sa"
    resource_group_name = "${azurerm_resource_group.resourcegroup.name}"

    location = "${var.location}"
    account_type = "Standard_LRS"
}

resource "azurerm_storage_container" "boshcontainer" {
    name = "bosh"
    resource_group_name = "${azurerm_resource_group.resourcegroup.name}"
    storage_account_name = "${azurerm_storage_account.storageaccount.name}"
    container_access_type = "private"
}

resource "azurerm_storage_container" "stemcellcontainer" {
    name = "stemcell"
    resource_group_name = "${azurerm_resource_group.resourcegroup.name}"
    storage_account_name = "${azurerm_storage_account.storageaccount.name}"
    container_access_type = "blob"
}

resource "azurerm_storage_table" "stemcelltable" {
    name = "stemcell"
    resource_group_name = "${azurerm_resource_group.resourcegroup.name}"
    storage_account_name = "${azurerm_storage_account.storageaccount.name}"
}

resource "azurerm_public_ip" "haproxypublicip" {
    name = "haproxypublicip"
    location = "${var.location}"
    resource_group_name = "${azurerm_resource_group.resourcegroup.name}"
    public_ip_address_allocation = "static"
}

resource "azurerm_public_ip" "loginhaproxypublicip" {
    name = "loginhaproxypublicip"
    location = "${var.location}"
    resource_group_name = "${azurerm_resource_group.resourcegroup.name}"
    public_ip_address_allocation = "static"
}

resource "azurerm_public_ip" "devboxpublicip" {
    name = "devboxpublicip"
    location = "${var.location}"
    resource_group_name = "${azurerm_resource_group.resourcegroup.name}"
    public_ip_address_allocation = "static"
}

resource "azurerm_virtual_network" "virtualnetwork" {
  name                = "${var.environment_name}vnetwork"
  resource_group_name = "${azurerm_resource_group.resourcegroup.name}"
  address_space       = ["${var.address_space}"]
  location            = "${var.location}"
}

resource "azurerm_subnet" "boshsubnet" {
    name = "boshnetwork"
    resource_group_name = "${azurerm_resource_group.resourcegroup.name}"
    virtual_network_name = "${azurerm_virtual_network.virtualnetwork.name}"
    address_prefix = "${var.subnets.bosh}"
}

resource "azurerm_subnet" "cloudfoundrysubnet" {
    name = "cloudfoundrynetwork"
    resource_group_name = "${azurerm_resource_group.resourcegroup.name}"
    virtual_network_name = "${azurerm_virtual_network.virtualnetwork.name}"
    address_prefix = "${var.subnets.cloudfoundry}"
}

resource "azurerm_subnet" "diegosubnet" {
    name = "diegonetwork"
    resource_group_name = "${azurerm_resource_group.resourcegroup.name}"
    virtual_network_name = "${azurerm_virtual_network.virtualnetwork.name}"
    address_prefix = "${var.subnets.diego}"
}

resource "azurerm_subnet" "mysqlsubnet" {
    name = "mysqlnetwork"
    resource_group_name = "${azurerm_resource_group.resourcegroup.name}"
    virtual_network_name = "${azurerm_virtual_network.virtualnetwork.name}"
    address_prefix = "${var.subnets.mysql}"
}

resource "azurerm_network_security_group" "boshsecuritygroup" {
    name = "boshsecuritygroup"
    location = "${var.location}"
    resource_group_name = "${azurerm_resource_group.resourcegroup.name}"

    security_rule {
        name = "internal-anything"
        priority = 100
        direction = "Inbound"
        access = "Allow"
        protocol = "*"
        source_port_range = "*"
        destination_port_range = "*"
        source_address_prefix = "VirtualNetwork"
        destination_address_prefix = "*"
    }

    security_rule {
        name = "ssh"
        priority = 200
        direction = "Inbound"
        access = "Allow"
        protocol = "Tcp"
        source_port_range = "*"
        destination_port_range = 22
        source_address_prefix = "Internet"
        destination_address_prefix = "*"
    }

    security_rule {
        name = "bosh-agent"
        priority = 201
        direction = "Inbound"
        access = "Allow"
        protocol = "Tcp"
        source_port_range = "*"
        destination_port_range = 6868
        source_address_prefix = "Internet"
        destination_address_prefix = "*"
    }

    security_rule {
        name = "bosh-director"
        priority = 202
        direction = "Inbound"
        access = "Allow"
        protocol = "Tcp"
        source_port_range = "*"
        destination_port_range = 25555
        source_address_prefix = "Internet"
        destination_address_prefix = "*"
    }

    security_rule {
        name = "dns"
        priority = 203
        direction = "Inbound"
        access = "Allow"
        protocol = "*"
        source_port_range = "*"
        destination_port_range = 53
        source_address_prefix = "Internet"
        destination_address_prefix = "*"
    }

    security_rule {
        name = "http"
        priority = 204
        direction = "Inbound"
        access = "Allow"
        protocol = "*"
        source_port_range = "*"
        destination_port_range = 80
        source_address_prefix = "Internet"
        destination_address_prefix = "*"
    }
    security_rule {
        name = "https"
        priority = 205
        direction = "Inbound"
        access = "Allow"
        protocol = "*"
        source_port_range = "*"
        destination_port_range = 443
        source_address_prefix = "Internet"
        destination_address_prefix = "*"
    }
    security_rule {
        name = "loggregator"
        priority = 206
        direction = "Inbound"
        access = "Allow"
        protocol = "*"
        source_port_range = "*"
        destination_port_range = 4443
        source_address_prefix = "Internet"
        destination_address_prefix = "*"
    }
}

resource "azurerm_network_interface" "devboxnic" {
    name = "devboxnic"
    location = "${var.location}"
    resource_group_name = "${azurerm_resource_group.resourcegroup.name}"

    ip_configuration {
        name = "devboxnic"
        subnet_id = "${azurerm_subnet.boshsubnet.id}"
        private_ip_address_allocation = "static"
        private_ip_address = "${var.devbox_configs.private_ip}"
        public_ip_address_id = "${azurerm_public_ip.devboxpublicip.id}"
    }
}

resource "azurerm_virtual_machine" "devboxvm" {
    name = "devboxvm"
    location = "${var.location}"
    resource_group_name = "${azurerm_resource_group.resourcegroup.name}"
    network_interface_ids = ["${azurerm_network_interface.devboxnic.id}"]
    vm_size = "Standard_D2_v2"

    storage_image_reference {
        publisher = "Canonical"
        offer = "UbuntuServer"
        sku = "14.04.4-LTS"
        version = "latest"
    }

    storage_os_disk {
        name = "devboxdisk"
        vhd_uri = "${azurerm_storage_account.storageaccount.primary_blob_endpoint}${azurerm_storage_container.boshcontainer.name}/devboxdisk.vhd"
        caching = "ReadWrite"
        create_option = "FromImage"
    }

    os_profile {
        computer_name = "${var.environment_name}jumpbox"
        admin_username = "${var.devbox_configs.username}"
        admin_password = "${var.devbox_configs.password}"
    }

    os_profile_linux_config {
        disable_password_authentication = true
        ssh_keys {
          path = "/home/${var.devbox_configs.username}/.ssh/authorized_keys"
          key_data = "${var.devbox_configs.publickey}"
        }
    }
}

resource "aws_route53_record" "jumpbox" {
  provider = "aws.aws"
  zone_id = "${var.aws.route_53_zone}"
  name = "jb.${var.environment_name}.azure"
  type = "A"
  ttl = "60"
  records = [
    "${azurerm_public_ip.devboxpublicip.ip_address}"]
}

resource "aws_route53_record" "wildcard" {
  provider = "aws.aws"
  zone_id = "${var.aws.route_53_zone}"
  name = "*.${var.environment_name}.azure"
  type = "A"
  ttl = "60"
  records = [
    "${azurerm_public_ip.haproxypublicip.ip_address}"]
}


output "devboxpublicip" {
  value = "${azurerm_public_ip.devboxpublicip.ip_address}"
}

output "variables.yml" {
  value = <<EOF

---
###  REPLACE BELOW ###
bosh_pub_key: 'REPLACE_WITH_YOUR_BOSH_PUB_KEY'
bosh_private_key_path: 'REPLACE_WITH_YOUR_BOSH_PRIVATE_KEY_PATH' # Path is relative to where your manifest will be on the dev box
system_domain: 'REPLACE_WITH_YOUR_SYSTEM_DOMAIN'


### VALUES GENERATED BY TERRAFORM ###

## Azure
subscription_id: '${var.azure_credentials.subscription_id}'
client_id: '${var.azure_credentials.client_id}'
client_secret: '${var.azure_credentials.client_secret}'
tenant_id: '${var.azure_credentials.tenant_id}'
vnet_name: '${azurerm_virtual_network.virtualnetwork.name}'
resource_group_name: '${azurerm_resource_group.resourcegroup.name}'
storage_account_name: '${azurerm_storage_account.storageaccount.name}'
devbox_username: '${var.devbox_configs.username}'
devbox_public_ip: '${azurerm_public_ip.devboxpublicip.ip_address}'
dns: '${var.dns}'

## Bosh
bosh_subnet_name: '${azurerm_subnet.boshsubnet.name}'
default_security_group: '${azurerm_network_security_group.boshsecuritygroup.name}'
bosh_admin_password: '${var.credentials.bosh_admin_password}'

## MySQL
mysql_subnet_name: '${azurerm_subnet.mysqlsubnet.name}'
mysql_subnet_range: '${var.subnets.mysql}'
mysql_reserved_range: '${cidrhost(var.subnets.mysql, 2)} - ${cidrhost(var.subnets.mysql, 3)}'
mysql_static_range: '${cidrhost(var.subnets.mysql, 4)} - ${cidrhost(var.subnets.mysql, 50)}'
mysql_gateway: '${cidrhost(var.subnets.mysql, 1)}'
mysql_ip: '${cidrhost(var.subnets.mysql, 4)}'
mysql_proxy_ip: '${cidrhost(var.subnets.mysql, 5)}'

## CF
cf_subnet_name: '${azurerm_subnet.cloudfoundrysubnet.name}'
cf_subnet_range: '${var.subnets.cloudfoundry}'
cf_reserved_range: '${cidrhost(var.subnets.cloudfoundry, 2)} - ${cidrhost(var.subnets.cloudfoundry, 3)}'
cf_static_range: '${cidrhost(var.subnets.cloudfoundry, 4)} - ${cidrhost(var.subnets.cloudfoundry, 50)}'
cf_gateway: '${cidrhost(var.subnets.cloudfoundry, 1)}'
consul_ip: '${cidrhost(var.subnets.cloudfoundry, 4)}'
haproxy_public_ip: "${azurerm_public_ip.haproxypublicip.ip_address}"
login_haproxy_public_ip: "${azurerm_public_ip.loginhaproxypublicip.ip_address}"
router_ip: '${cidrhost(var.subnets.cloudfoundry, 5)}'
nats_ip: '${cidrhost(var.subnets.cloudfoundry, 6)}'
nfs_ip: '${cidrhost(var.subnets.cloudfoundry, 7)}'
etcd_ip: '${cidrhost(var.subnets.cloudfoundry, 8)}'
postgres_ip: '${cidrhost(var.subnets.cloudfoundry, 9)}'
ccdb_password: '${var.credentials.ccdb}'
uaadb_password: '${var.credentials.uaadb}'
cf_api_password: '${var.credentials.cf_api}'
ccdb_encryption_key: '${var.credentials.ccdb_encryption_key}'
bulk_api_password: '${var.credentials.bulk_api_password}'
ccadmin_password: '${var.credentials.ccadmin}'
uaaadmin_password: '${var.credentials.uaaadmin}'
doppler_shared_secret: '${var.credentials.doppler_shared_secret}'
nats_password: '${var.credentials.nats}'
router_password: '${var.credentials.router}'
smoketests_password: '${var.credentials.smoketests}'
mysql_proxy_password: '${var.credentials.mysql_proxy_password}'
mysql_admin_password: '${var.credentials.mysql_admin_password}'
uaa_admin_client_secret: '${var.credentials.uaa_admin_client_secret}'
uaa_cc_client_secret: '${var.credentials.uaa_cc_client_secret}'
uaa_cc_service_dashboard_secret: '${var.credentials.uaa_cc_service_dashboard}'
uaa_cc_routing_secret: '${var.credentials.uaa_cc_routing}'
uaa_cc_username_lookup_secret: '${var.credentials.uaa_cc_username_lookup}'
uaa_datadog_firehoze_nozzle_secret: '${var.credentials.uaa_datadog_firehoze_nozzle}'
uaa_gorouter_secret: '${var.credentials.uaa_gorouter}'
uaa_doppler_secret: '${var.credentials.uaa_doppler}'
uaa_identity_secret: '${var.credentials.uaa_identity}'
uaa_login_secret: '${var.credentials.uaa_login}'
uaa_notifications_secret: '${var.credentials.uaa_notifications}'
uaa_portal_secret: '${var.credentials.uaa_portal}'
uaa_ssh_proxy_secret: '${var.credentials.uaa_ssh_proxy}'
uaa_tcp_emitter_secret: '${var.credentials.uaa_tcp_emitter}'
uaa_tcp_router_secret: '${var.credentials.uaa_tcp_router}'
bbs_encryption_passphrase: '${var.credentials.bbs_encryption}'

## Diego
diego_subnet_name: '${azurerm_subnet.diegosubnet.name}'
diego_subnet_range: '${var.subnets.diego}'
diego_reserved_range: '${cidrhost(var.subnets.diego, 2)} - ${cidrhost(var.subnets.diego, 3)}'
diego_static_range: '${cidrhost(var.subnets.diego, 4)} - ${cidrhost(var.subnets.diego, 50)}'
diego_gateway: '${cidrhost(var.subnets.diego, 1)}'
EOF
}
