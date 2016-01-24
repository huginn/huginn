FROM cantino/huginn-single-process:latest
MAINTAINER Andrew Cantino

WORKDIR /app

ADD scripts/standalone-packages /scripts/standalone-packages
RUN /scripts/standalone-packages

ADD scripts/init /scripts/init

VOLUME /var/lib/mysql

EXPOSE 3000

CMD ["/scripts/init"]

