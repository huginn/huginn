FROM ubuntu:14.04
MAINTAINER Andrew Cantino

ENV DEBIAN_FRONTEND noninteractive
RUN apt-get update && \
    apt-get install -y software-properties-common && \
    add-apt-repository -y ppa:git-core/ppa && \
    add-apt-repository -y ppa:brightbox/ruby-ng && \
    apt-get update && \
    apt-get install -y build-essential checkinstall postgresql-client \
      git-core mysql-server redis-server python2.7 python-docutils \
      libmysqlclient-dev libpq-dev zlib1g-dev libyaml-dev libssl-dev \
      libgdbm-dev libreadline-dev libncurses5-dev libffi-dev \
      libxml2-dev libxslt-dev libcurl4-openssl-dev libicu-dev \
      graphviz libgraphviz-dev \
      ruby2.1 ruby2.1-dev supervisor python-pip && \
    gem install --no-ri --no-rdoc bundler && \
    rm -rf /var/lib/apt/lists/*

RUN pip install supervisor-stdout

ADD scripts/ /scripts
RUN chmod 755 /scripts/setup /scripts/init

RUN /scripts/setup

VOLUME /var/lib/mysql

EXPOSE 5000

CMD ["/scripts/init"]

