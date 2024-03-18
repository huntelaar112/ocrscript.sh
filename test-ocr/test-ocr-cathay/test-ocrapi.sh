#!/bin/bash

set -e
done=no

source ./logshell

serviceTest=$1

cmdid=$(
  cat <<__
curl --location '10.1.21.52:8081/idfull/v1/recognition' \
--header 'api-key: a08eb42a-4a57-449b-84f4-1f67219f2679' \
--form 'image1=@"./id1.jpg"' \
--form 'image2=@"./id2.jpg"' \
--form 'encode="1"'
__
)

cmddkx=$(
  cat <<__
curl --location '10.1.21.52:8080/dkx_vn/v1/recognition' \
--header 'Authorization: Bearer eyJhbGciOiJSU0ExXzUiLCJlbmMiOiJBMjU2R0NNIiwia2lkIjoiMTQwNjIwMjEifQ.R8pyhGbedoSEeq0IEaGvqxoq5vNcO7lmHUFFtDndwIhHQwPV776tA5CiCZyWNLtgGl1XVP6vDwbNq6da1s9q9KcOqW4MrnNXDWvQoDBDqrR_hLs8YB7l0U5LO1L1DL6gX2R4JJ-60yoGfQp7m2cgsfgV_5iw7sQemAfcfsNpLsKYpY8xDh5zZoZ4iqFa8PPmp7LoV1y_xIjK0eentipyTgclefBH8H3gg6CESZNmpqep3o5R7-BkrW-c3GvapUhdabdpC-35AbEoiej9qCnovBZMInzBjvJMPrcJ0DVbc1EZ4FjO06Nk2r5DMUvdYv4G7fdRnBmG6-J29EX_A1jINQ.EcDc2Cpyfrb6a91nCpiL6w.6RaFHYmDnIdOl_FJ-aiGUaR0pkY7HZLB0v_sLUuuG1ZPCaRE6jZW2Wh1LjSE8MHgfpjyjLCEEHOEgxjZcJg0zWo.NnWHvfOBnSxru_hFW2qoGA' \
--form 'image1=@"./cv1.jpg"' \
--form 'image2=@"./cv2.jpg"'
__
)

#start caculate time
start=$(date +%s.%N)
[[ ${serviceTest} == "id" ]] && {
  eval "${cmdid}" &
} || {
  eval "${cmddkx}" &
}
wait

[[ ${serviceTest} == "id" ]] && {
  log-info "Command request call: ${cmdid}"
} || {
  log-info "Command request call: ${cmddkx}"
}
wait

#echo $result | grep "X-App-Request-Id"
end=$(date +%s.%N)

runtime=$(echo "$end - $start" | bc -l)
log-info "Time from request to receive response is ${runtime} seconds."

done=yes
