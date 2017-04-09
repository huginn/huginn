#!/usr/bin/env sh
set -ex

addgroup $HUGINN_GROUP
adduser -s "/bin/sh" -H -h "$HUGINN_HOME" -D -G $HUGINN_GROUP $HUGINN_USER
