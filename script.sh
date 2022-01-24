#!/usr/bin/env bash

# Variables
## Global
BIND_MOUT_ROOT=$HOME/teamcity-multinode-setup
## SQL server
SQL_CONTAINER_NAME=mysql-server
MYSQL_PASSWORD=123456789
TC_DB_USER=teamcity
TC_DB_PASSWORD=123456789
TC_DB_NAME=teamcity
MYSQL_CONTAINER_NAME=mysql-server
MYSQL_SERVER_VOLUME=${BIND_MOUT_ROOT}/${SQL_CONTAINER_NAME}/
MYSQL_VERSION=8.0.28
# NFS server
NFS_CONTAINER_NAME=nfs-server
NFS_BIND_MOUNT=${BIND_MOUT_ROOT}/${NFS_CONTAINER_NAME}/
## TeamCity nodes
TC_NODE1_CONTAINER_NAME=tc-node1
TC_NODE2_CONTAINER_NAME=tc-node2
TC_NODE1_DATA_VOLUME=${BIND_MOUT_ROOT}/${TC_NODE1_CONTAINER_NAME}/datadir/
TC_NODE2_DATA_VOLUME=${BIND_MOUT_ROOT}/${TC_NODE2_CONTAINER_NAME}/datadir/
TC_NODE1_LOGS_VOLUME=${BIND_MOUT_ROOT}/${TC_NODE1_CONTAINER_NAME}/logs/
TC_NODE2_LOGS_VOLUME=${BIND_MOUT_ROOT}/${TC_NODE2_CONTAINER_NAME}/logs/
TC_NODE1_NODESPECIFIC_DIR=${BIND_MOUT_ROOT}/${TC_NODE1_CONTAINER_NAME}/node-datadir
TC_NODE2_NODESPECIFIC_DIR=${BIND_MOUT_ROOT}/${TC_NODE2_CONTAINER_NAME}/node-datadir
TC_VERSION=2021.2
TC_NODE1_PORT=8111
TC_NODE2_PORT=8112
JDBC_DRIVER_DOWNLOAD_LINK=https://dev.mysql.com/get/Downloads/Connector-J/mysql-connector-java_8.0.28-1ubuntu18.04_all.deb
# NGINX
NGINX_CONTAINER_NAME=nginx
NGINX_CONFIG_PATH=${BIND_MOUT_ROOT}/nginx.conf

# Create host volumes
mkdir -p ${NFS_BIND_MOUNT}
mkdir -p ${MYSQL_SERVER_VOLUME}
mkdir -p ${TC_NODE1_DATA_VOLUME}
mkdir -p ${TC_NODE2_DATA_VOLUME}
mkdir -p ${TC_NODE1_LOGS_VOLUME}
mkdir -p ${TC_NODE2_LOGS_VOLUME}
mkdir -p ${TC_NODE1_NODESPECIFIC_DIR}
mkdir -p ${TC_NODE2_NODESPECIFIC_DIR}

# Run NFS server
docker run -dit --privileged --name=${NFS_CONTAINER_NAME} \
-e SHARED_DIRECTORY=/data \
-v ${NFS_BIND_MOUNT}:/data \
-p 2049:2049 \
itsthenetwork/nfs-server-alpine:latest

# Mount NFS share to each TC node's data dir
## Get NFS server container IP
NFS_SERVER_IP=$(docker inspect -f '{{range.NetworkSettings.Networks}}{{.IPAddress}}{{end}}' ${NFS_CONTAINER_NAME})
## Mount
sudo mount -v -o vers=4,loud,lookupcache=positive ${NFS_SERVER_IP}:/ ${TC_NODE1_DATA_VOLUME}
sudo mount -v -o vers=4,loud,lookupcache=positive ${NFS_SERVER_IP}:/ ${TC_NODE2_DATA_VOLUME}

# Run SQL server
docker run -dit --privileged --name=${MYSQL_CONTAINER_NAME} \
-e MYSQL_ROOT_PASSWORD=${MYSQL_PASSWORD} \
-v ${MYSQL_SERVER_VOLUME}:/var/lib/mysql \
-p 3306:3306 mysql/mysql-server:${MYSQL_VERSION}

