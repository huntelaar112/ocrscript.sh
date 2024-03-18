#!/bin/bash

set -e
done=no
confpath="${1}"
EXITEVAL=""

[[ $confpath = "-h" ]] && {
  echo "config file reference:
NOROLLBACK=yes
URLIMAGE=                  # Must have If you do not use IMAGE_BASE available
NETNAME=
IMAGE_PASSWORD=            # Depends on URLIMAGE
MONGO_HOST=                # Must have
MONGO_PWD=                 # Must have
STATICIP=                  # Auto set depend on docker network
IMAGE_BASE=                # Need if used Image is available
CONNAME=id                 # Default is the name of the configuration file folder
DEFAULT_NETWORK=ocrnetwork
"
  exit 0
}

#for checking
keydatfolder="data/license/api/key.dat"
mongoconfigfolder="data/config/id/mongo.ini"

source $(which logshell)
source $(which dsutils)
[ -e "$confpath" ] || {
  log-error "File configuration does not exist"
  exit 1
}
confpath=$(realpath ${confpath})
source "$confpath"

[[ $STATICIP ]] && STATICIP="--ip $STATICIP"
conpathdirname="${confpath%/*}"
conpathdirname="${conpathdirname##*/}"
# workdir="${workdir:-/home/stackops/HCM/}"

temdir="$(mktemp -d)"
log-info "Temporary folder: ${temdir}"
function cleanup() {
  rm -rf "${temdir}"
  [[ $EXITEVAL ]] && eval "${EXITEVAL}"
}
trap cleanup EXIT

cd "${temdir}"
#create networkocr
OCRNETWORK_SUBNET=172.172.0.0/16
OCRNETWORK="${DEFAULT_NETWORK}"
docker-network-is-exist "${OCRNETWORK}" || {
  log-step "Add new network ${OCRNETWORK}: ${OCRNETWORK_SUBNET}"
  docker-network-create $OCRNETWORK $OCRNETWORK_SUBNET
} || {
  [[ $(docker-network-get-cidr "${OCRNETWORK}") = "${OCRNETWORK_SUBNET}" ]] || {
    log-error "Error Subnet: ${OCRNETWORK}\n Remove ${OCRNETWORK} [docker network rm ${OCRNETWORK}] and run again"
    exit 1
  }
}

# if CONNAME=null --> CONNAME=conpathdirname else CONNAME=CONNAME
CONNAME="${CONNAME:-${conpathdirname}}"
# if con.old exist --> delete con --> rename con.old to con
function roolback() {
  [[ $NOROLLBACK = yes ]] && {
    log-error "Skip roll back"
    exit 1
  }
  docker-container-is-exist "${CONNAME}.old" && {
    # docker-container-is-running "${CONNAME}" || {
    log-warning 'Rollback to last container'
    docker rm -f "${CONNAME}" 1>/dev/null
    docker rename "${CONNAME}.old" "$CONNAME"
    docker start "$CONNAME" 1>/dev/null
    sleep 1
    docker-container-is-running "${CONNAME}" && {
      log-info 'Roll back successful'
    } || {
      log-error 'Roll back failure'
    }
  }
}

[[ $NETNAME ]] || {
  docker-network-is-exist "${OCRNETWORK}" && NETNAME="${OCRNETWORK}" || NETNAME="bridge"
}

[[ $rootvolume ]] || rootvolume="${confpath%/*}"
# use fist time deploy  form old version of  Minhvhd
#log-warning "Sync data logs..."
#rsync -xaXASH /data/logs/id/ "${rootvolume}/../app_log/"
#rsync -xaXASH /data/saveimages/id/ "${rootvolume}/../saved_images/"

[ -e "${rootvolume}/${keydatfolder}" ] || {
  log-error "License does not exist"
  exit 1
}

[[ ${MONGO_HOST} ]] && {
  mongoconf="
[MONGO]
MONGO_HOST=${MONGO_HOST}
MONGO_USER_PORT=27017
MONGO_USERNAME=root
MONGO_ROOT_PASSWORD=${MONGO_PWD}
DATABASE=KYCDB
AUTHSOURCE=admin"
}

