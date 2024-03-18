#!/bin/bash

set -e
done=no
confpath="${1}"
EXITEVAL=""
[[ $confpath = "-h" ]] && {
  echo "config file reference:
NOROLLBACK=yes
URLIMAGE=       # Must have If you do not use IMAGE_BASE available
IMAGE_PASSWORD= # Depends on URLIMAGE0
NETNAME=        # Default ocrnetowrk -> bridge
MONGO_HOST=     # Must have
MONGO_PWD=      # Must have
STATICIP=
IMAGE_BASE=     # Need if used Image is available
CONNAME=vnpff        # Default is the name of the configuration file folder
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

#sync old data
#[ ! -e "${rootvolume}/license_soc.dat" ] && [ -e /data/license/soc/license_soc.dat ] && {
#  log-warning "Synchronize data from old deploy configuration..."
#rsync -xaXASH /data/template/vnhff/database/ "${rootvolume}/templatedb/" # templare V
#rsync -xaXASH /data/saveimages/vnhff/ "${rootvolume}/saved_images/"      #V
#  rsync -xaXASH /data/logs/vnhff/ "${rootvolume}/app_log/" #v
# rsync -xaXASH /data/license/license_prod/license.dat "${rootvolume}/license_api.dat" #V
# rsync -xaXASH /data/license/soc/license.dat "${rootvolume}/license_soc.dat" #V
#}

[ -e "${rootvolume}/data/PRODVN/PRODVN-API/license.dat" ] || {
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

#create and mount api.ini
#[[ -e "${rootvolume}/api.ini" ]] && {
#  DOCKEROPTS+=" -v ${rootvolume}/api.ini:/server/api/configs/api.ini"
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
nvidia-docker run -e CUDA_VISIBLE_DEVICES=1 -idt -e P=1 --name $CONNAME --hostname $CONNAME \
-v "${rootvolume}/data/db.ini:/server/database/serv/db.ini" \
-v "${rootvolume}/data/api.ini/:/server/api/configs/api.ini" \
-v "${rootvolume}/data/keys.cpython-36m-x86_64-linux-gnu.so:/server/api/apikey/keys.cpython-36m-x86_64-linux-gnu.so" \
-v "${rootvolume}/data/alt.cpython-36m-x86_64-linux-gnu.so/:/server/database/ocr/alt.cpython-36m-x86_64-linux-gnu.so" \
-v "${rootvolume}/data/PRODVN/PRODVN-SOC/license.dat/:/server/modules/module_so/soc/core/authorization/license.dat" \
-v "${rootvolume}/data/PRODVN/PRODVN-API/license.dat/:/server/api/authorization/license.dat" \
-v "${rootvolume}/../saved_images:/server/saved_images" \
-v "${rootvolume}/../app_log:/server/logs" \
    --network "$NETNAME" ${STATICIP} "$IMAGE_BASE" bash -c "cd /server/ && ./run.sh"
__
)

log-info "Docker command: ${dockerruncmd}"
eval "${dockerruncmd}"

#copy customer template --> need chane next version to mount
#pbcpu=$(find "${rootvolume}/" -type d -iname "pb-*" | sort -r | head -n 1)
#[[ -e "${pbcpu}" ]] && {
#  log-info "Update db ini files from  ${pbcpu} to ${CONNAME}:/server/database/ocr/ocr_templates/db/cloud/ ..."
#  docker exec -it "${CONNAME}" bash -c 'rm -rf /server/database/ocr/ocr_templates/db/cloud/*.ini'
#  for ini in "${pbcpu}"/*.ini; do
#    docker cp "${ini}" "${CONNAME}:/server/database/ocr/ocr_templates/db/cloud/"
#  done
#  docker exec -it "${CONNAME}" ls -lhas /server/database/ocr/ocr_templates/db/cloud/
#
#  #DOCKEROPTS+=" -v ${pbcpu}:/server/database/ocr/ocr_templates/db/cloud/"
#}

#copy doc_type
#[[ -e "${rootvolume}/doc_type.py" ]] && {
#  log-info "Remove doctype*.so"
#  docker exec -it "${CONNAME}" bash -c 'rm -rf /server/database/ocr/doc_types/*.so'
#}

echo "${dockerruncmd}" >"${confpath%/*}/docker-run.sh"
chmod 755 "${confpath%/*}/docker-run.sh"

log-info "Restart the ${CONNAME} container to apply the pb-* configuration"
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
  respone="$(curl -s --location --request POST 'https://gapi.smartocr.vn/vnpff/v1/recognition' \
    --header 'Authorization: Bearer gAAAAABjiaKPdEamxxUZDq7UUD5zGPKbRLSle3QF3KNpXUbu-aPOw3l4CIubQl5nDaxFYSFmAD5rYZxKftcHrQjBoaUnO4N8WLQN3Y_CmSpy820WbLoz8gQ=' \
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
#	https://tempprod.smartocr.vn/vnpff/v1/recognition
