#!/bin/bash

set -e
done=no

source ./logshell

calltime=$1
interval=$2

[[ $calltime -lt 1 ]] && {
  log-error "Need time test"
  exit 1
}

idfaceapikey=$(cat ./cmnd.token)

cmdid=$(
  cat <<__
curl -i --location --request POST 'https://stgapi.smartocr.vn/idfull/v1/recognition' \
--header 'api-key: ${idfaceapikey}' \
--form 'image1=@"./CMND_moi_fs.jpg"' \
--form 'image2=@"./CMND_moi_bs.jpg"' \
--form 'encode="1"'
__
)

touch ./testResult.log
#start caculate time
start=$(date +%s.%N)
[[ -z $idfaceapikey ]] && log-info "Request without api-key"
count=0
while :; do
  ((count = count + 1))
  eval "${cmdid}" >>./testResult.log &
  [[ -n $interval ]] && {
    echo "Sleep $interval seconds"
    sleep $interval
  }

  [[ $count -eq $calltime ]] && break
done
wait

log-info "Command request call: ${cmdid}"
#echo $result | grep "X-App-Request-Id"
end=$(date +%s.%N)

runtime=$(echo "$end - $start" | bc -l)
log-info "Time from request to receive response is ${runtime} seconds."

done=yes
