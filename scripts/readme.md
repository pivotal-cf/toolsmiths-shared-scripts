For the internetless.sh script:

If you have set a default zone in gcloud, you will need to 

`gcloud config unset compute/zone`

Description:

<env>-internetless-management-egress
Ops Manager and Bosh Director granted access to all internet addresses

<env>-internetless-dns-egress
All VMs can use the 8.8.8.8 DNS server

<env>-internetless-intra-pcf-vm-egress-allow
All VMs can see each other’s private IP addresses & the loadbalancers

<env>-internetless-egress-deny
All other internet access is blocked. This is mainly for the ERT VMs and any other tiles that happen to be installed later
