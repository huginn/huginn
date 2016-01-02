FROM dsander/huginn-single-process:latest
MAINTAINER Andrew Cantino

WORKDIR /app

ADD scripts/init /scripts/init

VOLUME /var/lib/mysql

EXPOSE 3000

CMD ["/scripts/init"]

