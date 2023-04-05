FROM ghcr.io/huginn/huginn-single-process

ENV PHANTOM_VERSION "phantomjs-2.1.1"
ENV PHANTOM_JS "${PHANTOM_VERSION}-linux-x86_64"

USER 0

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
    apt-get -y clean && \
    curl -Ls https://bitbucket.org/ariya/phantomjs/downloads/${PHANTOM_JS}.tar.bz2 \
      | tar jxvf - --strip-components=2 -C /usr/local/bin/ ${PHANTOM_JS}/bin/phantomjs

RUN export LC_ALL=en_US.UTF-8 ON_HEROKU=true && \
    bundle config set --local path vendor/bundle && \
    bundle config set --local without 'test development' && \
    bundle install -j 4

COPY docker/test/scripts/test_env /scripts/
ENTRYPOINT ["/scripts/test_env"]
CMD ["rake spec"]

ARG UID=1001

USER $UID
ENV HOME /app
