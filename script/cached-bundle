#!/usr/bin/env bash
# Usage: cached-bundle install --deployment
#
# After running `bundle`, caches the `vendor/bundle` directory to S3.
# On the next run, restores the cached directory before running `bundle`.
# When `Gemfile.lock` changes, the cache gets rebuilt.
#
# Requirements:
# - Gemfile.lock
# - TRAVIS_REPO_SLUG
# - TRAVIS_RUBY_VERSION
# - AMAZON_S3_BUCKET
# - script/s3-put
# - bundle
# - curl
#
# Author: Mislav Marohnić

set -e

compute_md5() {
  local output="$(openssl md5)"
  echo "${output##* }"
}

download() {
  curl --tcp-nodelay -qsfL "$1" -o "$2"
}

bundle_path="vendor/bundle"
gemfile_hash="$(compute_md5 <"${BUNDLE_GEMFILE:-Gemfile}.lock")"
cache_name="${TRAVIS_RUBY_VERSION}-${gemfile_hash}.tgz"
fetch_url="http://${AMAZON_S3_BUCKET}.s3.amazonaws.com/${TRAVIS_REPO_SLUG}/${cache_name}"

if download "$fetch_url" "$cache_name"; then
  echo "Reusing cached bundle ${cache_name}"
  tar xzf "$cache_name"
fi

bundle "$@"

if [ ! -f "$cache_name" ]; then
  echo "Caching \`${bundle_path}' to S3"
  tar czf "$cache_name" "$bundle_path"
  script/s3-put "$cache_name" "${AMAZON_S3_BUCKET}:${TRAVIS_REPO_SLUG}/${cache_name}"
fi
