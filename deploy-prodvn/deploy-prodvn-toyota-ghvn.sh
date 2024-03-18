#!/bin/bash                                                                                                                                                                                                       
                                                                                                                                                                                                                  
set -e                                                                                                                                                                                                            
done=no                                                                                                                                                                                                           
confpath="${1}"                                                                                                                                                                                                   
EXITEVAL=""
# ExtOrcP!20212GPU

[[ $confpath = "-h" ]] && {
  echo "config file reference:
NOROLLBACK=no
URLIMAGE=                  # Must have If you do not use IMAGE_BASE available
IMAGE_PASSWORD=            # Depends on URLIMAGE
NETNAME=                   # Default ocrnetowrk -> bridge
MONGO_HOST=172.18.0.17     # Must have
MONGO_PWD=123456           # Must have
STATICIP=172.172.0.104
IMAGE_BASE=                # Need if used Image is available
CONNAME=ghvn                 # Default is the name of the configuration file folder
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

#docker inspect -f "{{ .Mounts }}" face

#sync old data
[ ! -e "${rootvolume}/license.dat" ] && [ -e /mnt/containerdata/ghvn/v1.0.1/license.dat ] && {
  log-warning "Synchronize data from old deploy configuration..."
  rsync -xaXASH /mnt/containerdata/ghvn/v1.0.1/license.dat "${rootvolume}/license.dat" #license_api.dat
  rsync -xaXASH /mnt/containerdata/ghvn/v1.0.1/db.ini "${rootvolume}/db.ini"           # mysql config
  rsync -xaXASH /mnt/containerdata/ghvn/v1.0.1/api.ini "${rootvolume}/api.ini"
  rsync -xaXASH /mnt/containerdata/ghvn/v1.0.1/alt.cpython-36m-x86_64-linux-gnu.so "${rootvolume}/alt.cpython-36m-x86_64-linux-gnu.so" # templare
  rsync -xaXASH /mnt/containerdata/ghvn/v1.0.1/template/ "${rootvolume}/template/"
  #rsync -xaXASH /data/apikey/keys.txt "${rootvolume}/"      #api key
  #rsync -xaXASH /data/logs/id/ "${rootvolume}/../app_log/"
}

[ -e "${rootvolume}/license.dat" ] || {
  log-error "License does not exist"
  exit 1
}

: '
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


{ [ ! -e "${rootvolume}/db_config/mongo.ini" ] || [[ ! $(cat "${rootvolume}/db_config/mongo.ini") ]]; } && {
  [[ $mongoconf ]] && {
    mkdir "${rootvolume}/db_config"
    echo "$mongoconf" >"${rootvolume}/db_config/mongo.ini"
  } || {
    log-error "Lack of configuration MongoDB: '${rootvolume}/db_config/mongo.ini'"
    exit 1
  }
}

timeout 0.5 bash -c "cat < /dev/null > /dev/tcp/${MONGO_HOST}/27017" || {
  log-error "Mongodb server is down"
  exit 1
}
'

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
#[ -e "${rootvolume}/keys.txt" ] || touch "${rootvolume}/keys.txt"
dockerruncmd=$(
  cat <<__
docker run -idt -e P=1 --name $CONNAME --hostname $CONNAME \
-v "${rootvolume}/db.ini:/server/database/serv/db.ini" \
-v "${rootvolume}/template/:/server/database/ocr/ocr_templates/db/" \
-v "${rootvolume}/alt.cpython-36m-x86_64-linux-gnu.so:/server/database/ocr/alt.cpython-36m-x86_64-linux-gnu.so" \
-v "${rootvolume}/api.ini:/server/api/configs/api.ini" \
-v "${rootvolume}/license.dat:/server/api/authorization/license.dat" \
-v "${rootvolume}/../logs:/server/logs" \
-v "${rootvolume}/../saveimages:/server/saveimages" \
    --network "$NETNAME" ${STATICIP} "$IMAGE_BASE" bash -c "cd /server/ && chmod 755 run.sh && ./run.sh"
__
)

log-info "Docker command: ${dockerruncmd}"
eval "${dockerruncmd}"

echo "${dockerruncmd}" >"${confpath%/*}/docker-run.sh"
chmod 755 "${confpath%/*}/docker-run.sh"

#add test api_cod_block if needed

done=yes
# URLIMAGE=
