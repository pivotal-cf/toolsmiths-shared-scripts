#!/usr/bin/env bash

set -e
PATH=$(pwd):$PATH
export PATH

urflag=false
prflag=false
trflag=false
grflag=false
vrflag=false
erflag=false
irflag=false

NO_ARGS=0
E_OPTERROR=85

usage() { echo "Usage: cmd -u <OPSMAN_USERNAME> -p <OPSMAN_PASSWORD> -t <PIVNET_TOKEN> -g <GLOB_FILTER> -v <PRODUCT_VERSION> -e <ENV_NAME> -i <IAAS>" 1>&2; exit 1; }

if [ $# -eq "$NO_ARGS" ]
then
  usage
  exit $E_OPTERROR
fi

while getopts "u:p:t:g:v:e:i:" Option
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
    t )
      trflag=true
      PIVNET_TOKEN=$OPTARG
      ;;
    g )
      grflag=true
      GLOB_FILTER=$OPTARG
      ;;
    v )
      vrflag=true
      PRODUCT_VERSION=$OPTARG
      ;;
    e )
      erflag=true
      ENV_NAME=$OPTARG
      ;;
    i )
      irflag=true
      IAAS=$OPTARG
      ;;
    * ) usage ;;
  esac
done
shift $(($OPTIND - 1))

if ! $urflag || ! $prflag || ! $trflag || ! $grflag || ! $vrflag || ! $erflag || ! $irflag
then
    echo "Required option was not specified" >&2
    usage
fi

export OPSMAN_USERNAME
export OPSMAN_PASSWORD
export ENV_NAME
export PIVNET_TOKEN
export PRODUCT_VERSION
export GLOB_FILTER
export IAAS

echo
echo "=============================================================================================="
echo " Examining IAAS value ..."
echo "=============================================================================================="
stemcell_glob=""
case $IAAS in
  "gcp")
    stemcell_glob="*google*";;
  "vsphere")
    stemcell_glob="*vsphere*";;
  *)
    echo "Unhandled IAAS value: '${IAAS}'"
    exit 1;;
esac

echo
echo "=============================================================================================="
echo " Downloading required tooling ..."
echo "=============================================================================================="
curl -L "https://github.com/pivotal-cf/om/releases/download/0.47.0/om-linux" > om-linux \
  && chmod +x om-linux
curl -L "https://github.com/pivotal-cf/pivnet-cli/releases/download/v0.0.55/pivnet-linux-amd64-0.0.55" > pivnet-cli \
  && chmod +x pivnet-cli
curl -L  "https://github.com/mikefarah/yq/releases/download/2.2.0/yq_linux_amd64" > yq-go \
  && chmod +x yq-go
curl -L "https://github.com/stedolan/jq/releases/download/jq-1.5/jq-linux64" > jq \
  && chmod +x jq

echo
echo "=============================================================================================="
echo " Downloding ERT tile to @ https://pcf.$ENV_NAME.cf-app.com ..."
echo "=============================================================================================="

set +e
tries=3
while [[ ${tries} -gt 0 ]]
do
  echo "# pivnet-cli login"
  pivnet-cli login --api-token "${PIVNET_TOKEN}" && break
  tries=$(( ${tries} - 1 ))
  echo "# pivnet-cli login ${tries} tries remaining"
  [[ ${tries} -gt 0 ]] && echo "pivnet-cli login - waiting 5 mins for next try" && sleep 300
done
set -e

ERT_VERSION=$(pivnet-cli releases --product-slug elastic-runtime --format=json | jq -r '.[ ] .version' | grep -F "${PRODUCT_VERSION}" | head -n 1)
export ERT_VERSION
if [[ $GLOB_FILTER == *"srt"* ]]; then
  pivnet-cli download-product-files \
    --product-slug elastic-runtime \
    --release-version "${ERT_VERSION}" \
    --glob srt*.pivotal \
    --accept-eula
else
  pivnet-cli download-product-files \
    --product-slug elastic-runtime \
    --release-version "${ERT_VERSION}" \
    --glob cf*.pivotal \
    --accept-eula
fi

echo
echo "=============================================================================================="
echo " Uploading ERT tile to @ https://pcf.$ENV_NAME.cf-app.com ..."
echo "=============================================================================================="
om-linux --target "https://pcf.${ENV_NAME}.cf-app.com" -k \
  --username "${OPSMAN_USERNAME}" \
  --password "${OPSMAN_PASSWORD}" \
  --request-timeout 18000 \
  upload-product \
  --product ./*.pivotal 2>&1 | tee om-output.txt

echo
echo "=============================================================================================="
echo " Staging ERT tile to @ https://pcf.$ENV_NAME.cf-app.com ..."
echo "=============================================================================================="
uploaded_product_version=$(om-linux --target "https://pcf.${ENV_NAME}.cf-app.com" -k \
  --username "${OPSMAN_USERNAME}" \
  --password "${OPSMAN_PASSWORD}" \
  available-products \
  | grep cf | awk '{print $4}')
export uploaded_product_version

om-linux --target "https://pcf.${ENV_NAME}.cf-app.com" -k \
  --username "${OPSMAN_USERNAME}" \
  --password "${OPSMAN_PASSWORD}" \
  stage-product \
  --product-name cf \
  --product-version "${uploaded_product_version}"

stemcell_os=$(unzip -p "*.pivotal" metadata/*.yml | yq-go r - stemcell_criteria.os)
stemcell_version=$(unzip -p "*.pivotal" metadata/*.yml | yq-go r - stemcell_criteria.version)

echo
echo "=============================================================================================="
echo " Downloading stemcell ${stemcell_os} version ${stemcell_version} ... "
echo "=============================================================================================="

product_slug=""
case $stemcell_os in
  "ubuntu-trusty")
    product_slug="stemcells";;
  *)
    product_slug="stemcells-${stemcell_os}";;
esac

pivnet-cli download-product-files \
  --product-slug "${product_slug}" \
  --release-version "${stemcell_version}" \
  --glob "${stemcell_glob}" \
  --accept-eula

echo "=============================================================================================="
echo " Uploading stemcell ${stemcell_os} version ${stemcell_version} ... "
echo "=============================================================================================="
om-linux --target "https://pcf.${ENV_NAME}.cf-app.com" -k \
  --username "${OPSMAN_USERNAME}" \
  --password "${OPSMAN_PASSWORD}" \
  upload-stemcell \
  --stemcell ./"${stemcell_glob}".tgz

echo
echo "=============================================================================================="
echo " Removing extraneous tooling and downloaded files ..."
echo "=============================================================================================="
rm -fv om-linux pivnet-cli yq-go jq

rm -rfv ./*.pivotal ./*.tgz
