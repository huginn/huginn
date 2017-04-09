#!/usr/bin/env sh
set -ex

# Cleanup ruby caches
INSTALL_ALL_DATABASE_ADAPTERS=true bundle clean
#&& rm -rf /root/.gem/specs/* \
#&& rm -rf /root/.bundle/cache/* \
#&& rm -rf /usr/local/lib/ruby/gems/2.4.0/cache/* \

# Cleanup transient dependencies/caches
apk del --purge .build-dependencies
rm -rf /var/cache/apk/*
rm -rf /var/lib/apk/*
rm -rf /etc/apk/cache/*
