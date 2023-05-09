FROM rubylang/ruby:3.2-jammy

COPY docker/scripts/prepare /scripts/
RUN /scripts/prepare

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

RUN APP_SECRET_TOKEN=secret DATABASE_ADAPTER=mysql2 ON_HEROKU=true bundle install -j 4

COPY --chown="$UID:0" ./ /app/

ARG OUTDATED_DOCKER_REGISTRY=false
ENV OUTDATED_DOCKER_REGISTRY=${OUTDATED_DOCKER_REGISTRY}

RUN APP_SECRET_TOKEN=secret DATABASE_ADAPTER=mysql2 ON_HEROKU=true bundle exec rake assets:clean assets:precompile

EXPOSE 3000

COPY docker/multi-process/scripts/supervisord.conf /etc/supervisor/
COPY ["docker/multi-process/scripts/bootstrap.conf", \
      "docker/multi-process/scripts/foreman.conf", \
      "docker/multi-process/scripts/mysqld.conf", "/etc/supervisor/conf.d/"]
COPY ["docker/multi-process/scripts/bootstrap.sh", \
      "docker/multi-process/scripts/foreman.sh", \
      "docker/multi-process/scripts/init", \
      "docker/scripts/setup_env", "/scripts/"]
CMD ["/scripts/init"]

VOLUME /var/lib/mysql
