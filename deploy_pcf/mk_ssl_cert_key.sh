#!/bin/bash
set -e

[[ ${1} ]] && ENV_NAME=${1}
: ${ENV_NAME:?must be set the environment name (ex: mammoth)}
: ${KEY_BITS:=2048}
: ${DAYS:=365}

openssl req -new -x509 -nodes -sha256 -newkey rsa:${KEY_BITS} -days ${DAYS} -keyout ${ENV_NAME}.ca.key.pkcs8 -out ${ENV_NAME}.ca.crt -config <( cat << EOF
[ req ]
prompt = no
distinguished_name    = dn

[ dn ]
C  = US
O = Pivotal

EOF
)

openssl rsa -in ${ENV_NAME}.ca.key.pkcs8 -out ${ENV_NAME}.ca.key
