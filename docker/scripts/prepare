#!/bin/bash
set -e

cat > /etc/dpkg/dpkg.cfg.d/01_nodoc <<EOF
# Delete locales
path-exclude=/usr/share/locale/*

# Delete man pages
path-exclude=/usr/share/man/*

# Delete docs
path-exclude=/usr/share/doc/*
path-include=/usr/share/doc/*/copyright
EOF

export LC_ALL=C
export DEBIAN_FRONTEND=noninteractive

CLEAR_DOCKER_CACHE=2020-05-28

minimal_apt_get_install='apt-get install -y --no-install-recommends'

apt-get update
apt-get dist-upgrade -y --no-install-recommends
$minimal_apt_get_install software-properties-common
$minimal_apt_get_install build-essential checkinstall git-core \
  zlib1g-dev libyaml-dev libssl-dev libgdbm-dev libreadline-dev \
  libncurses5-dev libffi-dev libxml2-dev libxslt-dev curl libcurl4-openssl-dev libicu-dev \
  graphviz libmysqlclient-dev libpq-dev libsqlite3-dev \
  locales tzdata shared-mime-info iputils-ping
locale-gen en_US.UTF-8
update-locale LANG=en_US.UTF-8 LC_CTYPE=en_US.UTF-8
gem update --system --no-document
gem update bundler --conservative --no-document

apt-get purge -y python3* rsyslog rsync manpages
apt-get -y clean
apt-get -y autoremove
rm -rf /var/lib/apt/lists/*
rm -rf /usr/share/doc/
rm -rf /usr/share/man/
rm -rf /usr/share/locale/
rm -rf /var/log/*

# Install the latest jq for JqAgent
curl -fsSL -o /usr/local/bin/jq https://github.com/stedolan/jq/releases/latest/download/jq-linux64
chmod +x /usr/local/bin/jq

mkdir -p /app
chmod -R g=u /etc/passwd /app
