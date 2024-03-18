#!/bin/bash

set -e
done=no

source $(which logshell)
source $(which dsutils)

docker run -itd --restart always --name mongo_newdb -e MONGO_INITDB_ROOT_USERNAME=root -e MONGO_INITDB_ROOT_PASSWORD=123456 docker.io/mongo:4.2.6

docker run -itd --name convert_db_097 --hostname convert_db_097 --network ocrnet convert_db-0.9.7-30122022 bash

mongo_old="
[MONGO]
MONGO_HOST=${MONGO_HOST}
MONGO_USER_PORT=27017
MONGO_USERNAME=root
MONGO_ROOT_PASSWORD=${MONGO_PWD}
DATABASE=KYCDB
AUTHSOURCE=admin"

mongo_new="
[MONGO]
MONGO_HOST=${MONGO_HOST}
MONGO_USER_PORT=27017
MONGO_USERNAME=root
MONGO_ROOT_PASSWORD=${MONGO_PWD}
DATABASE=KYCDB
AUTHSOURCE=admin"