{ [ ! -e "${rootvolume}/${mongoconfigfolder}" ] || [[ ! $(cat "${rootvolume}/${mongoconfigfolder}") ]]; } && {
  [[ $mongoconf ]] && {
    echo "$mongoconf" >"${rootvolume}/${mongoconfigfolder}"
  } || {
    log-error "Lack of configuration MongoDB: '${rootvolume}/${mongoconfigfolder}'"
    exit 1
  }
}

timeout 0.5 bash -c "cat < /dev/null > /dev/tcp/${MONGO_HOST}/27017" || {
  log-error "Mongodb server is down"
  exit 1
}

[[ $IMAGE_BASE ]] && {
  log-info "Use available Image Base ${IMAGE_BASE}"
} || {
  log-info "Downloading new image ..."
  curl -s -L "${URLIMAGE}" -o "id.tar.zip"
  unzip -P "${IMAGE_PASSWORD}" "id.tar.zip"
  rm -f "id.tar.zip"

  log-info "Loadding new image ..."
  IMAGE_BASE="$(docker load -i *.tar 2>&1)"
  IMAGE_BASE=$(echo "$IMAGE_BASE" | grep "Loaded image" | tail -n 1 | grep -iEoe "[\s]+$")
  sed -i -e "s/^IMAGE_BASE=.*/IMAGE_BASE='${IMAGE_BASE}'/g" "${confpath}"
}

[[ $IMAGE_BASE ]] && log-info "New image (${IMAGE_BASE}) has been loaded"
docker-container-is-exist "${CONNAME}.old" && {
  docker-container-is-exist "${CONNAME}" && {
    log-warning "Backup container has existed ${CONNAME}.old. Delete containers ${CONNAME}"
    docker rm -f "${CONNAME}"
  }
} || {
  docker-container-is-exist $CONNAME && {
    log-warning "Rename container $CONNAME -> ${CONNAME}.old"
    docker rename $CONNAME "${CONNAME}.old" &>/dev/null
    docker-container-is-running "${CONNAME}.old" && docker stop "${CONNAME}.old"
    EXITEVAL="roolback"
  }
}
#none:  use old  data , update
#Folder struct inside contianer
# mount
# 1. customer template: /workspace/config/template_id/db                            #update
# 2. apikey: /workspace/setting/keys.txt                                            #update
# 3. config mysql  and mongo: /workspace/setting/db_config
# 4. license  api : /workspace/key.dat                                              #update
# 5. license soc:  /workspace/id/Compare_CCCD/soc/core/authorization/license.dat    #update
# 6. logs
# 7. saved_images
#copy
# 8. config  of api: /workspace/config/config.ini                                   #update
# 9. config Trust server: /workspace/app/ocr/PGB/config_url.ini

# deploy on GPU1 vs number Process=1
dockerruncmd=$(
  cat <<__
nvidia-docker run --gpus "device=1" -e CUDA_VISIBLE_DEVICES=1 \
-idt -e P=1 --name $CONNAME --hostname $CONNAME --restart always -e LD_LIBRARY_PATH=/usr/local/cuda-11.7/lib64 \
-e TZ=Asia/Ho_Chi_Minh --privileged --ulimit core=0 \
-v "${rootvolume}/data/config/id/:/workspace/setting/db_config" \
-v "${rootvolume}/data/config/Trust/config_url.ini:/workspace/app/ocr/PGB/config_url.ini" \
-v "${rootvolume}/data/config/API/config_id1.ini:/workspace/config/config.ini" \
-v "${rootvolume}/data/license/api/key.dat:/workspace/key.dat" \
-v "${rootvolume}/data/license/soc/license.dat:/workspace/id/Compare_CCCD/soc/core/authorization/license.dat" \
-v "${rootvolume}/data/template/id/db:/workspace/config/template_id/db" \
-v "${rootvolume}/data/apikey/keys.txt:/workspace/setting/keys.txt" \
-v "${rootvolume}/../../saved_images:/workspace/saved_images" \
-v "${rootvolume}/../../app_log_id1:/workspace/logs/app_log" \
-v "${rootvolume}/run.sh:/workspace/run.sh" \
    --network "$NETNAME" ${STATICIP} "$IMAGE_BASE" bash -c "cd /workspace && chmod 755 run.sh && ./run.sh"
__
)

