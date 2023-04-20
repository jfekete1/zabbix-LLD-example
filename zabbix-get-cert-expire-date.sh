#!/bin/bash

if [ -z "$1" ]; then
  echo "Need a domain name for the certificate to query!"
  exit 1
fi

echo $1
