#!/bin/bash

docker container stop onlyoffice-{community-server,document-server,mysql-server,control-panel}
docker container prune -y
docker network remove onlyoffice
rm -R /app/onlyoffice

docker network create --driver bridge onlyoffice

## Make dirs
mkdir -p "/app/onlyoffice/mysql/conf.d" && mkdir -p "/app/onlyoffice/mysql/data" && mkdir -p "/app/onlyoffice/mysql/initdb" && mkdir -p "/app/onlyoffice/CommunityServer/data" && mkdir -p "/app/onlyoffice/CommunityServer/logs" && mkdir -p "/app/onlyoffice/CommunityServer/letsencrypt" && mkdir -p "/app/onlyoffice/DocumentServer/data" && mkdir -p "/app/onlyoffice/DocumentServer/logs" && mkdir -p "/app/onlyoffice/MailServer/data/certs" && mkdir -p "/app/onlyoffice/MailServer/logs" && mkdir -p "/app/onlyoffice/ControlPanel/data" && mkdir -p "/app/onlyoffice/ControlPanel/logs"

## Install Document Server
docker run --net onlyoffice -i -t -d --restart=always --name onlyoffice-document-server -v /app/onlyoffice/DocumentServer/logs:/var/log/onlyoffice -v /app/onlyoffice/DocumentServer/data:/var/www/onlyoffice/Data -v /app/onlyoffice/DocumentServer/fonts:/usr/share/fonts/truetype/custom -v /app/onlyoffice/DocumentServer/forgotten:/var/lib/onlyoffice/documentserver/App_Data/cache/files/forgotten onlyoffice/documentserver

## Install Control Panel
docker run --net onlyoffice -i -t -d --restart=always --name onlyoffice-control-panel -v /var/run/docker.sock:/var/run/docker.sock -v /app/onlyoffice/CommunityServer/data:/app/onlyoffice/CommunityServer/data -v /app/onlyoffice/ControlPanel/data:/var/www/onlyoffice/Data -v /app/onlyoffice/ControlPanel/logs:/var/log/onlyoffice onlyoffice/controlpanel

## Install Community Server
docker run --net onlyoffice -i -t -d --privileged --restart=always --name onlyoffice-community-server -p 7180:80 -e MYSQL_SERVER_ROOT_PASSWORD=my-secret-pw -e MYSQL_SERVER_DB_NAME=onlyoffice -e MYSQL_SERVER_HOST=onlyoffice-mysql-server -e MYSQL_SERVER_USER=onlyoffice_user -e MYSQL_SERVER_PASS=onlyoffice_pass -v /app/onlyoffice/CommunityServer/data:/var/www/onlyoffice/Data -v -e DOCUMENT_SERVER_PORT_80_TCP_ADDR=onlyoffice-document-server -e CONTROL_PANEL_PORT_80_TCP=80 -e CONTROL_PANEL_PORT_80_TCP_ADDR=onlyoffice-control-panel /app/onlyoffice/CommunityServer/logs:/var/log/onlyoffice -v /app/onlyoffice/CommunityServer/letsencrypt:/etc/letsencrypt -v /sys/fs/cgroup:/sys/fs/cgroup:ro onlyoffice/communityserver
