#!/bin/bash

#install mysql community server
sudo apt update && sudo apt -y  install wget
wget https://repo.mysql.com//mysql-apt-config_0.8.22-1_all.deb
sudo dpkg -i mysql-apt-config_0.8.22-1_all.deb
sudo apt update
sudo apt install mysql-server

#log in mysql
mysql -u root -p password
#remote mysql -h [MYSQL SERVER IP] -u [USER-NAME] -p

#create user and privileges
CREATE USER 'username' IDENTIFIED BY 'password';
GRANT SELECT ON *.* TO 'username';
GRANT ALL PRIVILEGES ON *.* TO 'username';

#create database
CREATE DATABASE dbname;

#show databases
show databases;
#start working with database
USE dbname;

#show tables
show tables;

#show columns name in table;
DESCRIBE table_name;
#or
SHOW COLUMNS FROM table_name;

#slect first row in table
SELECT * FROM 'table_name' LIMIT 1;
#select last row in table
SELECT 'fields_name' FROM 'table_name' ORDER BY 'fields_name' DESC LIMIT 1;

#select distinct value of a column in table
SELECT DISTINCT 'column' FROM 'table_name';
#select distinct value of a colums in table where value(another colum)=0
SELECT DISTINCT 'column' FROM 'table_name' WHERE 'another column'=0;


#count number of row have 'special value' in colume name
SELECT id, count(*) as 'column name' FROM 'table name' GROUP BY 'special value' # special value of colume name

#select last 5 row have specific value, id is auto increase value
SELECT * FROM 'table name' WHERE 'filed name = value'  ORDER BY id DESC LIMIT 5;

SELECT * FROM history WHERE client_id = 106  AND doc_type = 10  ORDER BY id DESC LIMIT 5;

SELECT * FROM testhistory WHERE client_id = 106  AND doc_type = 9  ORDER BY id DESC LIMIT 5;

#slect first 3 row mysql
SELECT * FROM history LIMIT 3;

#--ADMIN TASK--
#delete database
DROP DATABASE dbname;
#delete acount
DROP USER 'username';

#backup database/table mysql
mysqldump -u <db_username> -h <db_host> -p db_name table_name > table_name.sql

#restore sql table
mysql -u username -p db_name < /path/to/table_name.sql

#delete table from date
DELETE FROM table WHERE date < '2011-09-21 08:21:22';

#copy a part of table to another table depend on date, replace column[1-3], new_table, old_table, date_colum with your table static
INSERT INTO new_table (column1, column2, column3)
SELECT column1, column2, column3
FROM old_table
WHERE date_column >= '2022-01-01' AND date_column <= '2022-12-31';

#find version mysql
SHOW VARIABLES LIKE 'version';

#get size of mysql databases
SELECT table_schema "DB Name",
        ROUND(SUM(data_length + index_length) / 1024 / 1024, 1) "DB Size in MB"
FROM information_schema.tables
GROUP BY table_schema;

#get size of all tables in mysql
SELECT
     table_schema as `Database`,
     table_name AS `Table`,
     round(((data_length + index_length) / 1024 / 1024), 2) `Size in MB`
FROM information_schema.TABLES
ORDER BY (data_length + index_length) DESC;

#get numbers of record of table  mysql
SELECT table_name, table_rows FROM INFORMATION_SCHEMA.TABLES WHERE TABLE_SCHEMA = 'DB Name';

##################### INSTALL MARIADB docker container
docker run -idt --network ocrnetwork --name mariadb --hostname mariadb --env MARIADB_USER=ocr --env MARIADB_PASSWORD=justdoitforfun --env MARIADB_ROOT_PASSWORD=justdoit mariadb:latest

##################### MONGO
docker run -idt --network ocrnetwork --name redis_db --hostname --ip 172.18.0.3 -p 6379:6379 --restart always redis_db redis:7.0.10

docker run -idt --network ocrnetowrk --name helloworld --hostname -p 113:80 hello-world

mongo -u root -p password;

show dbs;

use "Data_base name"

#track err
cat gapi.smartocr.vn-access.log | grep "Js0cLPC-vgkilOE=" | grep "Mar/2023" | grep -v "\"status\": \"401\"" | grep -Ee "\"urt\": \"\w{2}.*\""
cat gapi.smartocr.vn-access.log | grep "172.18.0.5" | grep "Mar/2023" | grep -v "\"status\": \"401\"" | grep -Ee "\"urt\": \"\w{2}.*\""

#doi soat dgt
select count(ocr_result)  from (select ocr_result from history where client_id=2 and doc_type=0 and JSON_VALID(ocr_result) and result_code=200 and request_datetime>='2023-05-01' and request_datetime <'2023-06-01') as ocrret;
select count(*) from history where client_id=2 and doc_type=2 and result_code=200 and request_datetime>='2023-05-01' and request_datetime <'2023-06-01';
select count(ocr_result) from history where client_id=2 and doc_type=0 and result_code=200 and JSON_VALID(ocr_result) and request_datetime>='2023-05-01'  and request_datetime <'2023-06-01' and JSON_EXTRACT(ocr_result,'$.front_flg')=-1;

