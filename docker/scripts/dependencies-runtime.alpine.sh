#!/usr/bin/env sh
set -ex

apk add --no-cache \
    git \
    libcurl \
    libpq \
    mariadb-client-libs \
    sqlite-libs \
    su-exec \
    tzdata