# Create TC database (wait a few seconds after staring the SQL container)
docker exec -it ${MYSQL_CONTAINER_NAME} mysql -uroot -p${MYSQL_PASSWORD} -e "CREATE DATABASE ${TC_DB_NAME} COLLATE utf8mb4_bin;"
docker exec -it ${MYSQL_CONTAINER_NAME} mysql -uroot -p${MYSQL_PASSWORD} -e "CREATE USER ${TC_DB_USER} IDENTIFIED BY \"${TC_DB_PASSWORD}\";"
docker exec -it ${MYSQL_CONTAINER_NAME} mysql -uroot -p${MYSQL_PASSWORD} -e "GRANT ALL PRIVILEGES ON ${TC_DB_NAME}.* to ${TC_DB_USER};"
docker exec -it ${MYSQL_CONTAINER_NAME} mysql -uroot -p${MYSQL_PASSWORD} -e "GRANT PROCESS ON *.* to ${TC_DB_USER};"

# Install JDBC Driver
wget ${JDBC_DRIVER_DOWNLOAD_LINK} -P ${BIND_MOUT_ROOT}
JDBC_DEB_FILE_NAME=${BIND_MOUT_ROOT}/$(echo ${JDBC_DRIVER_DOWNLOAD_LINK} | tr / ' ' | awk '{print $NF}')
PATH_TO_JAR_IN_DEB=$(dpkg -c ${JDBC_DEB_FILE_NAME} | grep jar | awk '{print $NF}')
JAR_NAME=$(echo ${PATH_TO_JAR_IN_DEB} | tr / ' ' | awk '{print $NF}')
dpkg --fsys-tarfile ${JDBC_DEB_FILE_NAME} | tar xOf - ${PATH_TO_JAR_IN_DEB} > ${BIND_MOUT_ROOT}/${JAR_NAME}
chmod 777 ${BIND_MOUT_ROOT}/${JAR_NAME}
rm ${JDBC_DEB_FILE_NAME}
mkdir -p ${TC_NODE1_DATA_VOLUME}/lib/jdbc
mv ${BIND_MOUT_ROOT}/${JAR_NAME} ${TC_NODE1_DATA_VOLUME}/lib/jdbc

# Create a docker network for inter-node and NGINX communication
docker network create --subnet=192.168.0.0/24 teamcity-network

# Run TC Node 1
docker run --privileged -u 0 -dit --name ${TC_NODE1_CONTAINER_NAME} \
-e TEAMCITY_SERVER_OPTS="-Dteamcity.server.nodeId=${TC_NODE1_CONTAINER_NAME} -Dteamcity.server.rootURL=http://${TC_NODE1_CONTAINER_NAME}:8111 -Dteamcity.data.path=/data/teamcity_server/datadir -Dteamcity.node.data.path=/data/teamcity_server/node_datadir" \
-e TEAMCITY_STOP_WAIT_TIME=30 \
-v ${TC_NODE1_DATA_VOLUME}:/data/teamcity_server/datadir \
-v ${TC_NODE1_NODESPECIFIC_DIR}:/data/teamcity_server/node_datadir \
-v ${TC_NODE1_LOGS_VOLUME}:/opt/teamcity/logs \
-p ${TC_NODE1_PORT}:8111 \
jetbrains/teamcity-server:${TC_VERSION}

# Run TC Node 2
docker run --privileged -u 0 -dit --name ${TC_NODE2_CONTAINER_NAME} \
-e TEAMCITY_SERVER_OPTS="-Dteamcity.server.nodeId=${TC_NODE2_CONTAINER_NAME} -Dteamcity.server.rootURL=http://${TC_NODE2_CONTAINER_NAME}:8111 -Dteamcity.data.path=/data/teamcity_server/datadir -Dteamcity.node.data.path=/data/teamcity_server/node_datadir" \
-e TEAMCITY_STOP_WAIT_TIME=30 \
-v ${TC_NODE2_DATA_VOLUME}:/data/teamcity_server/datadir \
-v ${TC_NODE2_DATA_VOLUME}:/opt/teamcity/logs \
-p ${TC_NODE2_PORT}:8111 \
jetbrains/teamcity-server:${TC_VERSION}

# Connect TC nodes to docker network
docker network connect teamcity-network ${TC_NODE1_CONTAINER_NAME}
docker network connect teamcity-network ${TC_NODE2_CONTAINER_NAME}
