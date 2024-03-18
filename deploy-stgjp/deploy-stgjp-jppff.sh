#!/bin/bash

set -e
done=no
confpath="${1}"
EXITEVAL=""
[[ $confpath = "-h" ]] && {
  echo "config file reference:
NOROLLBACK=yes
URLIMAGE=       # Must have If you do not use IMAGE_BASE available
IMAGE_PASSWORD= # Depends on URLIMAGE
NETNAME=        # Default ocrnetowrk -> bridge
MONGO_HOST=     # Must have
MONGO_PWD=      # Must have
STATICIP=172.172.0.11
IMAGE_BASE=     # Need if used Image is available
CONNAME=jppff        # Default is the name of the configuration file folder
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
source "${confpath}"
[[ $STATICIP ]] && STATICIP="--ip $STATICIP"
conpathdirname="${confpath%/*}"
conpathdirname="${conpathdirname##*/}"
# workdir="${workdir:-/home/stackops/HCM/}"
# IMAGE_PASSWORD=
# rootvolume=
temdir="$(mktemp -d)"
log-info "Temporary folder: ${temdir}"

function cleanup() {
  # rm -rf '${temdir}'
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

#sync first time deploy
#log-warning "Synchronize data from old deploy configuration..."
#rsync -xaXASH /data/saveimages/jppff/ "${rootvolume}/../saved_images/"
#rsync -xaXASH /data/logs/jppff/ "${rootvolume}/../app_log/"

[ -e "${rootvolume}/license/api/license.dat" ] || {
  log-error "License does not exist"
  exit 1
}

[[ $IMAGE_BASE ]] && {
  log-info "Use available Image Base ${IMAGE_BASE}"
} || {
  log-info "Downloading new image ..."
  curl -s -L "${URLIMAGE}" -o "image.tar.zip"
  unzip -P "${IMAGE_PASSWORD}" "image.tar.zip"
  rm -f "image.tar.zip"

  log-info "Loadding new image ..."
  IMAGE_BASE="$(docker load -i *.tar 2>&1)"
  echo "IMAGE_BASE: ${IMAGE_BASE}"
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

# khong cau  hinh API-KEY --> rong
#[ -e "${rootvolume}/keys.txt" ] || touch "${rootvolume}/keys.txt"

# mount table reconstruction
#[[ -e "${rootvolume}/table_reconstruction" ]] && {
# log-info "Update db ini file / server/modules/module_so/table_reconstruction ..."
# docker cp "${rootvolume}/table_reconstruction"  "${CONNAME}:/server/modules/module_so/"
#  DOCKEROPTS+=" -v ${rootvolume}/table_reconstruction:/server/modules/module_so/table_reconstruction"
#}

# mount dont_key
#altso=$(find "${rootvolume}/" -maxdepth 1 -mindepth 1 -iname "alt*linux-gnu.so" | sort -r | head -n 1)
#[[ -e "${altso}" ]] && {
# log-info "Update db ini file /server/database/ocr/${altso##*/} ..."
# docker cp "${altso}"  "${CONNAME}:/server/database/ocr/"
#  DOCKEROPTS+=" -v ${altso}:/server/database/ocr/${altso##*/}"
#}

# create and mount doc_type.py
#[[ -e "${rootvolume}/doc_type.py" ]] && {
#  newver=$(echo "${IMAGE_BASE}" | grep -ioEe "[\.0-9]+" | grep '\.')
#  log-info "Update name version to ${newver}"
#  # sed -i -e '/"version"/c "version":"'"${newver}\"" "${rootvolume}/templatedb/ocr/doc_types/doc_type.py"
#  sed -i -e '/"version"/c "version":"'"${newver}\"" "${rootvolume}/doc_type.py"
#  DOCKEROPTS+=" -v ${rootvolume}/doc_type.py:/server/database/ocr/doc_types/doc_type.py"
#}

#DOCKEROPTS include table_reconstruction, dont_key, doc_type.py, api.ini
# DATA MOUNT TO CONTAINER
# 1. saved_images : /server/saved_images
# 2. app_log: /server/logs
# 3. license api: /server/api/authorization/license.dat                                      #update
# 4. license soc: /server/modules/module_so/soc/core/authorization/license.dat               #update
# 5. keys.txt:  ?? key customer
# 6 blacklist: /server/api/authorization/black_list/black_list.txt                           #update
# 7. connect  to mysql: db.ini : /server/database/serv/db.ini     ?? config db
# in DOCKEROPTS
# 6. config api vnpff:  api.ini : /server/api/configs/api.ini                                #update
# 7. table_reconstruction:  /server/modules/module_so/table_reconstruction                   #update
# 8. dont_key: alt*linux-gnu.so /server/database/ocr/alt.cpython-36m-x86_64-linux-gnu.so     #update
# 9. doc_type.py: ?? --> bo? --> embed to container /server/database/ocr/doc_types/doc_type.py
# copy
# 10. customer template: /server/database/ocr/ocr_templates/db/cloud                         #update

dockerruncmd=$(
  cat <<__
docker run -idt -e P=1 --name $CONNAME --hostname $CONNAME \
-v "${rootvolume}/license/api/license.dat:/server/api/authorization/license.dat" \
-v "${rootvolume}/license/soc/license.dat:/server/modules/module_so/soc/core/authorization/license.dat" \
-v "${rootvolume}/configs/api.ini:/server/api/configs/api.ini" \
-v "${rootvolume}/apikey/keys.txt:/server/api/apikey/keys.txt" \
-v "${rootvolume}/two_way_authentication/private_key.pem:/server/api/two_way_authentication/private_key.pem" \
-v "${rootvolume}/black_list/black_list.txt:/server/api/authorization/black_list/black_list.txt" \
-v "${rootvolume}/template/:/server/database/ocr/ocr_templates/db/" \
-v "${rootvolume}/alt/alt.cpython-36m-x86_64-linux-gnu.so:/server/database/ocr/alt.cpython-36m-x86_64-linux-gnu.so" \
-v "${rootvolume}/TR_LORE_1012:/src/modules/module_so/soc/core/table_reconstruction/jp_table_reconstruction" \
-v "${rootvolume}/../saved_images:/server/saved_images" \
-v "${rootvolume}/../app_log:/server/logs" \
    --network "$NETNAME" ${STATICIP} "$IMAGE_BASE"
__
)
# bash -c "cd /server/ && ./run.sh"
log-info "Docker command: ${dockerruncmd}"
eval "${dockerruncmd}"

echo "${dockerruncmd}" >"${confpath%/*}/docker-run.sh"
chmod 755 "${confpath%/*}/docker-run.sh"

log-info "Restart the ${CONNAME} container"
docker restart "${CONNAME}"
sleep 1

#TEST API
[ -e "${rootvolume}/../imgstest/image.jpg" ] || {
  log-warning "There is no photo in the path ${rootvolume}/../imgstest/image.jpg to test"
  exit 1
}

log-info "Checking api's ${CONNAME}..."
cnt=0
while :; do
  respone="$(curl -s --location --request POST 'https://jpffstg.smartocr.net/jppff/v1/recognition' \
    --header 'Authorization: 	gAAAAABhwZER6E-IR0qTPfxr1NmWWFg8mwN1Nd1v2YXmsYDFStF35AIHBF3vBJIYI8SG8HgIKqWDx9yrrKIKq9WQCvYg65-oYD58pSTjKZC2kb8mhaVu9wpeKWp6mpDqczSggfmU4mmrbWt_zN2OGzAvcrIXu6o51A==' \
    --form "file=@\"${rootvolume}/../imgstest/image.jpg\"")"
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
# curl -X POST 172.172.0.9/jppff/v1/recognition