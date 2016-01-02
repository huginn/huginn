FROM ubuntu:14.04
MAINTAINER Dominik Sander

ADD scripts/prepare /scripts/prepare
RUN /scripts/prepare

ADD scripts/setup /scripts/setup
RUN /scripts/setup

WORKDIR /app

ADD scripts/init /scripts/init

EXPOSE 3000

CMD ["/scripts/init"]