log-info "Docker command: ${dockerruncmd}"
eval "${dockerruncmd}"

echo "${dockerruncmd}" >"${confpath%/*}/docker-run-id1.sh"
chmod 755 "${confpath%/*}/docker-run-id1.sh"

#TRUST SERVER CONFIG
trustconfig="[TRUST_SERVER]
url = https://pgekyc.pgbank.com.vn:8443/mobile/ekyc/GetOCRConfirmation
method = POST
client_id = 106
in_use = True
authen_timeout = 40
request_timeout = 20
"

[ -e "${rootvolume}/config_url.ini" ] || {
  echo "${trustconfig}" >"${rootvolume}/config_url.ini"
}
sleep 2
log-info "Copy config_url.ini to container"
docker cp "${rootvolume}/config_url.ini" "${CONNAME}:/workspace/app/ocr/PGB/config_url.ini"

# TAT CHUC NANG
[ -e "${rootvolume}/id_ocr.py" ] && {
  log-warning "Disable model..."
  docker cp "${rootvolume}/id_ocr.py" "${CONNAME}:/workspace/id/recognition/"
  docker exec -it "${CONNAME}" mv "/workspace/id/recognition/id_ocr.cpython-36m-x86_64-linux-gnu.so" "/workspace/id/recognition/id_ocr.cpython-36m-x86_64-linux-gnu.so.old"
}

# UPDATE BLACK LIST
#[ -e "${rootvolume}/backlist.py" ] && {
#  log-warning "Update black list..."
#  docker cp "${rootvolume}/backlist.py" "${CONNAME}:/workspace/setting/backlist.py"
#  docker exec -it "${CONNAME}" rm -f "/workspace/setting/backlist.cpython-36m-x86_64-linux-gnu.so"
#}

# RESTART CONTAINER AND TEST API
log-info "Restart the ${CONNAME} container to apply the URL configuration"
docker restart "${CONNAME}"
sleep 1

#Checking api
[ -e "${rootvolume}/../../imgstest/id-front.jpg" ] || {
  log-warning "There is no photo in the path ${rootvolume}/../../imgstest/id-front.jpg to test"
  exit 1
}
log-info "Checking api's ${CONNAME}..."

cnt=0
while :; do
  respone="$(curl -s --location --request POST 'https://gapi.smartocr.vn/idfull/v1/recognition' \
    --header 'api-key: gAAAAABiTAtgmP_ESEZBmKrCEVAd6OvYnhGOaHp8_I6LQnh_cyBRW8G_P3G7MFXijzXsbklGk0k9eKi7lSI1BbfP5LzaH5VflXo4kavHJWOKPNT6JFHqCHAB1jY4GBN4hGqsjSTrzXBS9UXfnqJnRd-IuNaqNxzLfA==' \
    --form "image1=@\"${rootvolume}/../../imgstest/id-front.jpg\"" --form "image2=@\"${rootvolume}/../../imgstest/id-back.jpg\"" --form 'encode=1' --form 'deviceid=like')"
  ((cnt = cnt + 1))
  echo "${respone}" | grep -Ee '"result_code"' && {
    log-info "Success calls API to new containers"
    done=yes
    break
  } || {
    echo -n " ."
    ((cnt > 5)) && {
      log-debug "Error call API to new containers"
      echo "${respone}"
      EXITEVAL="roolback"
      break
    }
  }
  sleep 2
done

done=yes
# URLIMAGE=
