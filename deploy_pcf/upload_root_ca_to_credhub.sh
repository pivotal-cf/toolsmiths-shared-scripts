#!/usr/bin/env bash

set -ex
PATH=$(pwd):$PATH
export PATH

urflag=false
prflag=false
erflag=false

NO_ARGS=0
E_OPTERROR=85

usage() { echo "Usage: cmd -u <OPSMAN_USERNAME> -p <OPSMAN_PASSWORD> -e <ENV_NAME>>" 1>&2; exit 1; }

if [ $# -eq "$NO_ARGS" ]
then
  usage
  exit $E_OPTERROR
fi

while getopts "u:p:e:" Option
do
  case $Option in
    u )
      urflag=true
      OPSMAN_USERNAME=$OPTARG
      ;;
    p )
      prflag=true
      OPSMAN_PASSWORD=$OPTARG
      ;;
    e )
      erflag=true
      ENV_NAME=$OPTARG
      ;;
    * ) usage ;;
  esac
done
shift $(($OPTIND - 1))

if ! $urflag || ! $prflag || ! $trflag || ! $erflag
then
    echo "Required option was not specified" >&2
    usage
fi

export OPSMAN_USERNAME
export OPSMAN_PASSWORD
export ENV_NAME
export TARGET="https://pcf.${ENV_NAME}.cf-app.com"

uaa_login="$(./om-linux -t $TARGET -u $OPSMAN_USERNAME -p $OPSMAN_PASSWORD -k curl -s -p /api/v0/deployed/director/credentials/uaa_login_client_credentials)"
uaa_admin="$(./om-linux -t $TARGET -u $OPSMAN_USERNAME -p $OPSMAN_PASSWORD -k curl -s -p /api/v0/deployed/director/credentials/uaa_admin_user_credentials)"

login_client_cred="$(echo "$uaa_login" | jq -r .credential.value.password)"
admin_user_name="$(echo "$uaa_admin" | jq -r .credential.value.identity)"
admin_user_password="$(echo "$uaa_admin" | jq -r .credential.value.password)"

set +e
which uaac > /dev/null
UAAC_EC=$?
set -e

if [ $UAAC_EC -ne 0 ]
then
  echo "uaac was not found on our PATH. Assuming we're on a 1.12 PCF and using the version in the tempest-web vendor directory."
  UAAC_DIR=/home/tempest-web/tempest/web/vendor/uaac
  UAAC="bundle exec vendor/bundle/ruby/2.3.0/bin/uaac"
else
  UAAC_DIR="."
  UAAC=uaac
fi

pushd $UAAC_DIR
$UAAC target 10.0.0.5:8443 --skip-ssl-validation
$UAAC token owner get login $admin_user_name --password=$admin_user_password --secret=$login_client_cred

if $UAAC clients | grep -q "name: credhub"
then
  echo "credhub client already exists"
else
  $UAAC client add --authorized_grant_types client_credentials --authorities credhub.read,credhub.write credhub --secret=credhub
fi
popd

credhub login -s 10.0.0.5:8844 --ca-cert=/var/tempest/workspaces/default/root_ca_certificate --client-name=credhub --client-secret=credhub
credhub set --type certificate --name /services/tls_ca \
--root <(jq -r .ca ./tls_ca.json) \
--certificate <(jq -r .certificate ./tls_ca.json) \
--private <(jq -r .private_key ./tls_ca.json)
