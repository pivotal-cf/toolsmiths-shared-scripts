variable "aws_access_key" {}
variable "aws_access_secret" {}
variable "aws_hosted_zone_id" {}

provider "aws" {
  alias = "aws"
  access_key = "${var.aws_access_key}"
  secret_key = "${var.aws_access_secret}"
  region = "us-east-1"
}

resource "aws_route53_record" "pcf" {
  provider = "aws.aws"
  zone_id = "${var.aws_hosted_zone_id}"
  name = "pcf.${var.project}"
  type = "A"
  ttl = "60"
  records = [
    "${openstack_networking_floatingip_v2.ops_manager.address}"]
}

resource "aws_route53_record" "wildcard" {
  provider = "aws.aws"
  zone_id = "${var.aws_hosted_zone_id}"
  name = "*.${var.project}"
  type = "A"
  ttl = "60"
  records = [
    "${openstack_networking_floatingip_v2.ha_proxy.address}"]
}
