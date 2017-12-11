# update here: name of new tenant
variable "tenant" {
  default = "<YOUR TENANT NAME>"
}

# update here: third octet of subnet
variable "octet"
{
  default = "<THIRD OCTET OF SUBNET>"
}

variable "route53_zone" {
  default = "<ROUTE 53 ZONE ID>"
}

# update here: openstack keystone endpoint
# i.e. http://myopenstack.com:5000/v2.0
provider "openstack" {
  user_name = "admin"
  tenant_name = "${var.tenant}"
  password = ""
  # update here
  auth_url = "<KEYSTONE AUTH URL>"
}

# These security groups are wide open by default
resource "openstack_compute_secgroup_v2" "secgroup_1" {
  name = "${var.tenant}"
  description = "${var.tenant} Security Group"
  region = "RegionOne"

  rule {
    ip_protocol = "tcp"
    from_port = "1"
    to_port = "65535"
    cidr = "0.0.0.0/0"
  }

  rule {
    ip_protocol = "udp"
    from_port = "1"
    to_port = "65535"
    cidr = "0.0.0.0/0"
  }

  rule {
    ip_protocol = "icmp"
    from_port = "-1"
    to_port = "-1"
    cidr = "0.0.0.0/0"
  }
}

resource "openstack_networking_network_v2" "internal_net" {
  name = "${var.tenant}_net"
  region = "RegionOne"
  admin_state_up = "true"

}

resource "openstack_networking_subnet_v2" "internal_subnet" {
  region = "RegionOne"
  network_id = "${openstack_networking_network_v2.internal_net.id}"
  cidr = "192.168.${var.octet}.0/24"
  ip_version = 4
  allocation_pools = {
    start = "192.168.${var.octet}.2"
    end = "192.168.${var.octet}.254"
  }
  enable_dhcp = true
  dns_nameservers = [
    "<DNS SERVER 1>",
    "<DNS SERVER 2>"]

}

resource "openstack_networking_router_v2" "internal_router" {
  region = "RegionOne"
  name = "${var.tenant}-router"
  # update here: the network id of external subnet
  external_gateway = "<YOUR EXTERNAL SUBNET ID>"
  admin_state_up = "true"

}

output "internal_network_id"
{
  value = "${openstack_networking_network_v2.internal_net.id}"
}

output "ops_man_floating_ip"
{
  value = "${openstack_networking_floatingip_v2.floatip_1.address}"
}
output "ha_proxy_floating_ip"
{
  value = "${openstack_networking_floatingip_v2.floatip_2.address}"
}

resource "openstack_networking_router_interface_v2" "internal_interface" {
  region = "RegionOne"
  router_id = "${openstack_networking_router_v2.internal_router.id}"
  subnet_id = "${openstack_networking_subnet_v2.internal_subnet.id}"
}

resource "openstack_compute_keypair_v2" "keypair_01" {
  name = "${var.tenant}_key"
  public_key = "your pub key"
  region = "RegionOne"
}
resource "openstack_networking_floatingip_v2" "floatip_1" {
  region = "RegionOne"
  pool = "net04_ext"
}
resource "openstack_networking_floatingip_v2" "floatip_2" {
  region = "RegionOne"
  pool = "net04_ext"
}
resource "openstack_networking_floatingip_v2" "floatip_3" {
  region = "RegionOne"
  pool = "net04_ext"
}
resource "openstack_networking_floatingip_v2" "floatip_4" {
  region = "RegionOne"
  pool = "net04_ext"
}
resource "openstack_networking_floatingip_v2" "floatip_5" {
  region = "RegionOne"
  pool = "net04_ext"
}

# AWS creds to create DNS records in Route 53
provider "aws" {
  alias = "aws"
  access_key = "<YOUR AWS KEY>"
  secret_key = "<YOUR AWS SECRET>"
  region = "us-east-1"
}

# This creates pcf.<tenant_name>.<zone name>
resource "aws_route53_record" "pcf" {
  provider = "aws.aws"
  zone_id = "${var.route53_zone}"
  name = "pcf.${var.tenant}"
  type = "A"
  ttl = "60"
  records = [
    "${openstack_networking_floatingip_v2.floatip_1.address}"]
}

# This creates *.<tenant_name>.<zone name>
resource "aws_route53_record" "wildcard" {
  provider = "aws.aws"
  zone_id = "${var.route53_zone}"
  name = "*.${var.tenant}"
  type = "A"
  ttl = "60"
  records = [
    "${openstack_networking_floatingip_v2.floatip_2.address}"]
}
