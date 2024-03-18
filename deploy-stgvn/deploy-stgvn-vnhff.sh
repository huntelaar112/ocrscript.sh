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
STATICIP=       # auto set IP in bridge subnet
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
trap cleanup EXIT INT
cd "${temdir}"

#create ocrnetwork
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

[ -e "${rootvolume}/setup/STGVN-SOC/license.dat" ] || {
  log-error "License does not exist"
  exit 1
}

[[ $IMAGE_BASE ]] && {
  log-info "Use available Image Base ${IMAGE_BASE}"
} || {
  log-info "Downloading new image ..."
  curl -s -L "${URLIMAGE}" -o "vnhff.tar.zip"
  unzip -P "${IMAGE_PASSWORD}" "vnhff.tar.zip"
  rm -f "vnhff.tar.zip"

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

[ -e "${rootvolume}/keys.txt" ] || touch "${rootvolume}/keys.txt"

dockerruncmd=$(
  cat <<__
docker run -idt -e P=1 --name $CONNAME --hostname $CONNAME \
-v "${rootvolume}/setup/db.ini:/server/database/serv/db.ini" \
-v "${rootvolume}/setup/api.ini/:/server/api/configs/api.ini" \
-v "${rootvolume}/setup/STGVN-SOC/license.dat/:/server/modules/module_so/soc/core/authorization/license.dat" \
-v "${rootvolume}/setup/STGVN-API/license.dat/:/server/api/authorization/license.dat" \
-v "${rootvolume}/setup/STGVN-API/license.dat/:/server/api/authorization/license.dat" \
-v "${rootvolume}/../saved_images:/server/saved_images" \
-v "${rootvolume}/../app_log:/server/logs" \
--network "$NETNAME" ${STATICIP} "$IMAGE_BASE" bash -c "cd /server/ && ./run.sh"
__
)

log-info "Docker command: ${dockerruncmd}"
eval "${dockerruncmd}"

[[ -e "${rootvolume}/doc_type.py" ]] && {
  log-info "Remove doctype*.so"
  docker exec -it "${CONNAME}" bash -c 'rm -rf /server/database/ocr/doc_types/*.so'
}

#docker exec -it  "${CONNAME}"  sed '/on_premise/c on_premise = True/g' /server/api/configs/api.ini

echo "${dockerruncmd}" >"${confpath%/*}/docker-run.sh"
chmod 755 "${confpath%/*}/docker-run.sh"

#globalconfig
#log-info "Restart the ${CONNAME} container to apply the pb-* configuration"
log-info "Restart the ${CONNAME} container"
docker restart "${CONNAME}" 1>/dev/null
sleep 1

[ -e "${rootvolume}/../imgstest/image.jpg" ] || {
  log-warning "There is no photo in the path ${rootvolume}/../imgstest/image.jpg to test"
  exit 1
}

log-info "Checking api's ${CONNAME}..."

cnt=0
while :; do
  respone="$(curl -s --location --request POST 'https://stgapi.smartocr.vn/vnhff/v1/recognition' \
    --header 'Authorization: Bearer gAAAAABhb_Kilag9vNfUiCLLeYII-ur1I7fuGHupbNC9hO1Jtjd4zOX8TINBZvaRgKxAuiM_16qL4lKEp_mrqY1IFJkFFOxu56IZHzSesP8SCYq1tAIl9uw=' \
    --form "image=@\"${rootvolume}/../imgstest/image.jpg\"")"
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

# echo
done=yes
# URLIMAGE=