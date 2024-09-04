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
  echo "download start"
  echo "key var"
  echo $ACCOUNT_KEY
  echo $ACCOUNT_KEY > account_key.json
  cat account_key.json
  echo "that was the key"
  gcloud auth activate-service-account --key-file account_key.json

  gcloud storage cp gs://tas-prerelease/srt-7.0.0-build.11.pivotal
}

check_stemcell_exists() {
  stemcell_slug=$1
  version=$2
  iaas_glob=$3
  if pivnet-cli product-files -p "$stemcell_slug" -r "$version" | grep "bosh-stemcell-${version}-${iaas_glob}" 1>/dev/null; then
    return 0
  else
    echo "WARNING: No stemcell files on Pivnet for version ${version} and IaaS ${IAAS}." >&2
    return 1
  fi
}

if [ $# -eq "$NO_ARGS" ]
then
  usage
  exit $E_OPTERROR
fi

while getopts "u:p:t:g:v:e:i:s:a" Option
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
    a )
      arflag=true
      ACCOUNT_KEY=$OPTARG
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
export ACCOUNT_KEY

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
  |  jq -r ".[] | select(.name | contains(\"${STAGE_PRODUCT_SLUG}\")) | .version")

  uploaded_product_name=$(om-linux --target "https://pcf.${ENV_NAME}.cf-app.com" -k \
  --username "${OPSMAN_USERNAME}" \
  --password "${OPSMAN_PASSWORD}" \
  available-products \
  --format=json \
  |  jq -r ".[] | select(.name | contains(\"${STAGE_PRODUCT_SLUG}\")) | .name")

om-linux --target "https://pcf.${ENV_NAME}.cf-app.com" -k \
  --username "${OPSMAN_USERNAME}" \
  --password "${OPSMAN_PASSWORD}" \
  stage-product \
  --product-name ${uploaded_product_name} \
  --product-version "${uploaded_product_version}"

stemcell_os=$(unzip -p "*.pivotal" metadata/*.yml | yq-go r - stemcell_criteria.os)
tile_stemcell_version=$(unzip -p "*.pivotal" metadata/*.yml | yq-go r - stemcell_criteria.version)
major_version=$(echo "$tile_stemcell_version" | cut -f1 -d'.')

product_slug=""
case $stemcell_os in
  "ubuntu-trusty")
    product_slug="stemcells"
    ;;
  *)
    product_slug="stemcells-${stemcell_os}";;
esac

has_tile="true"
if ! check_stemcell_exists "$product_slug" "$tile_stemcell_version" "$stemcell_glob"; then
  has_tile="false"
fi

for i in $(seq 1 5);
do
  latest_stemcell_version=$(pivnet-cli releases -p $product_slug --format=json | jq '.[].version' -r  | grep -e "^$major_version$" -e "^$major_version\..*$" | sort --version-sort | tail -n $i | head -n 1)

  if [[ "$tile_stemcell_version" != "$latest_stemcell_version" ]]; then
    echo "Tile metadata specified $stemcell_os stemcell version $tile_stemcell_version, but $latest_stemcell_version is the latest usable release on Pivnet."
  fi

  has_latest="true"
  if ! check_stemcell_exists "$product_slug" "$latest_stemcell_version" "$stemcell_glob"; then
    has_latest="false"
  fi

  stemcell_version=""
  if [[ $has_tile == "true" ]]; then
    stemcell_version=$tile_stemcell_version
    break
  elif [[ $has_latest == "true" ]]; then
    stemcell_version=$latest_stemcell_version
    break
  else
    echo "Could not find $latest_stemcell_version."
  fi
done

if [[ $stemcell_version == "" ]]; then
  echo "ERROR: Could not find a compatible stemcell on Pivnet." >&2
  exit 1
fi

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
