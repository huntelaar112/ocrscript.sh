#!/bin/bash

set -e
done=no

service=$1
apikey=$2
calltime=$3

[[ $service == "-h" ]] && {
  echo "Use: test-ocrapi service name [api-key] [parallel calltime]
  service name: idstg/facestg/vnpffstg/vnhffstg
  parallel calltime: number of request call at a time.
#pgb: gAAAAABjKrxgRK7GoisJ60G4s22AgTGjInvpGpJV4wfHDgdQyPYIPXNVG4ImkP5wPRk35hmEZwFXDpM9L4t2VMvyQwVTKvMvLyi_oeOMuX-DGZebuw5KX_Q=
#9999: gAAAAABkDsp7xiSLPxhvikD105Bg-YJxl0vhyCSQ1zp-RHE6SMqoYhSc52iU-nzGu74Oe4_KpdxIjvL61FMlMH-1AN2xE_3TjKsWA1TqRxWjt_jKcHHKwSc=
"
  exit 0
}

source $(which logshell)

[[ -n "$calltime" ]] || {
  calltime=1
}

[[ "${service}" == "idstg" ]] && {
  cmd=$(
    cat <<__
  curl -v -s --location --request POST "https://stgapi.smartocr.vn/idfull/v1/recognition" \
--header "api-key: ${apikey}" \
--form "image1=@\"/mnt/containerdata/id/imgstest/id-front.jpg\"" --form "image2=@\"/mnt/containerdata/id/imgstest/id-back.jpg\"" --form 'encode=1'
__
  )
}

[[ "${service}" == "idprod" ]] && {
  cmd=$(
    cat <<__
  curl -v -s --location --request POST "https://gapi.smartocr.vn/idfull/v1/recognition" \
--header "api-key: ${apikey}" \
--form "image1=@\"/mnt/containerdata/id/imgstest/id-front.jpg\"" --form "image2=@\"/mnt/containerdata/id/imgstest/id-back.jpg\"" --form 'encode=1'
__
  )
}

[[ "${service}" == "facestg" ]] && {
  cmd=$(
    cat <<__
curl -v -s --location --request POST "https://stgapi.smartocr.vn/face/v1/recognition" \
--header "api-key: ${apikey}" \
--form "image1=@\"/mnt/containerdata/face/imgstest/face1.jpg\"" --form "image2=@\"/mnt/containerdata/face/imgstest/face2.jpg\"" --form 'encode=1'
__
  )
}

[[ $service == "vnpffstg" ]] && {
  cmd=$(
    cat <<__
  curl -v -s --location --request POST "https://stgapi.smartocr.vn/vnpff/v1/recognition" \
--header "api-key: ${apikey}" \
--form "image=@\"/mnt/containerdata/vnpff/imgstest/image.jpg\""
__
  )
}

[[ $service == "vnhffstg" ]] && {
  cmd=$(
    cat <<__
  curl -v -s --location --request POST "https://stgapi.smartocr.vn/vnhff/v1/recognition" \
--header "api-key: ${apikey}" \
--form "image=@\"/mnt/containerdata/vnhff/imgstest/image.jpg\""
__
  )
}

[[ -z ${cmd} ]] && {
  log-error "Service name is not support"
  exit 1
}

#start caculate time
start=$(date +%s.%N)
[[ -z $apikey ]] && log-info "Request without api-key"
count=0
while :; do
  ((count = count + 1))
  eval "${cmd}" &
  [[ $count -eq $calltime ]] && break
done

log-info "Command request call: ${cmd}"
#echo $result | grep "X-App-Request-Id"
end=$(date +%s.%N)

runtime=$(echo "$end - $start" | bc -l)
log-info "Time from request to receive response is ${runtime} seconds."

done=yes
