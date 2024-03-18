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
STATICIP=172.172.0.121                  # Auto set depend on docker network
IMAGE_BASE=                # Need if used Image is available
CONNAME=scanman                 # Default is the name of the configuration file folder
DEFAULT_NETWORK=ocrnetwork
"
  exit 0
}

#for checking
keydatfolder="setup/api_license.dat"

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

[ -e "${rootvolume}/${keydatfolder}" ] || {
  log-error "License does not exist"
  exit 1
}

[[ $IMAGE_BASE ]] && {
  log-info "Use available Image Base ${IMAGE_BASE}"
} || {
  log-info "Downloading new image ..."
  curl -s -L "${URLIMAGE}" -o "rkkcs.tar.zip"
  unzip -P "${IMAGE_PASSWORD}" "rkkcs.tar.zip"
  rm -f "rkkcs.tar.zip"

  log-info "Loadding new image ..."
  IMAGE_BASE="$(docker load -i *.tar 2>&1)"
  IMAGE_BASE=$(echo "$IMAGE_BASE" | grep "Loaded image" | tail -n 1 | grep -iEoe "[\s]+$")
  #sed -i -e "s/^IMAGE_BASE=.*/IMAGE_BASE='${IMAGE_BASE}'/g" "${confpath}"
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
docker run  -idt -e P=1 --name $CONNAME --hostname $CONNAME --restart always \
-v "${rootvolume}/setup/alt.cpython-36m-x86_64-linux-gnu.so:/server/database/ocr/alt.cpython-36m-x86_64-linux-gnu.so" \
-v "${rootvolume}/setup/keys.txt:/server/api/apikey/keys.txt" \
-v "${rootvolume}/setup/KH5.json:/server/database/ocr/ocr_templates/db/KH5.json" \
-v "${rootvolume}/setup/api_license.dat:/server/api/authorization/license.dat" \
-v "${rootvolume}/setup/doc_type.cpython-36m-x86_64-linux-gnu.so:/server/database/ocr/doc_types/doc_type.cpython-36m-x86_64-linux-gnu.so" \
    --network "$NETNAME" ${STATICIP} "$IMAGE_BASE" /bin/bash -c "bash run.sh"
__
)

log-info "Docker command: ${dockerruncmd}"
eval "${dockerruncmd}"

echo "${dockerruncmd}" >"${confpath%/*}/docker-run-scanman.sh"
chmod 755 "${confpath%/*}/docker-run-scanman.sh"

# RESTART CONTAINER AND TEST API
#log-info "Restart the ${CONNAME} container to apply the URL configuration"
#docker restart "${CONNAME}"
#sleep 1

#Checking api
#[ -e "${rootvolume}/../imgstest/id-front.jpg" ] || {
#  log-warning "There is no photo in the path ${rootvolume}/../imgstest/id-front.jpg to test"
#  exit 1
#}
log-info "Checking api's ${CONNAME}..."

cnt=0
while :; do
  respone="$(curl -s --location --request POST "http://${STATICIP}/jphw/bbs/classification")"
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
