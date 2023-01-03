#!/bin/bash

## Updated 21/08/22

COMPOSE_VERSION=$(curl --silent https://api.github.com/repos/docker/compose/releases/latest | grep -Po '"tag_name": "\K.*\d')
COMPOSE_DESTINATION=/usr/local/bin/docker-compose
curl -L https://github.com/docker/compose/releases/download/${VERSION}/docker-compose-$(uname -s)-$(uname -m) -o $COMPOSE_DESTINATION
chmod +x $COMPOSE_DESTINATION