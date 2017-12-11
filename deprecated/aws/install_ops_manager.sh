#! /bin/bash

set -xe
git clone ./environment-ymls output/environment-ymls
export ENV_DIRECTORY=$PWD/output/environment-ymls/$ENV_FOLDER
OLDPWD=$PWD

function install_ops_manager() {
  pushd p-runtime
  bundle install
  bundle exec rake opsmgr:install[${AWS_ENVIRONMENT_NAME},${OLDPWD}/ami/amis.yml]
  popd

}

function add_public_ip() {
  opsman_public_ip=$(aws ec2 describe-instances --filter "Name=tag:Name,Values=ops-manager-${AWS_ENVIRONMENT_NAME}" | jq -r .Reservations[].Instances[].NetworkInterfaces[].Association.PublicIp)
  pcf_elb_dns_name=$(aws cloudformation describe-stacks --stack-name ${AWS_ENVIRONMENT_NAME} --output text | grep PcfElbDnsName | awk '{print $3}')
  export AWS_ACCESS_KEY_ID=${AWS_ROUTE53_ACCESS_KEY_ID}
  export AWS_SECRET_ACCESS_KEY=${AWS_ROUTE53_SECRET_ACCESS_KEY}

  JSON="
  {
    \"Comment\": \"$AWS_ENVIRONMENT_NAME AWS environment\",
    \"Changes\": [
      {
        \"Action\": \"CREATE\",
        \"ResourceRecordSet\": {
          \"Name\": \"*.${AWS_SYSTEM_DOMAIN}\",
          \"Type\": \"CNAME\",
          \"TTL\": 300,
          \"ResourceRecords\": [
            {
              \"Value\": \"$pcf_elb_dns_name\"
            }
          ]
        }
      },
      {
        \"Action\": \"CREATE\",
        \"ResourceRecordSet\": {
          \"Name\": \"${OPS_MANAGER_FQDN}\",
          \"Type\": \"A\",
          \"TTL\": 300,
          \"ResourceRecords\": [
            {
              \"Value\": \"$opsman_public_ip\"
            }
          ]
        }
      }
    ]
  }"

  echo $JSON | jq .

  aws route53 change-resource-record-sets --hosted-zone-id ${AWS_ROUTE53_HOSTED_ZONE_ID} --change-batch "$JSON"

  sed -i "s/ops_manager_public_url_willbereplaced/\"https:\/\/${OPS_MANAGER_FQDN}\"/" $ENV_DIRECTORY/*.yml
  echo "DNS records for ${OPS_MANAGER_FQDN} and *.${AWS_SYSTEM_DOMAIN} have been created and added in manifest"
}

function commit_changes(){
  pushd output/environment-ymls
  git config --global user.email ${GIT_EMAIL}
  git config --global user.name ${GIT_USER}
  git add .
  git commit -m"Adding ops_manager public_ip to ${AWS_ENVIRONMENT_NAME} manifest"
  popd
}

install_ops_manager
add_public_ip
commit_changes
