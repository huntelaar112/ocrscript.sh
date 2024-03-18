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
STATICIP=                  # Auto set depend on docker network
IMAGE_BASE=                # Need if used Image is available
CONNAME=id                 # Default is the name of the configuration file folder
DEFAULT_NETWORK=ocrnetwork
"
	exit 0
}

keydatfolder="setup/license/api/key.dat"

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
# workdir="${workdir:-/home/stackops/HCM/}"

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

dockerruncmd=$(
	cat <<__
docker run --gpus "device=0" \
-idt -e P=1 --name $CONNAME --hostname $CONNAME --restart always -e LD_LIBRARY_PATH=/usr/local/cuda-11.7/lib64 \
-e TZ=Asia/Ho_Chi_Minh --privileged --ulimit core=0 \
-v "${rootvolume}/setup/config/id/:/workspace/setting/db_config" \
-v "${rootvolume}/setup/config/API/config.ini:/workspace/config/config.ini" \
-v "${rootvolume}/setup/license/api/key.dat:/workspace/key.dat" \
-v "${rootvolume}/setup/license/soc/license.dat:/workspace/id/Compare_CCCD/soc/core/authorization/license.dat" \
-v "${rootvolume}/setup/template/id/db:/workspace/config/template_id/db" \
-v "${rootvolume}/setup/logs/id1:/workspace/logs/app_log" \
    --network "$NETNAME" ${STATICIP} "$IMAGE_BASE"
__
)

log-info "Docker command: ${dockerruncmd}"
eval "${dockerruncmd}"

echo "${dockerruncmd}" >"${confpath%/*}/docker-run-id1.sh"
chmod 755 "${confpath%/*}/docker-run-id1.sh"

log-info "Restart the ${CONNAME} container to apply the URL configuration"
docker restart "${CONNAME}"
sleep 1

log-step "${CONNAME} is deployed"
