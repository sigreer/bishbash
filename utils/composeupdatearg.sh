#!/bin/bash

app=$1
docker=/root/docker

if [ ! -d "$docker/$app" ]; then
    echo "Directory $docker/$app does not exist"
    exit 1
fi
cd $docker/$app
docker compose pull
docker compose down
docker compose up -d