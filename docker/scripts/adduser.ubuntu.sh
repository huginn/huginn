#!/usr/bin/env sh
set -ex

adduser --group $HUGINN_GROUP
adduser --disabled-login --ingroup $HUGINN_GROUP --gecos 'Huginn' --no-create-home --home $HUGINN_HOME $HUGINN_USER
passwd -d $HUGINN_USER
