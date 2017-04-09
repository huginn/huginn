#!/usr/bin/env sh
set -ex

apt-get purge -y python3* rsyslog rsync manpages
rm -rf /var/lib/apt/lists/*
rm -rf /usr/share/doc/
rm -rf /usr/share/man/
rm -rf /usr/share/locale/
rm -rf /var/log/*
