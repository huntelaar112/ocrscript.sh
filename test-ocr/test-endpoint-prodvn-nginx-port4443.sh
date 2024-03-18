#!/bin/bash

set -e
done=no

listEndpoint=("https://gapi.smartocr.vn:4443/idfull/v1/recognition"
  "https://gapi.smartocr.vn:4443/idcard/v1/recognition"
  "https://tfv.smartocr.vn:4443/idcard/v1/recognition"
  "https://dgt.smartocr.vn:4443/idcard/v1/recognition"
  "https://dgt.smartocr.vn:4443/multiid/v1/recognition"
  #face
  "https://gapi.smartocr.vn:4443/face/v1/recognition"
  #"https://gapi.smartocr.vn:4443/pp/v1/recognition"
  #pp
  #"https://dgt.smartocr.vn:4443/pp/v1/recognition"
  "https://gapi.smartocr.vn:4443/pp/v1/recognition"
  #cmqdvn
  "https://gapi.smartocr.vn:4443/cqd/v1/recognition"
  #vnpff
  "https://gapi.smartocr.vn:4443/vnpff/v1/recognition"
  #ghvn
  "https://gapi.smartocr.vn:4443/ghvn/v1/recognition"
  #dkx,gh php
  "https://tfv.smartocr.vn:4443/vnpff/v1/recognition"
)

count=1
for i in ${listEndpoint[@]}; do
  echo "${count}: ${i}"
  ((count = count + 1))
  curl --location -X POST -D - ${i}
  #  curl -i -X POST -L ${i}
  echo
done

# test: pp ok