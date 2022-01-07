FROM ruby:2.6-alpine AS builder

RUN apk --update add --no-cache \
  build-base \
  git \
  zlib-dev \
  yaml-dev \
  openssl-dev \
  gdbm-dev \
  readline-dev \
  ncurses-dev \
  libffi-dev \
  libxml2-dev \
  libxslt-dev \
  icu-dev \
  mariadb-dev \
  libpq-dev \
  sqlite-dev \
  graphviz \
  curl \
  tzdata \
  shared-mime-info \
  iputils \
  jq \
  libc6-compat \
  nodejs && \
  mkdir /app && \
  ln -s /lib/libc.musl-x86_64.so.1 /lib/ld-linux-x86-64.so.2

WORKDIR /app

COPY ["Gemfile", "Gemfile.lock", "./"]
COPY lib/gemfile_helper.rb lib/
COPY vendor/gems/ vendor/gems/
COPY .env.example .env

RUN umask 002 && git init && \
  gem install bundler && \
  bundle install --without test development -j 4 && \
  rm -rf /usr/local/bundle/cache/*.gem && \
  find /usr/local/bundle/gems/ -name "*.c" -delete && \
  find /usr/local/bundle/gems/ -name "*.o" -delete

COPY . .

ENV LC_ALL=en_US.UTF-8 RAILS_ENV=production DATABASE_URL=sqlite3:/data/huginn.db
  
RUN bundle exec rails assets:precompile && rm -rf app/assets spec

# -------

FROM ruby:2.6-alpine

WORKDIR /app

RUN addgroup -g 1000 -S app \
 && adduser -u 1000 -S app -G app

RUN apk --update add --no-cache \
  git zlib yaml libssl3 gdbm readline ncurses-libs libffi libxml2 libxslt icu \
  sqlite-libs mariadb-client libpq \
  graphviz curl tzdata shared-mime-info iputils jq \
  libc6-compat nodejs && \
  mkdir /data && \
  ln -s /lib/libc.musl-x86_64.so.1 /lib/ld-linux-x86-64.so.2 && \
  chown -R app:app /data

COPY --from=builder /usr/local/bundle /usr/local/bundle
COPY --from=builder --chown=app:app /app /app

ENV LC_ALL=en_US.UTF-8 \
  RAILS_ENV=production \
  USE_GRAPHVIZ_DOT=dot \
  RAILS_LOG_TO_STDOUT=true \
  RAILS_SERVE_STATIC_FILES=true \
  IP="0.0.0.0" PORT=3000 \
  DATABASE_URL=sqlite3:/data/huginn.db \
  APP_SECRET_TOKEN=changeme 

USER app

EXPOSE 3000

CMD ["bundle", "exec", "foreman", "start"]
