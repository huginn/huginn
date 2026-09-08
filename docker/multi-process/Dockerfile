# Smokescreen is an egress proxy that refuses connections to private and
# link-local addresses.  It is started inside the container when
# ENABLE_SMOKESCREEN=true; see doc/manual/outbound-requests.md.
# renovate: datasource=git-refs depName=https://github.com/stripe/smokescreen branch=master
ARG SMOKESCREEN_COMMIT=d4da883a671475551d78da812db547341c8fe6c3

FROM golang:1.27-alpine AS smokescreen
ARG SMOKESCREEN_COMMIT
RUN CGO_ENABLED=0 go install "github.com/stripe/smokescreen@${SMOKESCREEN_COMMIT}"

FROM rubylang/ruby:4.0.6-jammy

COPY docker/scripts/prepare /scripts/
RUN /scripts/prepare

COPY --from=smokescreen /go/bin/smokescreen /usr/local/bin/smokescreen

COPY docker/multi-process/scripts/standalone-packages /scripts/
RUN /scripts/standalone-packages

WORKDIR /app

ENV HOME=/app

ARG UID=1001
RUN useradd -u "$UID" -g 0 -d /app -s /sbin/nologin -c "default user" default
RUN chown -R "$UID:0" /app
USER $UID

ENV LC_ALL=en_US.UTF-8
ENV RAILS_ENV=production

COPY --chown="$UID:0" ["Gemfile", "Gemfile.lock", "/app/"]
COPY --chown="$UID:0" lib/gemfile_helper.rb /app/lib/
RUN mkdir /app/vendor
COPY --chown="$UID:0" vendor/gems/ /app/vendor/gems/

ARG ADDITIONAL_GEMS=
ENV ADDITIONAL_GEMS=$ADDITIONAL_GEMS

# Get rid of annoying "fatal: Not a git repository (or any of the parent directories): .git" messages
RUN git init && \
    bundle config set --local path vendor/bundle && \
    bundle config set --local without 'test development'

RUN APP_SECRET_TOKEN=secret DATABASE_ADAPTER=mysql2 ON_HEROKU=true bundle install

COPY --chown="$UID:0" ./ /app/

RUN npm install --production

RUN APP_SECRET_TOKEN=secret DATABASE_ADAPTER=mysql2 ON_HEROKU=true bundle exec bootsnap precompile --gemfile app/ lib/ config/
RUN APP_SECRET_TOKEN=secret DATABASE_ADAPTER=mysql2 ON_HEROKU=true bundle exec rake assets:clean assets:precompile

EXPOSE 3000

COPY docker/multi-process/scripts/supervisord.conf /etc/supervisor/
COPY ["docker/multi-process/scripts/bootstrap.conf", \
      "docker/multi-process/scripts/foreman.conf", \
      "docker/multi-process/scripts/mysqld.conf", \
      "docker/multi-process/scripts/smokescreen.conf", "/etc/supervisor/conf.d/"]
COPY ["docker/multi-process/scripts/bootstrap.sh", \
      "docker/multi-process/scripts/foreman.sh", \
      "docker/multi-process/scripts/init", \
      "docker/multi-process/scripts/mysql-5.7.44-linux-glibc2.12-x86_64.tar.gz.asc", \
      "docker/multi-process/scripts/mysql-2022-release.asc", \
      "docker/multi-process/scripts/upgrade-mysql", \
      "docker/scripts/setup_env", "docker/scripts/smokescreen", "/scripts/"]
CMD ["/scripts/init"]

VOLUME /var/lib/mysql
