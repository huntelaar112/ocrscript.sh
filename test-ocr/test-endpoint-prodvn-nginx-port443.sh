#!/bin/bash

set -e
done=no

listEndpoint=("https://gapi.smartocr.vn/idfull/v1/recognition"
  "https://gapi.smartocr.vn/idcard/v1/recognition"
  "https://tfv.smartocr.vn/idcard/v1/recognition"
  "https://dgt.smartocr.vn/idcard/v1/recognition"
  "https://dgt.smartocr.vn/multiid/v1/recognition"
  "https://gapi.smartocr.vn/idfulltoyota/v1/recognition"
  #face
  "https://gapi.smartocr.vn/face/v1/recognition"
  "https://gapi.smartocr.vn/face/v1/searching"
  "https://gapi.smartocr.vn/face/v1/register"
  #"https://gapi.smartocr.vn:4443/pp/v1/recognition"
  #pp
  #"https://dgt.smartocr.vn:/pp/v1/recognition"
  "https://gapi.smartocr.vn/pp/v1/recognition"
  #cmqdvn
  "https://gapi.smartocr.vn/cqd/v1/recognition"
  #vnpff
  "https://gapi.smartocr.vn/vnpff/v1/recognition"
  #ghvn
  "https://gapi.smartocr.vn/ghvn/v1/recognition"
  #dkx,gh php
  "https://tfv.smartocr.vn/vnpff/v1/recognition"
)

count=1
for i in "${listEndpoint[@]}"; do
  echo "${count}: ${i}"
  ((count = count + 1))
  curl --location -X POST -D - ${i}
  #  curl -i -X POST -L ${i}
  echo
done

# test: pp ok
