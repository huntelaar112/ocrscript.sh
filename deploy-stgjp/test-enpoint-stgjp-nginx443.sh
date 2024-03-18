#!/bin/bash

set -e
done=no

listEndpoint=(
  #jppff
  "https://jpffstg.smartocr.net/jppff/v1/recognition"
  #jphff
  "https://jpffstg.smartocr.net/jphff/v1/recognition"
  #mynumber
  "https://mystg.smartocr.net/mynumber/v1/recognition"
  #jppp
  #"https://ppstg.smartocr.net:4443/pp/v1/recognition"
  #ins
  "https://insstg.smartocr.net/ins/v1/recognition"
  #dlic
  "https://dlicstg.smartocr.net/dlic/v1/recognition"
  #jcr
  "https://jrcstg.smartocr.net/jrc/v1/recognition"
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
