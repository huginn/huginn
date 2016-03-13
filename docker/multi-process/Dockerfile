FROM ubuntu:14.04
MAINTAINER Andrew Cantino

ADD docker/scripts/prepare /scripts/prepare
RUN /scripts/prepare

ADD docker/multi-process/scripts/standalone-packages /scripts/standalone-packages
RUN /scripts/standalone-packages

WORKDIR /app

ADD ["Gemfile", "Gemfile.lock", "/app/"]
ADD lib/gemfile_helper.rb /app/lib/
ADD vendor/gems /app/vendor/gems

RUN chown -R huginn:huginn /app && \
    sudo -u huginn -H echo "gem 'sqlite3', '~> 1.3.11'" >> /app/Gemfile && \
    sudo -u huginn -H LC_ALL=en_US.UTF-8 RAILS_ENV=production ON_HEROKU=true bundle install --without test development --path vendor/bundle -j 4
COPY . /app

ADD ["docker/scripts/setup", "docker/multi-process/scripts/init", "/scripts/"]
RUN /scripts/setup

VOLUME /var/lib/mysql

EXPOSE 3000

CMD ["/scripts/init"]

