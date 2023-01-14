#!/bin/bash

set -e

docker build -t global_api_release --target release . --build-arg MIX_ENV=prod

id=$(docker create global_api_release)

docker cp $id:global_api.7z .
docker rm $id