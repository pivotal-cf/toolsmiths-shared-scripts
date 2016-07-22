#!/bin/bash
set -x

bosh target 10.0.0.4
bosh login admin PASSWORDHERE

bosh upload release https://bosh.io/d/github.com/cloudfoundry/cf-mysql-release?v=24
bosh upload release https://bosh.io/d/github.com/cloudfoundry/cf-release?v=231
bosh upload release https://bosh.io/d/github.com/cloudfoundry-incubator/garden-linux-release?v=0.333.0
bosh upload release https://bosh.io/d/github.com/cloudfoundry-incubator/etcd-release?v=36
bosh upload release https://bosh.io/d/github.com/cloudfoundry-incubator/diego-release?v=0.1454.0
bosh upload stemcell https://bosh.io/d/stemcells/bosh-azure-hyperv-ubuntu-trusty-go_agent?v=3232.11
