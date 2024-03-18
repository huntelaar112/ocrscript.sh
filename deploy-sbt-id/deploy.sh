#!/bin/bash

source $(which logshell)
source $(which dsutils)

log-step "Download id api image..."
currentdir=$(pwd)
img="idall-1.2.6-15112023_gpu"

docker-image-is-exist "${img}" && {
  log-info "Docker image already exist already exist."
} || {
  cd /tmp
  wget -O id.zip https://www.dropbox.com/scl/fi/cnyy01m0gn4k1azoouc4o/idall-1.2.6-15112023_gpu.tar.zip?rlkey=9qr09om1lyrukf11u1u6un15a && \
  unzip -P idall12615112023gpu id.zip && \
  docker load -i idall-1.2.6-15112023_gpu.tar
  [[ $? == 0 ]] && {
    log-info "Done load docker image: ${img}"
  } || {
    log-err "Fail to load image ${img}"
    exit 1
  }
}

#docker-container-is-exist "id0.oldversion" || {
#  docker rename id0 id0.oldversion
#  docker rename id1 id1.oldversion
#}

cd "${currentdir}"
[[ ! -d ./setup ]] && {
  unzip setup.zip
}
docker rm id0.old || :
docker rm id1.old || :
./deploy-id1.sh id0.env
./deploy-id0.sh id1.env

sleep 5
log-step "Update container restart rules to always restart."
docker update --restart=always $(docker ps -q)
docker update --restart=no $(docker ps --filter status=exited -q)
log-step "Wait 5 minutes until id api started..."
log-info "First two requests to id api will response time out (504) because id api take time to load model."
sleep 300
