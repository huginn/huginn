#!/usr/bin/env sh
set -ex

apk add --no-cache --virtual .build-dependencies \
    build-base \
    linux-headers \
    mariadb-dev \
    postgresql-dev \
    sqlite-dev
