#!/bin/bash

mkdir -p /tilt/docker/apps
cd /tilt/docker/apps/
git clone https://github.com/ONLYOFFICE/Docker-DocumentServer.git
cd Docker-DocumentServer
SECRET=$(pwgen 20 1)
sed -i 's/#- JWT/- JWT/g' ./docker-compose.yml
sed -i "s/JWT_SECRET=secret/JWT_SECRET=$SECRET/" ./docker-compose.yml
docker-compose up -d
