#!/bin/bash

#stop if any command fail (return !0 for OS)
set -e

confpath="${1}"
EXITEVAL=""
[[ $confpath = "-h" ]] && {
  echo "config file reference:
NOROLLBACK=yes
URLIMAGE=       # Must have If you do not use IMAGE_BASE available
IMAGE_PASSWORD= # Depends on URLIMAGE
NETNAME=        # Default ocrnetowrk -> bridge
MONGO_HOST=     # 
MONGO_PWD=      #
STATICIP=
IMAGE_BASE=     # Need if used Image is available
CONNAME=jphff        # Default is the name of the configuration file folder

Use: ${0} config.env
"
  exit 0
}

# load shell libs in /bin
source "$(which logshell)"
source "$(which dsutils)"

# check if config file is exist
[ -e "$confpath" ] || {
  log-error "File configuration does not exist"
  exit 1
}

#load config file
confpath=$(realpath "${confpath}")
source "${confpath}"

# static IP option use for docker run
[[ $STATICIP ]] && STATICIP="--ip $STATICIP"

# get current path location
conpathdirname="${confpath%/*}"
conpathdirname="${conpathdirname##*/}"

# make temp dir in /tmp
temdir="$(mktemp -d)"
log-info "Temporary folder: ${temdir}"

# remove temp dir when exit scriptdone=no
# if EXITEVAL = roolback, run rool back function
function cleanup() {
  rm -rf "${temdir}"
  [[ $EXITEVAL ]] && eval "${EXITEVAL}"
}
trap cleanup EXIT

cd "${temdir}"

# check if docker network ocrnetwork is existed, if not, create it.
OCRNETWORK_SUBNET=172.17.0.0/16
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

# if CONNAME is not exist, set default CONNAME is current directory name. 
CONNAME="${CONNAME:-${conpathdirname}}"

# roolback function: enable by set NOROLLBACK=no
# remove con, rename con.old --> con, start con
function roolback() {
  [[ $NOROLLBACK = yes ]] && {
    log-error "Skip roll back"
    exit 1
  }
  docker-container-is-exist "${CONNAME}.old" && {
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

# set default network for docker run is bridge if NETNAME="" (config file)
[[ $NETNAME ]] || {
  docker-network-is-exist "${OCRNETWORK}" && NETNAME="${OCRNETWORK}" || NETNAME="bridge"
}

# get directory have config file.
[[ $rootvolume ]] || rootvolume="${confpath%/*}"

#sync first time deploy
#log-warning "Synchronize data from old deploy configuration..."
#rsync -xaXASH /data/saveimages/jphff/ "${rootvolume}/../saved_images/"
#rsync -xaXASH /data/logs/jphff/ "${rootvolume}/../app_log/"

# check if license of app is exist 
[ -e "${rootvolume}/setup/license/api/license.dat" ] || {
  log-error "License does not exist"
  exit 1
}

[[ $IMAGE_BASE ]] && {
  log-info "Use available Image Base ${IMAGE_BASE}"
} || {
  log-info "Downloading new image ..."done=no
  #curl -s -L "${URLIMAGE}" -o "image.tar.zip"
  wget -O "image.tar.zip" "${URLIMAGE}"
  unzip -P "${IMAGE_PASSWORD}" "image.tar.zip"
  rm -f "image.tar.zip"

  log-info "Loadding new image ..."
  IMAGE_BASE="$(docker load -i *.tar 2>&1)"
  echo "IMAGE_BASE: ${IMAGE_BASE}"
  IMAGE_BASE=$(echo "$IMAGE_BASE" | grep "Loaded image" | tail -n 1 | grep -iEoe "[\s]+$")
  sed -i -e "s/^IMAGE_BASE=.*/IMAGE_BASE='${IMAGE_BASE}'/g" "${confpath}"
}

# have to manualy remove con.old before deploy new
[[ $IMAGE_BASE ]] && log-info "New image (${IMAGE_BASE}) has been loaded"
docker-container-is-exist "${CONNAME}.old" && {
  docker-container-is-exist "${CONNAME}" && {
    log-warning "Backup container has existed ${CONNAME}.old. Delete containers ${CONNAME}"
    docker rm -f "${CONNAME}"
  }
} || {
  docker-container-is-exist "${CONNAME}" && {
    log-warning "Rename container $CONNAME -> ${CONNAME}.old"
    docker rename "${CONNAME}" "${CONNAME}.old" &>/dev/null
    docker-container-is-running "${CONNAME}.old" && docker stop "${CONNAME}.old"
    EXITEVAL="roolback"
  }
}

# stop if both STATICIP exist and NETNAME = bridge
[[ $STATICIP ]] && [[ $NETNAME = bridge ]] && {
  log-error "User specified IP (${STATICIP}) address is supported on user defined networks only"
  exit 1
}


dockerruncmd=$(
  cat <<__
docker run -idt -e P=1 --name $CONNAME --hostname $CONNAME --restart always \
-v "${rootvolume}/setup/license/api/license.dat:/server/api/authorization/license.dat" \
-v "${rootvolume}/setup/license/soc/license.dat:/server/modules/module_so/soc/core/authorization/license.dat" \
-v "${rootvolume}/setup/configs/api.ini:/server/api/configs/api.ini" \
-v "${rootvolume}/setup/apikey/keys.txt:/server/api/apikey/keys.txt" \
-v "${rootvolume}/setup/black_list/black_list.txt:/server/api/authorization/black_list/black_list.txt" \
-v "${rootvolume}/setup/template/:/server/database/ocr/ocr_templates/db/" \
-v "${rootvolume}/setup/alt/alt.cpython-36m-x86_64-linux-gnu.so:/server/database/ocr/alt.cpython-36m-x86_64-linux-gnu.so" \
-v "${rootvolume}/setup/run.sh:/server/run.sh" \
-v "${rootvolume}/setup/two_way_authentication/private_key.pem:/server/api/two_way_authentication/private_key.pem" \
-v "${rootvolume}/setup/correct/correct.yaml:/server/modules/correct/correct.yaml" \
-v "${rootvolume}/../saved_images:/server/saveimages" \
-v "${rootvolume}/../app_log:/server/logs" \
    --network "$NETNAME" ${STATICIP} "$IMAGE_BASE" bash -c "cd /server/ && chmod 777 run.sh && ./run.sh"
__
)

log-info "Docker command: ${dockerruncmd}"
eval "${dockerruncmd}"

echo "${dockerruncmd}" >"${confpath%/*}/docker-run.sh"
chmod 755 "${confpath%/*}/docker-run.sh"
sleep 1

#TEST API
[ -e "${rootvolume}/../imgstest/image.jpg" ] || {
  log-warning "There is no photo in the path ${rootvolume}/../imgstest/image.jpg to test"
  exit 1
}


sleep 5
log-info "Checking api's ${CONNAME}..."
cnt=0
while :; do
  respone="$(curl -s --location --request POST 'https://jpcapi.smartocr.net/jphff/v1/recognition' \
    --header 'Authorization:    token???' \
    --form "file=@\"${rootvolume}/../imgstest/image.jpg\"")"
  ((cnt = cnt + 1))
  echo "${respone}" | grep -Ee '"result_code"' && {
    log-info "Success calls API to new containers"
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
