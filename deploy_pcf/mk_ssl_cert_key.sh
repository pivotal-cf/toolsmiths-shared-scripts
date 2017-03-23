#! /bin/bash

set -ex 

DOMAIN=$1


openssl req -x509 -newkey rsa:2048 -keyout ${DOMAIN}.key -out ${DOMAIN}.crt -days 3650 -nodes -subj "/C=US/ST=California/L=San Francisco/O=Pivotal Software Inc./CN=*.${DOMAIN}/emailAddress=cf-toolsmiths@pivotal.io/subjectAltName=DNS.1=${DOMAIN},DNS.2=*.uaa.${DOMAIN},DNS.3=*.login.${DOMAIN}"
