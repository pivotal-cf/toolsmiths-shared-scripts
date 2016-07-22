#!/bin/bash

die() {
  echo "[ERROR] $*"
  exit 1
}

HERE="${PWD}"
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
CERTSTRAP="${SCRIPT_DIR}/certstrap"
[ -f "${CERTSTRAP}" ] || die "CA tool not found: ${CERTSTRAP}"

chmod +x $CERTSTRAP

if [[ -z $1 ]]; then
  echo "Usage: $0 [options] <PATH TO DIR>"
  echo "Options:"
  echo "    -y|--yes    Always overwrite files"
  echo "    -n|--no     Never overwrite files"
  echo "Arguments:"
  echo "    <PATH TO DIR>  the directory _above_ where the diego certs live"
  exit 1
fi

# Process command line options, if any
DEFAULT_ACTION=
while true
do
  case $1 in
    -y|--yes)
      DEFAULT_ACTION=-y
      shift
      ;;
    -n|--no)
      DEFAULT_ACTION=-n
      shift
      ;;
    *)
      break
      ;;
  esac
done

# ask_yn: Ask a question and return 0/yes or 1/no unless default specified
ask_yn() {
  local answer
  case "$1" in
    -y|--yes)
      return 0
      ;;
    -n|--no)
      return 1
      ;;
  esac

  while true
  do
    printf "%s (yes/no) " "$*"
    read answer
    answer=$(tr '[:upper:]' '[:lower:]' <<< "$answer")
    case "$answer" in
      y|yes)
        return 0
        ;;
      n|no)
        return 1
        ;;
    esac
  done
}


function generate_and_sign_cert () {
  local name=$1
  local common_name=$2
  local domain=$3

  if [[ -z $domain ]]
  then
    ${CERTSTRAP} --depot-path "${DEST_DIR}" request-cert \
      --common-name "${common_name}" \
      --passphrase ""
  else
    ${CERTSTRAP} --depot-path "${DEST_DIR}" request-cert \
        --common-name "${common_name}" \
        --domain "${domain}" \
        --passphrase ""
  fi

  ${CERTSTRAP} --depot-path "${DEST_DIR}" sign "${common_name}" --CA diegoCA

  rm -f ${DEST_DIR}/${common_name}.csr
  mv -f ${DEST_DIR}/${common_name}.key ${DEST_DIR}/${name}_key
  mv -f ${DEST_DIR}/${common_name}.crt ${DEST_DIR}/${name}_cert
}


#
# Main
#
DEST_DIR="$1"
DEST_DIR=$(tr -s / <<< "${DEST_DIR}/diego")
mkdir -p "${DEST_DIR}"
pushd "${DEST_DIR}"


# Determine desired action for each certificate
for file in diego_ca_cert etcdpeers_ca_cert bbs_client_cert bbs_server_cert etcd_client_cert etcd_server_cert ssh_proxy_key etcd_peers_cert
do
  var="${file}_flag"

  # Handle dependancies (some things MUST change if the signing CA will change)
  if [ "${file}" != "diego_ca_cert" -a "${file}" != "etcdpeers_ca_cert" ]
  then
    if [ "${file}" == "etcd_peers_cert" ] && ${etcdpeers_ca_cert_flag}
    then
      declare "${var}=true"
    elif ${diego_ca_cert_flag} && [ "${file}" != "ssh_proxy_key" ]
    then
      declare "${var}=true"
    fi
  fi

  if [ -f "$file" -a -z "${!var}" ]  # only runs when ${!var} not yet declared
  then
    if ask_yn ${DEFAULT_ACTION} "${file} exists; do you want to recreate it?"
    then
      declare "${var}=true"
    else
      declare "${var}=false"
    fi
  else
    declare "${var}=true"
  fi
done

popd

if $diego_ca_cert_flag
then
  echo -e "\n\n=== GENERATING NEW DIEGO CERTIFICATE AUTHORITY ===\n"
  ${CERTSTRAP} --depot-path "${DEST_DIR}" init --common-name "diegoCA" --passphrase ""

  rm -f ${DEST_DIR}/diegoCA.crl
  cp -f ${DEST_DIR}/diegoCA.crt ${DEST_DIR}/diego_ca_cert
  cp -f ${DEST_DIR}/diegoCA.key ${DEST_DIR}/diego_ca_key
fi

