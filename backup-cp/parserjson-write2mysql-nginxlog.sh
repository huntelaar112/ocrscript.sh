#!/bin/bash

#use:
#script:
# parser nginx log to .txt contain json list --> parser json file to array bash
set -e
done=no

[[ -e /tmp/countrequest-json.txt ]] && {
  echo "Create blank /tmp/countrequest-json.txt"
  rm -rf /tmp/countrequest-json.txt
  touch "/tmp/countrequest-json.txt"
}

currentpath="$PWD"

cd "/mnt/containerdata/nginxgen/var_log_nginx"
zgrep "face" gapi.smartocr.vn-access.log-* | grep 200 | grep "uX-DGZebuw5KX_Q=" | grep -Eo '\{(.*?)\}' >/tmp/countrequest-json.txt
cat gapi.smartocr.vn-access.log | grep "face" | grep 200 | grep "uX-DGZebuw5KX_Q=" >>/tmp/countrequest-json.txt

cd "${currentpath}"

#echo "CREATE DATABASE testDB;" > "/tmp/insert.json"
# create database test before run
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

count=0
year=2023
month=1
jq -c '.[]' countrequest-json.txt | while read i; do
  [[ $count -eq 21 ]] && count=0
  [[ $count -eq 9 ]] && {
    request_datetime=$(echo $i | cut -d '"' -f2)
    #day=$(echo "${request_datetime}" | grep -Eo '^.{0,2}')
    day=${request_datetime::2}
    daytime=${request_datetime%+*}
    daytime=${daytime:12}
    parserdatetimeSql="${year}-${month}-${day} ${daytime}"

    echo "INSERT INTO history (client_id, request_datetime, doc_type, result_code, ocr_result)
VALUES ('106', '${parserdatetimeSql}', '9', '200', '{\"message\": \"Manual insert\"}');" >> "/tmp/insert.sql"
  }
  ((count = count + 1))
done

echo "Done create /tmp/insert.sql"
done=yes
