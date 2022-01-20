#!/usr/bin/env bash

MYSQL_CONTAINER_NAME=mysql-server
MYSQL_SERVER_VOLUME=$HOME/docker/mysql-server/
MYSQL_VERSION=8.0.28
MYSQL_PASSWORD=your-password
TC_DB_NAME=teamcity
TC_VERSION=2021.2
TC_DB_USER=teamcity
TC_DB_PASSWORD=your-password
TC_NODE1_CONTAINER_NAME=tc-node-1
TC_NODE2_CONTAINER_NAME=tc-node-2
TC_NODE1_DATA_VOLUME=$HOME/docker/teamcity/node-1/datadir/
TC_NODE1_LOGS_VOLUME=$HOME/docker/teamcity/node-1/logs/
TC_NODE1_PORT=8111
TC_NODE2_DATA_VOLUME=$HOME/docker/teamcity/node-2/datadir/
TC_NODE2_LOGS_VOLUME=$HOME/docker/teamcity/node-2/logs/
TC_NODE2_PORT=8112

mkdir -p ${MYSQL_SERVER_VOLUME}
mkdir -p ${TC_NODE1_DATA_VOLUME}
mkdir -p ${TC_NODE1_LOGS_VOLUME}
mkdir -p ${TC_NODE2_DATA_VOLUME}
mkdir -p ${TC_NODE2_LOGS_VOLUME}

docker run -dit --privileged --name=${MYSQL_CONTAINER_NAME} \
-e MYSQL_ROOT_PASSWORD=${MYSQL_PASSWORD} \
-v ${MYSQL_SERVER_VOLUME}:/var/lib/mysql \
-p 3306:3306 mysql/mysql-server:${MYSQL_VERSION}

docker exec -it ${MYSQL_CONTAINER_NAME} mysql -uroot -p${MYSQL_PASSWORD} -e "create database ${TC_DB_NAME} collate utf8mb4_bin;"
docker exec -it ${MYSQL_CONTAINER_NAME} mysql -uroot -p${MYSQL_PASSWORD} -e "create user ${TC_DB_USER} identified by \"${TC_DB_PASSWORD}\";"
docker exec -it ${MYSQL_CONTAINER_NAME} mysql -uroot -p${MYSQL_PASSWORD} -e "grant all privileges on ${TC_DB_NAME}.* to ${TC_DB_USER};"
docker exec -it ${MYSQL_CONTAINER_NAME} mysql -uroot -p${MYSQL_PASSWORD} -e "grant process on *.* to ${TC_DB_USER};"

docker run -dit --name ${TC_NODE1_CONTAINER_NAME} \
-e TEAMCITY_STOP_WAIT_TIME=120 \ 
-v ${TC_NODE1_DATA_VOLUME}:/data/teamcity_server/datadir \
-v ${TC_NODE1_LOGS_VOLUME}:/opt/teamcity/logs \
-p ${TC_NODE1_PORT}:${TC_NODE1_PORT} jetbrains/teamcity-server:${TC_VERSION}

docker run -dit --name ${TC_NODE2_CONTAINER_NAME} \
-e TEAMCITY_STOP_WAIT_TIME=120 \ 
-v ${TC_NODE2_DATA_VOLUME}:/data/teamcity_server/datadir \
-v ${TC_NODE2_DATA_VOLUME}:/opt/teamcity/logs \
-p ${TC_NODE2_PORT}:${TC_NODE2_PORT} jetbrains/teamcity-server:${TC_VERSION}