if $etcdpeers_ca_cert_flag
then
  echo -e "\n\n=== GENERATING NEW ETCD PEER CERTIFICATE AUTHORITY ===\n"
  ${CERTSTRAP} --depot-path "${DEST_DIR}" init --common-name "peerCA" --passphrase ""

  rm -f ${DEST_DIR}/peerCA.crl
  cp -f ${DEST_DIR}/peerCA.crt ${DEST_DIR}/etcdpeers_ca_cert
  cp -f ${DEST_DIR}/peerCA.key ${DEST_DIR}/etcdpeers_ca_key
fi

## HACK HACK HACK
# generate_and_sign_cert() wants to see .crt and .key style certs, so we need
# to recreate those on repeat runs to make it happy.
[ -f "${DEST_DIR}/diegoCA.crt" ] || cp "${DEST_DIR}/diego_ca_cert" "${DEST_DIR}/diegoCA.crt"
[ -f "${DEST_DIR}/diegoCA.key" ] || cp "${DEST_DIR}/diego_ca_key" "${DEST_DIR}/diegoCA.key"
[ -f "${DEST_DIR}/peerCA.crt" ] || cp "${DEST_DIR}/etcdpeers_ca_cert" "${DEST_DIR}/peerCA.crt"
[ -f "${DEST_DIR}/peerCA.key" ] || cp "${DEST_DIR}/etcdpeers_ca_key" "${DEST_DIR}/peerCA.key"
# END HACK

if $etcd_peers_cert_flag
then
  echo -e "\n\n=== GENERATING NEW ETCD PEER CERT AND KEY ===\n"
  common_name="etcd.service.cf.internal"
  domain="*.etcd.service.cf.internal,etcd.service.cf.internal"

  ${CERTSTRAP} --depot-path "${DEST_DIR}" request-cert \
       --common-name "${common_name}" \
       --domain "${domain}" \
       --passphrase ""

  ${CERTSTRAP} --depot-path "${DEST_DIR}" sign "${common_name}" --CA peerCA

  rm -f ${DEST_DIR}/${common_name}.csr
  mv -f ${DEST_DIR}/${common_name}.key ${DEST_DIR}/etcd_peers_key
  mv -f ${DEST_DIR}/${common_name}.crt ${DEST_DIR}/etcd_peers_cert
fi

if $bbs_client_cert_flag
then
  echo -e "\n\n=== GENERATING NEW BBS CLIENT CERT AND KEY ===\n"
  generate_and_sign_cert "bbs_client" "clientName"
fi

if $bbs_server_cert_flag
then
  echo -e "\n\n=== GENERATING NEW BBS SERVER CERT AND KEY ===\n"
  generate_and_sign_cert "bbs_server" "bbs.service.cf.internal" "*.bbs.service.cf.internal,bbs.service.cf.internal"
fi

if $etcd_client_cert_flag
then
  echo -e "\n\n=== GENERATING NEW ETCD CLIENT CERT AND KEY ===\n"
  generate_and_sign_cert "etcd_client" "clientName"
fi

if $etcd_server_cert_flag
then
  echo -e "\n\n=== GENERATING NEW ETCD SERVER CERT AND KEY ===\n"
  generate_and_sign_cert "etcd_server" "etcd.service.cf.internal" "*.etcd.service.cf.internal,etcd.service.cf.internal"
fi

if $ssh_proxy_key_flag
then
  echo -e "\n\n=== GENERATING NEW SSH PROXY KEY ===\n"
  [ -f "${DEST_DIR}/ssh_proxy_key" ] && rm -f "${DEST_DIR}/ssh_proxy_key"
  [ -f "${DEST_DIR}/ssh_proxy_key.pub" ] && rm -f "${DEST_DIR}/ssh_proxy_key.pub"
  ssh-keygen -q -t rsa -N "" -f "${DEST_DIR}/ssh_proxy_key"
  rm -f "${DEST_DIR}/ssh_proxy_key.pub"
fi

# Clean up the CA cert copies which we do not want to check into the repo
for fn in diegoCA peerCA
do
  fn="${DEST_DIR}/${fn}"
  [ -f "${fn}.crt" ] && rm -f ${fn}.crt
  [ -f "${fn}.key" ] && rm -f ${fn}.key
done

echo
ls -l ${DEST_DIR}

echo -e "\n\nFinished generating certs and keys."
