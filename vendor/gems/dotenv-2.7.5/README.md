# dotenv [![Build Status](https://secure.travis-ci.org/bkeepers/dotenv.svg?branch=master)](https://travis-ci.org/bkeepers/dotenv) [![Gem Version](https://badge.fury.io/rb/dotenv.svg)](https://badge.fury.io/rb/dotenv) [![Join the chat at https://gitter.im/bkeepers/dotenv](https://badges.gitter.im/Join%20Chat.svg)](https://gitter.im/bkeepers/dotenv?utm_source=badge&utm_medium=badge&utm_campaign=pr-badge&utm_content=badge)

Shim to load environment variables from `.env` into `ENV` in *development*.

Storing [configuration in the environment](http://12factor.net/config) is one of the tenets of a [twelve-factor app](http://12factor.net). Anything that is likely to change between deployment environments–such as resource handles for databases or credentials for external services–should be extracted from the code into environment variables.

But it is not always practical to set environment variables on development machines or continuous integration servers where multiple projects are run. dotenv loads variables from a `.env` file into `ENV` when the environment is bootstrapped.

## Installation

### Rails

Add this line to the top of your application's Gemfile:

```ruby
gem 'dotenv-rails', groups: [:development, :test]
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
gem 'dotenv-rails', require: 'dotenv/rails-now'
gem 'gem-that-requires-env-variables'
```

### Sinatra or Plain ol' Ruby

Install the gem:

```shell
$ gem install dotenv
```

As early as possible in your application bootstrap process, load `.env`:

```ruby
require 'dotenv/load'

# or
require 'dotenv'
Dotenv.load
```

By default, `load` will look for a file called `.env` in the current working directory. Pass in multiple files and they will be loaded in order. The first value set for a variable will win.

```ruby
require 'dotenv'
Dotenv.load('file1.env', 'file2.env')
```

Alternatively, you can use the `dotenv` executable to launch your application:

```shell
$ dotenv ./script.rb
```

The `dotenv` executable also accepts a single flag, `-f`. Its value should be a comma-separated list of configuration files, in the order of most important to least. All of the files must exist. There _must_ be a space between the flag and its value.

```
$ dotenv -f ".env.local,.env" ./script.rb
```

To ensure `.env` is loaded in rake, load the tasks:

```ruby
require 'dotenv/tasks'

task mytask: :dotenv do
    # things that require .env
end
```

## Usage

Add your application configuration to your `.env` file in the root of your project:

```shell
S3_BUCKET=YOURS3BUCKET
SECRET_KEY=YOURSECRETKEYGOESHERE
```

Whenever your application loads, these variables will be available in `ENV`:

```ruby
config.fog_directory  = ENV['S3_BUCKET']
```

You may also add `export` in front of each line so you can `source` the file in bash:

```shell
export S3_BUCKET=YOURS3BUCKET
export SECRET_KEY=YOURSECRETKEYGOESHERE
```

### Multi-line values

If you need multiline variables, for example private keys, you can double quote strings and use the `\n` character for newlines:

```shell
PRIVATE_KEY="-----BEGIN RSA PRIVATE KEY-----\nHkVN9...\n-----END DSA PRIVATE KEY-----\n"
```

Alternatively, multi-line values with line breaks are now supported for quoted values.

```shell
PRIVATE_KEY="-----BEGIN RSA PRIVATE KEY-----
...
HkVN9...
...
-----END DSA PRIVATE KEY-----"
```

This is particularly helpful when using the Heroku command line plugin [`heroku-config`](https://github.com/xavdid/heroku-config) to pull configuration variables down that may have line breaks.

### Command Substitution

You need to add the output of a command in one of your variables? Simply add it with `$(your_command)`:

```shell
DATABASE_URL="postgres://$(whoami)@localhost/my_database"
```

### Variable Substitution

You need to add the value of another variable in one of your variables? You can reference the variable with `${VAR}` or often just `$VAR` in unqoted or double-quoted values.

```shell
DATABASE_URL="postgres://${USER}@localhost/my_database"
```

If a value contains a `$` and it is not intended to be a variable, wrap it in single quotes.

```shell
PASSWORD='pas$word'
```

### Comments

Comments may be added to your file as such:

```shell
# This is a comment
SECRET_KEY=YOURSECRETKEYGOESHERE # comment
SECRET_HASH="something-with-a-#-hash"
```

### Required Keys

If a particular configuration value is required but not set, it's appropriate to raise an error.

To require configuration keys:

```ruby
# config/initializers/dotenv.rb

Dotenv.require_keys("SERVICE_APP_ID", "SERVICE_KEY", "SERVICE_SECRET")
```

If any of the configuration keys above are not set, your application will raise an error during initialization. This method is preferred because it prevents runtime errors in a production application due to improper configuration.

### Parsing

To parse a list of env files for programmatic inspection without modifying the ENV:

```ruby
Dotenv.parse(".env.local", ".env")
# => {'S3_BUCKET' => 'YOURS3BUCKET', 'SECRET_KEY' => 'YOURSECRETKEYGOESHERE', ...}
```

This method returns a hash of the ENV var name/value pairs.

## Frequently Answered Questions

### Can I use dotenv in production?

dotenv was originally created to load configuration variables into `ENV` in *development*. There are typically better ways to manage configuration in production environments - such as `/etc/environment` managed by [Puppet](https://github.com/puppetlabs/puppet) or [Chef](https://github.com/chef/chef), `heroku config`, etc.

However, some find dotenv to be a convenient way to configure Rails applications in staging and production environments, and you can do that by defining environment-specific files like `.env.production` or `.env.test`.

If you use this gem to handle env vars for multiple Rails environments (development, test, production, etc.), please note that env vars that are general to all environments should be stored in `.env`. Then, environment specific env vars should be stored in `.env.<that environment's name>`.

### What other .env* files can I use?

`dotenv-rails` will override in the following order (highest defined variable overrides lower):

| Hierarchy Priority | Filename                 | Environment          | Should I `.gitignore`it?                            | Notes                                                        |
| ------------------ | ------------------------ | -------------------- | --------------------------------------------------- | ------------------------------------------------------------ |
| 1st (highest)      | `.env.development.local` | Development          | Yes!                                                | Local overrides of environment-specific settings.            |
| 1st                | `.env.test.local`        | Test                 | Yes!                                                | Local overrides of environment-specific settings.            |
| 1st                | `.env.production.local`  | Production           | Yes!                                                | Local overrides of environment-specific settings.            |
| 2nd                | `.env.local`             | Wherever the file is | Definitely.                                         | Local overrides. This file is loaded for all environments _except_ `test`. |
| 3rd                | `.env.development`       | Development          | No.                                                 | Shared environment-specific settings                         |
| 3rd                | `.env.test`              | Test                 | No.                                                 | Shared environment-specific settings                         |
| 3rd                | `.env.production`        | Production           | No.                                                 | Shared environment-specific settings                         |
| Last               | `.env`                   | All Environments     | Depends (See [below](#should-i-commit-my-env-file)) | The Original®                                                |


### Should I commit my .env file?

Credentials should only be accessible on the machines that need access to them. Never commit sensitive information to a repository that is not needed by every development machine and server.


You can use the `-t` or `--template` flag on the dotenv cli to create a template of your `.env` file.
```shell
$ dotenv -t .env
```
A template will be created in your working directory named `{FINAME}.template`. So in the above example, it would create a `.env.template` file. 

The template will contain all the environment variables in your `.env` file but with their values set to the variable names.

```shell
# .env
S3_BUCKET=YOURS3BUCKET
SECRET_KEY=YOURSECRETKEYGOESHERE
```

Would become 

```shell
# .env.template
S3_BUCKET=S3_BUCKET
SECRET_KEY=SECRET_KEY
```

Personally, I prefer to commit the `.env` file with development-only settings. This makes it easy for other developers to get started on the project without compromising credentials for other environments. If you follow this advice, make sure that all the credentials for your development environment are different from your other deployments and that the development credentials do not have access to any confidential data.

### Why is it not overriding existing `ENV` variables?

By default, it **won't** overwrite existing environment variables as dotenv assumes the deployment environment has more knowledge about configuration than the application does. To overwrite existing environment variables you can use `Dotenv.overload`.

## Contributing

If you want a better idea of how dotenv works, check out the [Ruby Rogues Code Reading of dotenv](https://www.youtube.com/watch?v=lKmY_0uY86s).

1. Fork it
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit your changes (`git commit -am 'Added some feature'`)
4. Push to the branch (`git push origin my-new-feature`)
5. Create new Pull Request
