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

#sync old data
#[ ! -e "${rootvolume}/key.dat" ] && [ -e /data/license/key.dat ] && {
#  log-warning "Synchronize data from old deploy configuration..."
#  rsync -xaXASH /data/template/id/db/ "${rootvolume}/db/"   # templare
#  rsync -xaXASH /data/apikey/keys.txt "${rootvolume}/"      #api key
#  rsync -xaXASH /data/config/id/ "${rootvolume}/db_config/" # db config host
#  rsync -xaXASH /data/saveimages/id/ "${rootvolume}/../saved_images/"
#  rsync -xaXASH /data/logs/id/ "${rootvolume}/../app_log/"
#  rsync -xaXASH /data/license/key.dat "${rootvolume}/license_api.dat"
#  rsync -xaXASH /data/license/soc/license.dat "${rootvolume}/license_soc.dat"
#}

#check license api
#[ -e "${rootvolume}/license_api.dat" ] || {
#  log-error "License does not exist"
#  exit 1
#}

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

[ -e "${rootvolume}/license.dat" ] || touch "${rootvolume}/license.dat"

dockerruncmd=$(
  cat <<__
docker run -idt --name $CONNAME --hostname $CONNAME \
-v "${rootvolume}/license.dat:/server/authorization/license.dat" \
-v "${rootvolume}/../app_log:/server/logs/" \
    --network "$NETNAME" ${STATICIP} "$IMAGE_BASE" bash -c "cd /server/ && ./run.sh"
__
)
# docker run -itd --name helloworld --hostname helloworld --network ocrnetwork nginxdemos/hello

log-info "Docker command: ${dockerruncmd}"
eval "${dockerruncmd}"

echo "${dockerruncmd}" >"${confpath%/*}/docker-run.sh"
chmod 755 "${confpath%/*}/docker-run.sh"

# trustconfig="url = https://mbankingapi-uat.pgbank.com.vn/mobile/ekyc/GetOCRConfirmation
# method = POST
# client_id = 106
# in_use = True"

#trust config for stg, already mount
#trustconfig="[TRUST_SERVER]
#url = https://mbankingapi-uat.pgbank.com.vn/mobile/ekyc/GetOCRConfirmation
#method = POST
#client_id = 106
#in_use = True
#authen_timeout = 40
#request_timeout = 20"

#[ -e "${rootvolume}/config_url.ini" ] || {
#  echo "${trustconfig}" >"${rootvolume}/config_url.ini"
#}

[ -e "${rootvolume}/backlist.py" ] && {
  log-warning "Update black list..."
  docker cp "${rootvolume}/backlist.py" "${CONNAME}:/workspace/setting/backlist.py"
  docker exec -it "${CONNAME}" rm -f "/workspace/setting/backlist.cpython-36m-x86_64-linux-gnu.so"
}

log-info "Restart the ${CONNAME} container to apply the configuration"
docker restart "${CONNAME}"
sleep 1

[ -e "${rootvolume}/../imgstest/id-front.jpg" ] || {
  log-warning "There is no photo in the path ${rootvolume}/../imgstest/id-front.jpg to test"
  exit 1
}

log-info "Checking api's ${CONNAME}..."

cnt=0
while :; do
  respone="$(curl -s --location --request POST 'https://stgapi.smartocr.vn/idfull/v1/recognition' \
    --header 'api-key: gAAAAABjKrxgRK7GoisJ60G4s22AgTGjInvpGpJV4wfHDgdQyPYIPXNVG4ImkP5wPRk35hmEZwFXDpM9L4t2VMvyQwVTKvMvLyi_oeOMuX-DGZebuw5KX_Q=' \
    --form "image1=@\"${rootvolume}/../imgstest/id-front.jpg\"" --form "image2=@\"${rootvolume}/../imgstest/id-back.jpg\"" --form 'encode=1' --form 'deviceid=like')"
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
