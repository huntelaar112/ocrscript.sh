#!/bin/bash
set -e
done=no
source $(which logshell)
source $(which dsutils)
## deploy tool convert db
docker run -itd --name convert_db_097 -hostname convert_db_097 --network ocrnet convert_db-0.9.7-30122022 bash

mongo_oldconf="[MONGO]
MONGO_HOST=172.18.0.17
MONGO_USER_PORT=27017
MONGO_USERNAME=root
MONGO_ROOT_PASSWORD=123456
DATABASE=KYCDB
AUTHSOURCE=admin"

mongo_newconf="[MONGO]
MONGO_HOST=172.18.0.17
MONGO_USER_PORT=27017
MONGO_USERNAME=root
MONGO_ROOT_PASSWORD=123456
DATABASE=KYCDB1
AUTHSOURCE=admin"

docker exec -d convert_db_097 echo "${mongo_oldconf}" > /workspace/config/db/mongo_old.ini
docker exec -d convert_db_097 echo "${mongo_newconf}" > /workspace/config/db/mongo_new.ini

docker exec -d convert_db_097 sh run.sh && sh check.sh

# /workspace/logs/app.log --> view convert log
# Step 1 --> deploy tool conver DB
# Step 2 --> deploy face (endpoint test)
# Step 3 --> if test ok -> rename contianer name face test --> face
