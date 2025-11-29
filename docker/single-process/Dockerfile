FROM rubylang/ruby:4.0-jammy

COPY docker/scripts/prepare /scripts/
RUN /scripts/prepare

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

ARG OUTDATED_DOCKER_REGISTRY=false
ENV OUTDATED_DOCKER_REGISTRY=${OUTDATED_DOCKER_REGISTRY}

RUN APP_SECRET_TOKEN=secret DATABASE_ADAPTER=mysql2 ON_HEROKU=true bundle exec rake assets:clean assets:precompile

EXPOSE 3000

COPY ["docker/scripts/setup_env", "docker/single-process/scripts/init", "/scripts/"]
CMD ["/scripts/init"]
