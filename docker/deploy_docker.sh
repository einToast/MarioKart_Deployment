#!/usr/bin/env bash

set -euo pipefail

docker compose -f docker-compose.management.yml -f docker-compose.mariokart.yml -f docker-compose.nginx.yml up -d --pull always
