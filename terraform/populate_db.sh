#!/bin/bash

export DEBIAN_FRONTEND=noninteractive
export NEEDRESTART_SUSPEND=1
export NEEDRESTART_MODE=a

sudo apt-get update
# sudo apt-get upgrade -yqq
sudo apt-get install -y mysql-client-8.0 mysql-client-core-8.0

mkdir -pv ~/.mysql
wget "https://storage.yandexcloud.net/cloud-certs/CA.pem" --output-document ~/.mysql/root.crt
chmod 0600 ~/.mysql/root.crt

mysql --host="$1" \
        --port=3306 \
        --ssl-mode=VERIFY_IDENTITY \
        --ssl-ca=~/.mysql/root.crt \
        --user=john \
        --password=fhdjenljf \
        dostavim < CREATE.sql > output.sql
