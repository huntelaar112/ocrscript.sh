#!/bin/bash

set -e
done=no
confpath="${1}"
EXITEVAL=""
[[ $confpath = "-h" ]] && {
  echo "Script deploy Face searching
  Use: sudo bash ./deploy-face-searching.sh face.env"
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
OCRNETWORK=pgbnetwork
docker-network-is-exist "${OCRNETWORK}" || {
  log-step "Add new network ${OCRNETWORK}: ${OCRNETWORK_SUBNET}"
  docker-network-create $OCRNETWORK $OCRNETWORK_SUBNET
} || {
  [[ $(docker-network-get-cidr "${OCRNETWORK}") = "${OCRNETWORK_SUBNET}" ]] || {
    log-error "Error Subnet: ${OCRNETWORK}\n Remove ${OCRNETWORK} [docker network rm ${OCRNETWORK}] and run again"
    exit 1
  }
}

CONNAME="${CONNAME:-${conpathdirname}}"

[[ $NETNAME ]] || {
  docker-network-is-exist "${OCRNETWORK}" && NETNAME="${OCRNETWORK}" || NETNAME="bridge"
}

[[ $rootvolume ]] || rootvolume="${confpath%/*}"

[ -e "${rootvolume}/data/key/key.dat" ] || {
  log-error "License does not exist"
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

dockerruncmdface0=$(
  cat <<__
docker run -idt -e P=1 --name face0 --hostname face0 \
   -v "${rootvolume}/data/tool/log/:/workspace/tools/pgb_tool/logs/app_log/" \
   -v "${rootvolume}/data/tool/config/config.ini:/workspace/tools/pgb_tool/config/config.ini" \
   -v "${rootvolume}/data/config/pgb_api_config/config_url.ini:/workspace/face_recog/pgb_api/config_url.ini" \
   -v "${rootvolume}/data/config/api_config/face0/config.ini:/workspace/setting/api_config/config.ini" \
   -v "${rootvolume}/data/config/db_config/redis.ini:/workspace/setting/db_config/redis.ini" \
   -v "${rootvolume}/data/key/key.dat:/workspace/key.dat " \
   -v "${rootvolume}/data/logs/face0/app_log:/workspace/logs/app_log" \
   -v "${rootvolume}/data/saveimages:/workspace/saveimages/" \
    --network "$NETNAME" ${STATICIP}  "$IMAGE_BASE" bash -c "cd /workspace/ && ./run.sh"
__
)

dockerruncmdface1=$(
  cat <<__
docker run -idt -e P=1 --name face1 --hostname face1 \
   -v "${rootvolume}/data/tool/log/:/workspace/tools/pgb_tool/logs/app_log/" \
   -v "${rootvolume}/data/tool/config/config.ini:/workspace/tools/pgb_tool/config/config.ini" \
   -v "${rootvolume}/data/config/pgb_api_config/config_url.ini:/workspace/face_recog/pgb_api/config_url.ini" \
   -v "${rootvolume}/data/config/api_config/face1/config.ini:/workspace/setting/api_config/config.ini" \
   -v "${rootvolume}/data/config/db_config/redis.ini:/workspace/setting/db_config/redis.ini" \
   -v "${rootvolume}/data/key/key.dat:/workspace/key.dat " \
   -v "${rootvolume}/data/logs/face1/app_log:/workspace/logs/app_log" \
   -v "${rootvolume}/data/saveimages:/workspace/saveimages/" \
    --network "$NETNAME" ${STATICIP}  "$IMAGE_BASE" bash -c "cd /workspace/ && ./run.sh"
__
)

dockerruncmdface2=$(
  cat <<__
docker run -idt -e P=1 --name face2 --hostname face2 \
   -v "${rootvolume}/data/tool/log/:/workspace/tools/pgb_tool/logs/app_log/" \
   -v "${rootvolume}/data/tool/config/config.ini:/workspace/tools/pgb_tool/config/config.ini" \
   -v "${rootvolume}/data/config/pgb_api_config/config_url.ini:/workspace/face_recog/pgb_api/config_url.ini" \
   -v "${rootvolume}/data/config/api_config/face2/config.ini:/workspace/setting/api_config/config.ini" \
   -v "${rootvolume}/data/config/db_config/redis.ini:/workspace/setting/db_config/redis.ini" \
   -v "${rootvolume}/data/key/key.dat:/workspace/key.dat " \
   -v "${rootvolume}/data/logs/face2/app_log:/workspace/logs/app_log" \
   -v "${rootvolume}/data/saveimages:/workspace/saveimages/" \
    --network "$NETNAME" ${STATICIP}  "$IMAGE_BASE" bash -c "cd /workspace/ && ./run.sh"
__
)

dockerruncmdface3=$(
  cat <<__
docker run -idt -e P=1 --name face3 --hostname face3 \
   -v "${rootvolume}/data/tool/log/:/workspace/tools/pgb_tool/logs/app_log/" \
   -v "${rootvolume}/data/tool/config/config.ini:/workspace/tools/pgb_tool/config/config.ini" \
   -v "${rootvolume}/data/config/pgb_api_config/config_url.ini:/workspace/face_recog/pgb_api/config_url.ini" \
   -v "${rootvolume}/data/config/api_config/face3/config.ini:/workspace/setting/api_config/config.ini" \
   -v "${rootvolume}/data/config/db_config/redis.ini:/workspace/setting/db_config/redis.ini" \
   -v "${rootvolume}/data/key/key.dat:/workspace/key.dat " \
   -v "${rootvolume}/data/logs/face3/app_log:/workspace/logs/app_log" \
   -v "${rootvolume}/data/saveimages:/workspace/saveimages/" \
    --network "$NETNAME" ${STATICIP}  "$IMAGE_BASE" bash -c "cd /workspace/ && ./run.sh"
__
)

dockerruncmdface4=$(
  cat <<__
docker run -idt -e P=1 --name face4 --hostname face4 \
   -v "${rootvolume}/data/tool/log/:/workspace/tools/pgb_tool/logs/app_log/" \
   -v "${rootvolume}/data/tool/config/config.ini:/workspace/tools/pgb_tool/config/config.ini" \
   -v "${rootvolume}/data/config/pgb_api_config/config_url.ini:/workspace/face_recog/pgb_api/config_url.ini" \
   -v "${rootvolume}/data/config/api_config/face4/config.ini:/workspace/setting/api_config/config.ini" \
   -v "${rootvolume}/data/config/db_config/redis.ini:/workspace/setting/db_config/redis.ini" \
   -v "${rootvolume}/data/key/key.dat:/workspace/key.dat " \
   -v "${rootvolume}/data/logs/face4/app_log:/workspace/logs/app_log" \
   -v "${rootvolume}/data/saveimages:/workspace/saveimages/" \
    --network "$NETNAME" ${STATICIP}  "$IMAGE_BASE" bash -c "cd /workspace/ && ./run.sh"
__
)

dockerruncmdface5=$(
  cat <<__
docker run -idt -e P=1 --name face5 --hostname face5 \
   -v "${rootvolume}/data/tool/log/:/workspace/tools/pgb_tool/logs/app_log/" \
   -v "${rootvolume}/data/tool/config/config.ini:/workspace/tools/pgb_tool/config/config.ini" \
   -v "${rootvolume}/data/config/pgb_api_config/config_url.ini:/workspace/face_recog/pgb_api/config_url.ini" \
   -v "${rootvolume}/data/config/api_config/face5/config.ini:/workspace/setting/api_config/config.ini" \
   -v "${rootvolume}/data/config/db_config/redis.ini:/workspace/setting/db_config/redis.ini" \
   -v "${rootvolume}/data/key/key.dat:/workspace/key.dat " \
   -v "${rootvolume}/data/logs/face5/app_log:/workspace/logs/app_log" \
   -v "${rootvolume}/data/saveimages:/workspace/saveimages/" \
    --network "$NETNAME" ${STATICIP}  "$IMAGE_BASE" bash -c "cd /workspace/ && ./run.sh"
__
)

log-info "Docker command: ${dockerruncmdface0}"
eval "${dockerruncmdface0}"
echo "${dockerruncmdface0}" >"${confpath%/*}/docker-run-face0.sh"
chmod 755 "${confpath%/*}/docker-run-face0.sh"

log-info "Docker command: ${dockerruncmdface1}"
eval "${dockerruncmdface1}"
echo "${dockerruncmdface1}" >"${confpath%/*}/docker-run-face1.sh"
chmod 755 "${confpath%/*}/docker-run-face1.sh"

log-info "Docker command: ${dockerruncmdface2}"
eval "${dockerruncmdface2}"
echo "${dockerruncmdface2}" >"${confpath%/*}/docker-run-face2.sh"
chmod 755 "${confpath%/*}/docker-run-face2.sh"

log-info "Docker command: ${dockerruncmdface3}"
eval "${dockerruncmdface3}"
echo "${dockerruncmdface3}" >"${confpath%/*}/docker-run-face3.sh"
chmod 755 "${confpath%/*}/docker-run-face3.sh"

log-info "Docker command: ${dockerruncmdface4}"
eval "${dockerruncmdface4}"
echo "${dockerruncmdface4}" >"${confpath%/*}/docker-run-face4.sh"
chmod 755 "${confpath%/*}/docker-run-face4.sh"

log-info "Docker command: ${dockerruncmdface5}"
eval "${dockerruncmdface5}"
echo "${dockerruncmdface5}" >"${confpath%/*}/docker-run-face5.sh"
chmod 755 "${confpath%/*}/docker-run-face5.sh"

docker run --hostname face0 --name face0 -e P=1 \
  -v /mnt/containerdata/face/data/key/key.dat:/workspace/key.dat \
  -v /mnt/containerdata/face/data/config/api_config/face0/config.ini:/workspace/setting/api_config/config.ini \
  -v /mnt/containerdata/face/data/config/db_config/redis.ini:/workspace/setting/db_config/redis.ini \
  -v /mnt/containerdata/face/data/logs/face0/app_log/:/workspace/logs/app_log/ \
  -v /mnt/containerdata/face/data/tool/:/workspace/tools/pgb_tool/ \
  --network pgbnetwork -idt face_recognition-2.0.5-18062023
