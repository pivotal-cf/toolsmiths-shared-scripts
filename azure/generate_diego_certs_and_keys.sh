#!/bin/bash

if [[ -z $1 ]]; then
  echo "Usage: ./generate_diego_certs_and_keys.sh <PATH TO DIR>"
  exit 1
fi

certs_and_keys_dir=$1

function generate_and_sign_cert () {
  name=$1
  common_name=$2
  domain=$3

  if [[ -z $domain ]]; then
    ./certstrap --depot-path "${certs_and_keys_dir}/diego" request-cert \
      --common-name "${common_name}" \
      --passphrase ""
  else
    ./certstrap --depot-path "${certs_and_keys_dir}/diego" request-cert \
        --common-name "${common_name}" \
        --domain "${domain}" \
        --passphrase ""
  fi

  ./certstrap --depot-path "${certs_and_keys_dir}/diego" sign "${common_name}" --CA diegoCA

  rm -f ${certs_and_keys_dir}/diego/${common_name}.csr
  mv -f ${certs_and_keys_dir}/diego/${common_name}.key ${certs_and_keys_dir}/diego/${name}_key
  mv -f ${certs_and_keys_dir}/diego/${common_name}.crt ${certs_and_keys_dir}/diego/${name}_cert
}


mkdir -p $certs_and_keys_dir/diego
pushd $certs_and_keys_dir/diego

for file in diego_ca_cert bbs_client_cert bbs_server_cert etcd_client_cert etcd_server_cert ssh_proxy_key etcdpeers_ca_cert etcd_peers_cert; do
  var=${file}_flag
  declare "${var}=true"
  if [ -f $file ]; then
    echo -n "$file already exists. Do you want to recreate it? (y/n)"
    read line
    if [[ $line == 'n' ]]; then
     declare "${var}=false"
    fi
  fi
done

popd

if [[ $diego_ca_cert_flag == true ]]; then
  echo -e "\n\n=== GENERATING NEW DIEGO CERTIFICATE AUTHORITY ===\n"
  ./certstrap --depot-path "${certs_and_keys_dir}/diego" init --common-name "diegoCA" --passphrase ""
fi

if [[ $etcdpeers_ca_cert_flag == true ]]; then
  echo -e "\n\n=== GENERATING NEW ETCD PEER CERTIFICATE AUTHORITY ===\n"
  ./certstrap --depot-path "${certs_and_keys_dir}/diego" init --common-name "peerCA" --passphrase ""
fi

if [[ $etcd_peers_cert_flag == true ]]; then
  echo -e "\n\n=== GENERATING NEW ETCD PEER CERT AND KEY ===\n"
  common_name="etcd.service.cf.internal"
  domain="*.etcd.service.cf.internal,etcd.service.cf.internal"

  ./certstrap --depot-path "${certs_and_keys_dir}/diego" request-cert \
       --common-name "${common_name}" \
       --domain "${domain}" \
       --passphrase ""

  ./certstrap --depot-path "${certs_and_keys_dir}/diego" sign "${common_name}" --CA peerCA

  rm -f ${certs_and_keys_dir}/diego/${common_name}.csr
  mv -f ${certs_and_keys_dir}/diego/${common_name}.key ${certs_and_keys_dir}/diego/etcd_peers_key
  mv -f ${certs_and_keys_dir}/diego/${common_name}.crt ${certs_and_keys_dir}/diego/etcd_peers_cert
fi

if [[ $bbs_client_cert_flag == true ]]; then
  echo -e "\n\n=== GENERATING NEW BBS CLIENT CERT AND KEY ===\n"
  generate_and_sign_cert "bbs_client" "clientName"
fi

if [[ $bbs_server_cert_flag == true ]]; then
  echo -e "\n\n=== GENERATING NEW BBS SERVER CERT AND KEY ===\n"
  generate_and_sign_cert "bbs_server" "bbs.service.cf.internal" "*.bbs.service.cf.internal,bbs.service.cf.internal"
fi

if [[ $etcd_client_cert_flag == true ]]; then
  echo -e "\n\n=== GENERATING NEW ETCD CLIENT CERT AND KEY ===\n"
  generate_and_sign_cert "etcd_client" "clientName"
fi

if [[ $etcd_server_cert_flag == true ]]; then
  echo -e "\n\n=== GENERATING NEW ETCD SERVER CERT AND KEY ===\n"
  generate_and_sign_cert "etcd_server" "etcd.service.cf.internal" "*.etcd.service.cf.internal,etcd.service.cf.internal"
fi

if [[ $ssh_proxy_key_flag == true ]]; then
  echo -e "\n\n=== GENERATING NEW SSH PROXY KEY ===\n"
  echo -e  'y\n'| ssh-keygen -q -t rsa -N "" -f "${certs_and_keys_dir}/diego/ssh_proxy_key"
  rm -f "${certs_and_keys_dir}/diego/ssh_proxy_key.pub"
fi

rm -f ${certs_and_keys_dir}/diego/diegoCA.crl
mv -f ${certs_and_keys_dir}/diego/diegoCA.crt ${certs_and_keys_dir}/diego/diego_ca_cert
mv -f ${certs_and_keys_dir}/diego/diegoCA.key ${certs_and_keys_dir}/diego/diego_ca_key

rm -f ${certs_and_keys_dir}/diego/peerCA.crl
mv -f ${certs_and_keys_dir}/diego/peerCA.crt ${certs_and_keys_dir}/diego/etcdpeers_ca_cert
mv -f ${certs_and_keys_dir}/diego/peerCA.key ${certs_and_keys_dir}/diego/etcdpeers_ca_key

ls -l ${certs_and_keys_dir}/diego

echo -e "\n\nFinished generating certs and keys."
