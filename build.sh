#!/bin/bash

set -e

APP_NAME="$(grep 'app:' mix.exs | sed -e 's/\[//g' -e 's/ //g' -e 's/app://' -e 's/[:,]//g')"
APP_VSN="$(grep 'version:' mix.exs | cut -d '"' -f2)"

docker build -t release . --build-arg APP_VSN=${APP_VSN} --build-arg APP_NAME=${APP_NAME}

id=$(docker create release)
docker cp $id:${APP_NAME}-${APP_VSN}.tar.gz .
docker rm $id