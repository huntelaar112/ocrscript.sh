#!/bin/bash

set -e
done=no

listEndpoint=(
  #id
  "https://stgapi.smartocr.vn/idfull/v1/recognition"
  #vnhff
  "https://stgapi.smartocr.vn/vnhff/v1/recognition"
  "https://stgapi.smartocr.vn/vcbhpt/recognition"
  #vnpff
  "https://stgapi.smartocr.vn/vnpff/v1/recognition"
  #face
  "https://stgapi.smartocr.vn/face/v1/recognition"
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
