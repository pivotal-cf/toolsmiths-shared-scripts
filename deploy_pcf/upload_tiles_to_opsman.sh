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
srflag=false

NO_ARGS=0
E_OPTERROR=85

usage() { echo "Usage: cmd -u <OPSMAN_USERNAME> -p <OPSMAN_PASSWORD> -t <PIVNET_TOKEN> -g <GLOB_FILTER> -v <PRODUCT_VERSION> -e <ENV_NAME> -i <IAAS> -s <PRODUCT_SLUG>" 1>&2; exit 1; }

download_tile() {
  file_glob="INVALID_FILE_GLOB"

  case $PRODUCT_SLUG in
    'elastic-runtime' )
      if [[ $GLOB_FILTER == *"srt"* ]]; then
        file_glob="srt*.pivotal"
      else
        file_glob="cf*.pivotal"
      fi
      ;;
    'pivotal-container-service' )
        file_glob="*.pivotal"
      ;;
    *)
      echo "Unsupported slug: '$slug'"
      exit 1
      ;;
  esac

  release_version=$(pivnet-cli releases --product-slug $PRODUCT_SLUG --format=json | jq -r '.[ ] .version' | grep -F "${PRODUCT_VERSION}" | head -n 1)
  pivnet-cli download-product-files \
      --product-slug $PRODUCT_SLUG \
      --release-version "${release_version}" \
      --glob $file_glob \
      --accept-eula
}

if [ $# -eq "$NO_ARGS" ]
then
  usage
  exit $E_OPTERROR
fi

while getopts "u:p:t:g:v:e:i:s:" Option
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
    s )
      srflag=true
      PRODUCT_SLUG=$OPTARG
      ;;
    * ) usage ;;
  esac
done
shift $(($OPTIND - 1))

if ! $urflag || ! $prflag || ! $trflag || ! $grflag || ! $vrflag || ! $erflag || ! $irflag || ! $srflag
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
export PRODUCT_SLUG

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
echo " Downloding ${PRODUCT_SLUG} tile to @ https://pcf.$ENV_NAME.cf-app.com ..."
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

download_tile

echo
echo "=============================================================================================="
echo " Uploading ${PRODUCT_SLUG} tile to @ https://pcf.$ENV_NAME.cf-app.com ..."
echo "=============================================================================================="
om-linux --target "https://pcf.${ENV_NAME}.cf-app.com" -k \
  --username "${OPSMAN_USERNAME}" \
  --password "${OPSMAN_PASSWORD}" \
  --request-timeout 18000 \
  upload-product \
  --product ./*.pivotal 2>&1 | tee om-output.txt

echo
echo "=============================================================================================="
echo " Staging ${PRODUCT_SLUG} tile to @ https://pcf.$ENV_NAME.cf-app.com ..."
echo "=============================================================================================="
uploaded_product_version=$(om-linux --target "https://pcf.${ENV_NAME}.cf-app.com" -k \
  --username "${OPSMAN_USERNAME}" \
  --password "${OPSMAN_PASSWORD}" \
  available-products \
  --format=json \
  |  jq -r '.[0]."version"')

  uploaded_product_name=$(om-linux --target "https://pcf.${ENV_NAME}.cf-app.com" -k \
  --username "${OPSMAN_USERNAME}" \
  --password "${OPSMAN_PASSWORD}" \
  available-products \
  --format=json \
  |  jq -r '.[0]."name"')

om-linux --target "https://pcf.${ENV_NAME}.cf-app.com" -k \
  --username "${OPSMAN_USERNAME}" \
  --password "${OPSMAN_PASSWORD}" \
  stage-product \
  --product-name ${uploaded_product_name} \
  --product-version "${uploaded_product_version}"

stemcell_os=$(unzip -p "*.pivotal" metadata/*.yml | yq-go r - stemcell_criteria.os)
stemcell_version=$(unzip -p "*.pivotal" metadata/*.yml | yq-go r - stemcell_criteria.version)

product_slug=""
case $stemcell_os in
  "ubuntu-trusty")
    product_slug="stemcells"
    major_version=$(cut -f1 -d'.' $stemcell_version)
    stemcell_version=$(pivnet-cli releases -p $product_slug --format=json | jq '.[].version' -r  | grep $major_version | sort --version-sort | tail -n 1)
    ;;
  *)
    product_slug="stemcells-${stemcell_os}";;
esac

echo
echo "=============================================================================================="
echo " Downloading stemcell ${stemcell_os} version ${stemcell_version} ... "
echo "=============================================================================================="

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
  --stemcell ./${stemcell_glob}.tgz

rm -rfv ./*.pivotal ./*.tgz
