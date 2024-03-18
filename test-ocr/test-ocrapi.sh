#!/bin/bash

set -e
done=no

source $(which logshell)

calltime=$1

[[ $calltime -lt 1 ]] && {
  log-error "Need time test"
  exit 1
}

idfaceapikey=$(cat ./CMND-FACE.txt)
vnpffapikey=$(cat ./VNPFF.txt)

cmdid=$(
  cat <<__
curl -i --location --request POST 'https://gapi.smartocr.vn/idfull/v1/recognition' \
--header 'api-key: ${idfaceapikey}' \
--form 'image1=@"./CMND_moi_fs.jpg"' \
--form 'image2=@"./CMND_moi_bs.jpg"' \
--form 'encode="1"'
__
)

cmdface=$(
  cat <<__
curl -i --location --request POST 'https://gapi.smartocr.vn/face/v1/recognition' \
--header 'api-key: ${idfaceapikey}' \
--form 'image1=@"./biden1.jpeg"' \
--form 'image2=@"./biden2.jpeg"'
__
)

cmdvnpff=$(
  cat <<__
curl --location 'https://gapi.smartocr.vn/vnpff/v1/recognition' \
--header 'Authorization: Bearer ${vnpffapikey}' \
--form 'file=@"./unit_test_data_test_file_2-5.png"' \
--form 'options=@"./options.json"'
__
)

#start caculate time
start=$(date +%s.%N)
[[ -z $idfaceapikey ]] && log-info "Request without api-key"
count=0
while :; do
  ((count = count + 1))
  eval "${cmdid}" &
  eval "${cmdface}" &
  eval "${cmdvnpff}" &
  [[ $count -eq $calltime ]] && break
done
wait

log-info "Command request call: ${cmdid}"
log-info "Command request call: ${cmdface}"
log-info "Command request call: ${cmdvnpff}"
#echo $result | grep "X-App-Request-Id"
end=$(date +%s.%N)

runtime=$(echo "$end - $start" | bc -l)
log-info "Time from request to receive response is ${runtime} seconds."

done=yes
