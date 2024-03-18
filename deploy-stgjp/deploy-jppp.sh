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
conpathdirname="${conpathdirname##*/}"

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

[[ $STATICIP ]] && [[ $NETNAME = bridge ]] && {
  log-error "User specified IP (${STATICIP}) address is supported on user defined networks only"
  exit 1
}

dockerruncmd=$(
  cat <<__
docker run -idt --name $CONNAME --hostname $CONNAME -e TZ=Asia/Ho_Chi_Minh --restart always \
-v "${rootvolume}/setup/license/api/license.dat:/server/api/authorization/license.dat" \
-v "${rootvolume}/setup/license/soc/license.dat:/server/modules/soc/core/authorization/license.dat" \
-v "${rootvolume}/setup/configs/api.ini:/server/api/configs/api.ini" \
-v "${rootvolume}/setup/apikey/keys.txt:/server/api/apikey/keys.txt" \
-v "${rootvolume}/../setup/logs/:/server/logs/" \
-v "${rootvolume}/../setup/saveimages/:/server/saveimages/" \
-v "${rootvolume}/setup/template/:/server/database/ocr/ocr_templates/db" \
-v "${rootvolume}/setup/run.sh:/server/run.sh" \
-v "${rootvolume}/setup/alt/alt.cpython-36m-x86_64-linux-gnu.so:/server/database/ocr/alt.cpython-36m-x86_64-linux-gnu.so" \
    --network "$NETNAME" ${STATICIP} "$IMAGE_BASE"
__
)
# docker run -itd --name helloworld --hostname helloworld --network ocrnetwork nginxdemos/hello

log-info "Docker command: ${dockerruncmd}"
eval "${dockerruncmd}"

echo "${dockerruncmd}" >"${confpath%/*}/docker-run.sh"
chmod 755 "${confpath%/*}/docker-run.sh"


[ -e "${rootvolume}/backlist.py" ] && {
  log-warning "Update black list..."
  docker cp "${rootvolume}/backlist.py" "${CONNAME}:/workspace/setting/backlist.py"
  docker exec -it "${CONNAME}" rm -f "/workspace/setting/backlist.cpython-36m-x86_64-linux-gnu.so"
}

log-info "Restart the ${CONNAME} container to apply the configuration"
docker restart "${CONNAME}"
sleep 1

log-step "Done deploy ${CONNAME}..."

