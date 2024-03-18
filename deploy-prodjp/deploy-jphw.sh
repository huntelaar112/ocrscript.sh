#!/bin/bash
source $(which logshell)
source $(which dsutils)

scanmanImage="jphw-10072023-ver-1.3.10"
rkkcsImage="scanman_classification_ver_0.9.1"
pathRkkcsImages="rkkcs/jphw-10072023-ver-1.3.10.tar"
pathScanmanImages="scanman/scanman_classification_ver_0.9.1.tar"
docker-image-is-exist ${rkkcsImage} || {
        log-info "Load rkkcs docker iamges..."
        docker load -i "${pathRkkcsImages}"
} && log-info "$rkkcsImage images is exist"

 docker-image-is-exist "${scanmanImage}" || {
        log-info "Load scanman docker images..."
        docker load -i "${pathScanmanImages}"
} && log-info "$scanmanImage images is exist"

log-info "Deploy scanman api..."
./scanman/deploy-scanman.sh ./scanman/config.env
[[ $? == 0 ]] && {
        log-info "Done deploy scanman, ready to port though nginxproxy"
}

log-info "Deploy rkkcs api..."
./rkkcs/deploy-rkkcs.sh ./rkkcs/config.env
[[ $? == 0 ]] && {
        log-info "Done deploy rkkcs, ready to port though nginxproxy"
}