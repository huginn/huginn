# dotenv [![Build Status](https://secure.travis-ci.org/bkeepers/dotenv.png?branch=master)](https://travis-ci.org/bkeepers/dotenv)

Shim to load environment variables from `.env` into `ENV` in *development*.

Storing [configuration in the environment](http://www.12factor.net/config) is one of the tenets of a [twelve-factor app](http://www.12factor.net/). Anything that is likely to change between deployment environments–such as resource handles for databases or credentials for external services–should be extracted from the code into environment variables.

But it is not always practical to set environment variables on development machines or continuous integration servers where multiple projects are run. dotenv loads variables from a `.env` file into `ENV` when the environment is bootstrapped.

## Installation

### Rails

Add this line to the top of your application's Gemfile:

```ruby
gem 'dotenv-rails', :groups => [:development, :test]
```

And then execute:

```shell
$ bundle
```

#### Note on load order

dotenv is initialized in your Rails app during the `before_configuration` callback, which is fired when the `Application` constant is defined in `config/application.rb` with `class Application < Rails::Application`. If you need it to be initialized sooner, you can manually call `Dotenv::Railtie.load`.

```ruby
# config/application.rb
Bundler.require(*Rails.groups)

Dotenv::Railtie.load

HOSTNAME = ENV['HOSTNAME']
```

If you use gems that require environment variables to be set before they are loaded, then list `dotenv-rails` in the `Gemfile` before those other gems and require `dotenv/rails-now`.

```ruby
gem 'dotenv-rails', :require => 'dotenv/rails-now'
gem 'gem-that-requires-env-variables'
```

### Sinatra or Plain ol' Ruby

Install the gem:

```shell
$ gem install dotenv
```

As early as possible in your application bootstrap process, load `.env`:

```ruby
require 'dotenv'
Dotenv.load
```

Alternatively, you can use the `dotenv` executable to launch your application:

```shell
$ dotenv ./script.py
```

To ensure `.env` is loaded in rake, load the tasks:

```ruby
require 'dotenv/tasks'

task :mytask => :dotenv do
    # things that require .env
end
```

## Usage

Add your application configuration to your `.env` file in the root of your project:

```shell
S3_BUCKET=YOURS3BUCKET
SECRET_KEY=YOURSECRETKEYGOESHERE
```

If you need multiline variables, for example private keys, you can double quote strings and use the `\n` character for newlines:

```shell
PRIVATE_KEY="-----BEGIN RSA PRIVATE KEY-----\nHkVN9…\n-----END DSA PRIVATE KEY-----\n"
```

You may also add `export` in front of each line so you can `source` the file in bash:

```shell
export S3_BUCKET=YOURS3BUCKET
export SECRET_KEY=YOURSECRETKEYGOESHERE
```

Whenever your application loads, these variables will be available in `ENV`:

```ruby
config.fog_directory  = ENV['S3_BUCKET']
```

Comments may be added to your file as such:

```shell
# This is a comment
SECRET_KEY=YOURSECRETKEYGOESHERE # comment
SECRET_HASH="something-with-a-#-hash"
```

Variable names may not contain the `#` symbol. Values can use the `#` if they are enclosed in quotes.

## Multiple Rails Environments

dotenv was originally created to load configuration variables into `ENV` in *development*. There are typically better ways to manage configuration in production environments - such as `/etc/environment` managed by [Puppet](https://github.com/puppetlabs/puppet) or [Chef](https://github.com/opscode/chef), `heroku config`, etc.

However, some find dotenv to be a convenient way to configure Rails applications in staging and production environments, and you can do that by defining environment-specific files like `.env.production` or `.env.test`.

You can also `.env.local` for local overrides.

## Should I commit my .env file?

Credentials should only be accessible on the machines that need access to them. Never commit sensitive information to a repository that is not needed by every development machine and server.

Personally, I prefer to commit the `.env` file with development-only settings. This makes it easy for other developers to get started on the project without compromising credentials for other environments. If you follow this advice, make sure that all the credentials for your development environment are different from your other deployments and that the development credentials do not have access to any confidential data.

## Contributing

If you want a better idea of how dotenv works, check out the [Ruby Rogues Code Reading of dotenv](https://www.youtube.com/watch?v=lKmY_0uY86s).

1. Fork it
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit your changes (`git commit -am 'Added some feature'`)
4. Push to the branch (`git push origin my-new-feature`)
5. Create new Pull Request
