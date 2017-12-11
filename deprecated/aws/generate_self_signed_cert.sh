#!/bin/bash

if [[ -z $1 ]]; then
  echo "Usage: ./generate_self_signed_cert.sh [options] <PATH TO DIR>"
  echo "Options:"
  echo "    -y|--yes    Always overwrite files"
  echo "    -n|--no     Never overwrite files"
  exit 1
fi

MODE=ask
while true
do
  case $1 in
    -y|--yes)
      MODE=overwrite
      shift
      ;;
    -n|--no)
      MODE=keep
      shift
      ;;
    *)
      break
      ;;
  esac
done

dir=$1
certname=$2

mkdir -p $dir
pushd $dir

if [ -f ${certname}.pem ]; then
  [ "$MODE" == 'keep' ] && exit 0
  if [ "$MODE" == 'ask' ]; then
    read -p  "The certificate ${certname} already exists. Are you sure you want to overwrite it? (y/n): " input
    [ "$input" == 'n' ] && exit 0
  fi
fi

openssl genrsa -out ${certname}.key 2048 &&
  echo -e "\n\n\n\n\n\n\n" | openssl req -new -x509 -days 3650 -key ${certname}.key -out ${certname}.pem

ls -l

popd

echo -e "\n\nFinished generating cert."
