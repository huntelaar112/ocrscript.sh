#!/bin/bash

set -e
done=no
confpath="${1}"
EXITEVAL=""
[[ $confpath = "-h" ]] && {
  echo "config file reference:
NOROLLBACK=no
URLIMAGE=       # Must have If you do not use IMAGE_BASE available
IMAGE_PASSWORD= # Depends on URLIMAGE
NETNAME=        # Default ocrnetowrk -> bridge
MONGO_HOST=     # Must have
MONGO_PWD=      # Must have
STATICIP=       # auto set depend on subnet
IMAGE_BASE=     # Need if used Image is available
CONNAME=        # Default is the name of the configuration file folder
"
  exit 0
}

source $(which logshell)
source $(which dsutils)
[ -e "$confpath" ] || {
  log-error "File configuration does not exist"
  exit 1
}
confpath=$(realpath ${confpath})
#load config file
source "$confpath"
[[ $STATICIP ]] && STATICIP="--ip $STATICIP"
conpathdirname="${confpath%/*}"
conpathdirname="${conpathdirname##*/}"
# workdir="${workdir:-/home/stackops/HCM/}"
# IMAGE_PASSWORD=
# rootvolume=
temdir="$(mktemp -d)"
log-info "Temporary folder: ${temdir}"

function cleanup() {
  rm -rf '${temdir}'
  [[ $EXITEVAL ]] && eval "${EXITEVAL}"
}
trap cleanup EXIT
cd "${temdir}"

#create networkocr
OCRNETWORK_SUBNET=172.172.0.0/16
OCRNETWORK=ocrnetwork
docker-network-is-exist "${OCRNETWORK}" || {
  log-step "Add new network ${OCRNETWORK}: ${OCRNETWORK_SUBNET}"
  docker-network-create $OCRNETWORK $OCRNETWORK_SUBNET
} || {
  [[ $(docker-network-get-cidr "${OCRNETWORK}") = "${OCRNETWORK_SUBNET}" ]] || {
    log-error "Error Subnet: ${OCRNETWORK}\n Remove ${OCRNETWORK} [docker network rm ${OCRNETWORK}] and run again"
    exit 1
  }
}

#mkdir -p  /mnt/containerdata/{face,vnpff,id,mongo,pp,vnhff,cmqd,dklxvn}
CONNAME="${CONNAME:-${conpathdirname}}"

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
    # }
  }
}

[[ $NETNAME ]] || {
  docker-network-is-exist "${OCRNETWORK}" && NETNAME="${OCRNETWORK}" || NETNAME="bridge"
}

[[ $rootvolume ]] || rootvolume="${confpath%/*}"

[ -e "${rootvolume}/data/key/key.dat" ] || {
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

{ [ ! -e "${rootvolume}/data/config/db/mongo.ini" ] || [[ ! $(cat "${rootvolume}/data/config/db/mongo.ini") ]]; } && {
  [[ $mongoconf ]] && {
    mkdir "${rootvolume}/data/config/db/mongo.ini"
    echo "$mongoconf" >"${rootvolume}/data/config/db/mongo.ini"
  } || {
    log-error "Lack of configuration MongoDB: '${rootvolume}/data/config/db/mongo.ini'"
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
  curl -s -L "${URLIMAGE}" -o "face.tar.zip"
  unzip -P "${IMAGE_PASSWORD}" "face.tar.zip"
  rm -f "face.tar.zip"

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

[[ $STATICIP ]] && [[ $NETNAME = bridge ]] && {
  log-error "User specified IP (${STATICIP}) address is supported on user defined networks only"
  exit 1
}

dockerruncmd=$(
  cat <<__
docker run -idt -e P=1 --name $CONNAME --hostname $CONNAME --restart always -e TZ=Asia/Ho_Chi_Minh \
   -v "${rootvolume}/data/key/key.dat:/workspace/key.dat" \
   -v "${rootvolume}/data/config/db/:/workspace/setting/db_config" \
   -v "${rootvolume}/data/config/api/config.ini:/workspace/setting/api_config/config.ini" \
   -v "${rootvolume}/data/template/:/workspace/setting/templates/cloud/" \
   -v "${rootvolume}/../app_log:/workspace/logs/" \
   -v "${rootvolume}/../saved_images:/workspace/saveimages" \
    --network "$NETNAME" ${STATICIP} --entrypoint  /workspace/run.sh  "$IMAGE_BASE"
__
)

log-info "Docker command: ${dockerruncmd}"
eval "${dockerruncmd}"
echo "${dockerruncmd}" >"${confpath%/*}/docker-run.sh"
chmod 755 "${confpath%/*}/docker-run.sh"

#mount
#trustconfig="[TRUST_SERVER]
#url = https://mbankingapi-uat.pgbank.com.vn/mobile/ekyc/FaceMatchingGMOConfirm
#method = POST
#client_id = 106
#authen_timeout = 40
#request_timeout = 20"

#[ -e "${rootvolume}/config_url.ini" ] || {
#  echo "${trustconfig}" >"${rootvolume}/config_url.ini"
#}
#docker cp "${rootvolume}/config_url.ini" "${CONNAME}:/workspace/face_recog/send_request/config_url.ini"

[ -e "${rootvolume}/backlist.py" ] && {
  log-warning "Update black list..."
  docker cp "${rootvolume}/backlist.py" "${CONNAME}:/workspace/setting/backlist.py"
  docker exec -it "${CONNAME}" rm -f "/workspace/setting/backlist.cpython-36m-x86_64-linux-gnu.so"
}

log-info "Restart the ${CONNAME} container to apply the URL configuration"
docker restart "${CONNAME}" 1>/dev/null

[ -e "${rootvolume}/../imgstest/face1.jpg" ] || {
  log-warning "There is no photo in the path ${rootvolume}/../imgstest/face1.jpg to test"
  exit 1
}
sleep 1

log-info "Checking api's ${CONNAME} ...."
cnt=0
while :; do
  respone="$(curl -s --location --request POST 'https://tempprod.smartocr.vn/face/v1/recognition' \
    --header 'api-key: gAAAAABjTQHbH8GV8N0AGGm3hEmFoNcxNm4rsK8SFMGg8dAfzbUMsPGRdtsIhjdpnn-PplMfGolOrbrFo5I2431L4mxZfcgKzvmSoKtzbzvs2OY9GM8R3foU-9-Ub_p2EEFhHOe82Ndq' \
    --form "image1=@\"${rootvolume}/imgstest/../face1.jpg\"" --form "image2=@\"${rootvolume}/imgstest/../face2.jpg\"" --form 'encode="1"')"
  ((cnt = cnt + 1))
  echo "${respone}" | grep -Ee '"result_code"\s*:\s*304' && {
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

# URLIMAGE=
