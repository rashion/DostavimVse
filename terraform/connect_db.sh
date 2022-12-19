#!/bin/bash

mkdir -pv ~/.mysql
wget "https://storage.yandexcloud.net/cloud-certs/CA.pem" --output-document ~/.mysql/root.crt
chmod 0600 ~/.mysql/root.crt

mysql --host="$1" \
        --port=3306 \
        --ssl-mode=VERIFY_IDENTITY \
        --ssl-ca=~/.mysql/root.crt \
        --user=john \
        --password=fhdjenljf \
        dostavim
