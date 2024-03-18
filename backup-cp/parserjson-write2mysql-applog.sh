#!/bin/bash

set -e
done=no

[[ -e /tmp/countrequest-json.txt ]] && {
  echo "Create blank /tmp/countrequest-json.txt"
  rm -rf /tmp/countrequest-json.txt
  touch "/tmp/countrequest-json.txt"
}
currentpath="$PWD"

echo "CREATE TABLE history (
    id int NOT NULL AUTO_INCREMENT,
    client_id int NOT NULL,
    request_datetime datetime,
    doc_type int NOT NULL,
    file_name varchar(100),
    front_flag int,
    result_code varchar(10),
    ocr_result varchar(10000),
    PRIMARY KEY (id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;" >/tmp/insert.sql

cat app.log | grep "PGB respose" | grep "200" | grep "2022/11" >/tmp/tempdata.log

[[ -e ./app.log ]] && {
  #data=$(cat app.log | grep "200 : Same Person"
  cat tempdata.log | while read i; do
    line=$i
    request_datetime=${line:1:19}
    echo "INSERT INTO history (client_id, request_datetime, doc_type, result_code, ocr_result)
VALUES ('106', '${request_datetime}', '9', '200', '{\"message\": \"Manual insert\"}');" >>/tmp/insert.sql
  done
} || {
  echo "There aren't app.log file in current folder"
  exit 1
}

echo "Done create /tmp/insert.sql "

done=yes
