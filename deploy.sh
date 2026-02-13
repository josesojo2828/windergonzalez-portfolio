#!/bin/sh

# Detener el script si ocurre un error
set -e

git pull origin main

# Deploy
docker compose down
docker compose up -d --build
docker compose up -d
