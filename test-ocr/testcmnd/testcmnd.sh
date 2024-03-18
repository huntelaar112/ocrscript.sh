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
curl -i  --location --request POST 'https://tempprod.smartocr.vn/idcard/v1/recognition' \
--header 'api-key: ${idfaceapikey}' \
--form 'image1=@"./0ba49547178bf566ad0b09d8e9f72de3__26092023_131257744183__front_1.dat.jpg"' \
--form 'image2=@"./0ba49547178bf566ad0b09d8e9f72de3__26092023_131257744183__backside_2.dat.jpg"' \
--form 'encode="1"'
__
)

touch ./result.log
#start caculate time
start=$(date +%s.%N)
[[ -z $idfaceapikey ]] && log-info "Request without api-key"
count=0
while :; do
  ((count = count + 1))
  eval "${cmdid}" >>./result.log &
  [[ -n $interval ]] && {
    echo ""
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

