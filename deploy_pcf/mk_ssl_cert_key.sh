#! /bin/bash

set -ex 

DOMAIN=$1

SSL_FILE=sslconf-${DOMAIN}.conf

openssl genrsa -out ${DOMAIN}.key 2048


openssl req -x509 -newkey rsa:2048 -keyout ${DOMAIN}.key -out ${DOMAIN}.crt -days 3650 -nodes -subj "/C=US/ST=California/L=San Francisco/O=Pivotal Software Inc./CN=*.${DOMAIN}/emailAddress=cf-toolsmiths@pivotal.io/subjectAltName=DNS.1=${DOMAIN}"
