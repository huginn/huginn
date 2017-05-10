# FIXME: once image is published inherit from official image
# FROM cantino/huginn
FROM singleprocess_huginn_web

ENV PHANTOM_VERSION "phantomjs-2.1.1"
ENV PHANTOM_JS "${PHANTOM_VERSION}-linux-x86_64"

RUN apt-get update && \
    apt-get -y install \
      build-essential \
      chrpath \
      libssl-dev \
      libxft-dev \
      libfreetype6 \
      libfreetype6-dev \
      libfontconfig1 \
      libfontconfig1-dev curl && \
    curl -Ls https://bitbucket.org/ariya/phantomjs/downloads/${PHANTOM_JS}.tar.bz2 \
      | tar jxvf - --strip-components=2 -C /usr/local/bin/ ${PHANTOM_JS}/bin/phantomjs

ENV RAILS_ENV test
RUN chown -R huginn:huginn /app && \
    sudo -u huginn -H echo "gem 'sqlite3', '~> 1.3.11'" >> /app/Gemfile && \
    sudo -u huginn -H LC_ALL=en_US.UTF-8 ON_HEROKU=true bundle install --with test development --path vendor/bundle -j 4

ADD "docker/test/scripts/" "/scripts/"

ENTRYPOINT ["/scripts/init", "/scripts/test"]
CMD [""]
