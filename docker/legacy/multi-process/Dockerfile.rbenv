FROM ubuntu
# MAINTAINER Someone <someone@example.com>

# Update package list
RUN apt-get update

# Set environmental variables
ENV HOME /root
ENV RBENV_ROOT $HOME/.rbenv
ENV RUBY_VERSION 1.9.3-p545
ENV RUBYGEMS_VERSION 2.2.2
ENV PATH $HOME/.rbenv/shims:$HOME/.rbenv/bin:$RBENV_ROOT/versions/$RUBY_VERSION/bin:$PATH

# Install OS packages
RUN apt-get install -y build-essential curl zlib1g-dev libreadline-dev libssl-dev libcurl4-openssl-dev git libmysqlclient-dev

RUN git clone https://github.com/sstephenson/rbenv.git $HOME/.rbenv
RUN git clone https://github.com/sstephenson/ruby-build.git $HOME/.rbenv/plugins/ruby-build

# install & set global ruby version
RUN rbenv install $RUBY_VERSION
RUN rbenv global $RUBY_VERSION

WORKDIR /usr/local/src

RUN curl -O http://production.cf.rubygems.org/rubygems/rubygems-$RUBYGEMS_VERSION.tgz
RUN tar -xvf rubygems-$RUBYGEMS_VERSION.tgz
RUN cd rubygems-$RUBYGEMS_VERSION ; ruby setup.rb

RUN gem install bundle

RUN mkdir huginn
WORKDIR huginn

# Add Gemfiles and run bundle ahead of time
# This way bundle does not have to rerun unless the Gemfile changes
# It drastically speeds up rebuilds
ADD Gemfile /usr/local/src/huginn/
ADD Procfile /usr/local/src/huginn/
ADD Gemfile.lock /usr/local/src/huginn/
RUN bundle

# Now add the rest of the source
ADD . /usr/local/src/huginn/
RUN rm -rf /usr/local/src/huginn/.env

# Add the environmental variables this way so that the -e option can override them
ENV DATABASE_HOST db
ENV DATABASE_NAME huginn
ENV DATABASE_USERNAME huginn

# Expose the Rails port to the rest of the world
EXPOSE 3000

# Default command - optimized for upgradability
CMD ["foreman", "start"]
