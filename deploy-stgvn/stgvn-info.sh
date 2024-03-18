vnpff: 172.172.0.103
vnhff: 172.172.0.102
face: 172.172.0.100
id: 172.172.0.101
mongo: 172.17.0.4
mysqldb: 172.172.0.200

network bridge: 172.17.0.0/16
network ocrnetwork: 172.172.0.0/16

#MONGO and MYSQL STG
[MONGO]
MONGO_HOST=172.17.0.4
MONGO_USER_PORT=27017
MONGO_USERNAME=root
MONGO_ROOT_PASSWORD=123456
DATABASE=KYCDB
AUTHSOURCE=admin

[root@vngcpu8core16gram face]# cat v1.0.1/db_config/mysql.ini
[MYSQL]
MYSQL_HOST=172.172.0.200
MYSQL_PORT=3306
MYSQL_USERNAME=ocr
MYSQL_ROOT_PASSWORD=@#$Cdf-EFBG^
DATABASE=OCR

mysql_rootpass=53%FDFDF!pE$%

#deploy mariadb on ocrssd.
docker run -idt --name mariadb --env MARIADB_USER=ocr --env MARIADB_PASSWORD=123456 --env MARIADB_ROOT_PASSWORD=123456 --network "ocrnetwork" --ip 172.172.0.100  mariadb:latest