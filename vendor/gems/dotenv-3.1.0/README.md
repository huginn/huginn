# dotenv [![Gem Version](https://badge.fury.io/rb/dotenv.svg)](https://badge.fury.io/rb/dotenv)

Shim to load environment variables from `.env` into `ENV` in *development*.

Storing [configuration in the environment](http://12factor.net/config) is one of the tenets of a [twelve-factor app](http://12factor.net). Anything that is likely to change between deployment environments–such as resource handles for databases or credentials for external services–should be extracted from the code into environment variables.

But it is not always practical to set environment variables on development machines or continuous integration servers where multiple projects are run. dotenv loads variables from a `.env` file into `ENV` when the environment is bootstrapped.

## Installation

Add this line to the top of your application's Gemfile and run `bundle install`:

```ruby
gem 'dotenv', groups: [:development, :test]
```

## Usage

Add your application configuration to your `.env` file in the root of your project:

```shell
S3_BUCKET=YOURS3BUCKET
SECRET_KEY=YOURSECRETKEYGOESHERE
```

Whenever your application loads, these variables will be available in `ENV`:

```ruby
config.fog_directory = ENV['S3_BUCKET']
```

See the [API Docs](https://rubydoc.info/github/bkeepers/dotenv/main) for more.

### Rails

Dotenv will automatically load when your Rails app boots. See [Customizing Rails](#customizing-rails) to change which files are loaded and when.

### Sinatra / Ruby

Load Dotenv as early as possible in your application bootstrap process:

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

### Autorestore in tests

Since 3.0, dotenv in a Rails app will automatically restore `ENV` after each test. This means you can modify `ENV` in your tests without fear of leaking state to other tests. It works with both `ActiveSupport::TestCase` and `Rspec`.

To disable this behavior, set `config.dotenv.autorestore = false` in `config/application.rb` or `config/environments/test.rb`. It is disabled by default if your app uses [climate_control](https://github.com/thoughtbot/climate_control) or [ice_age](https://github.com/dpep/ice_age_rb).

To use this behavior outside of a Rails app, just `require "dotenv/autorestore"` in your test suite.

See [`Dotenv.save`](https://rubydoc.info/github/bkeepers/dotenv/main/Dotenv:save), [Dotenv.restore](https://rubydoc.info/github/bkeepers/dotenv/main/Dotenv:restore), and [`Dotenv.modify(hash) { ... }`](https://rubydoc.info/github/bkeepers/dotenv/main/Dotenv:modify) for manual usage.

### Rake

To ensure `.env` is loaded in rake, load the tasks:

```ruby
require 'dotenv/tasks'

task mytask: :dotenv do
  # things that require .env
end
```

### CLI

You can use the `dotenv` executable load `.env` before launching your application:

```console
$ dotenv ./script.rb
```

The `dotenv` executable also accepts the flag `-f`. Its value should be a comma-separated list of configuration files, in the order of most important to least. All of the files must exist. There _must_ be a space between the flag and its value.

```console
$ dotenv -f ".env.local,.env" ./script.rb
```

The `dotenv` executable can optionally ignore missing files with the `-i` or `--ignore` flag. For example, if the `.env.local` file does not exist, the following will ignore the missing file and only load the `.env` file.

```console
$ dotenv -i -f ".env.local,.env" ./script.rb
```

### Load Order

If you use gems that require environment variables to be set before they are loaded, then list `dotenv` in the `Gemfile` before those other gems and require `dotenv/load`.

```ruby
gem 'dotenv', require: 'dotenv/load'
gem 'gem-that-requires-env-variables'
```

### Customizing Rails

Dotenv will load the following files depending on `RAILS_ENV`, with the first file having the highest precedence, and `.env` having the lowest precedence:

<table>
  <thead>
    <tr>
      <th>Priority</th>
      <th colspan="3">Environment</th>
      <th><code>.gitignore</code>it?</th>
      <th>Notes</th>
    </tr>
    <tr>
      <th></th>
      <th>development</th>
      <th>test</th>
      <th>production</th>
      <th></th>
      <th></th>
    </tr>
  </thead>
  <tr>
    <td>highest</td>
    <td><code>.env.development.local</code></td>
    <td><code>.env.test.local</code></td>
    <td><code>.env.production.local</code></td>
    <td>Yes</td>
    <td>Environment-specific local overrides</td>
  </tr>
  <tr>
    <td>2nd</td>
    <td><code>.env.local</code></td>
    <td><strong>N/A</strong></td>
    <td><code>.env.local</code></td>
    <td>Yes</td>
    <td>Local overrides</td>
  </tr>
  <tr>
    <td>3rd</td>
    <td><code>.env.development</code></td>
    <td><code>.env.test</code></td>
    <td><code>.env.production</code></td>
    <td>No</td>
    <td>Shared environment-specific variables</td>
  </tr>
  <tr>
    <td>last</td>
    <td><code>.env</code></td>
    <td><code>.env</code></td>
    <td><code>.env</code></td>
    <td><a href="#should-i-commit-my-env-file">Maybe</a></td>
    <td>Shared for all environments</td>
  </tr>
</table>


These files are loaded during the `before_configuration` callback, which is fired when the `Application` constant is defined in `config/application.rb` with `class Application < Rails::Application`. If you need it to be initialized sooner, or need to customize the loading process, you can do so at the top of `application.rb`

```ruby
# config/application.rb
Bundler.require(*Rails.groups)

# Load .env.local in test
Dotenv::Rails.files.unshift(".env.local") if ENV["RAILS_ENV"] == "test"

module YourApp
  class Application < Rails::Application
    # ...
  end
end
```

Available options:

* `Dotenv::Rails.files` - list of files to be loaded, in order of precedence.
* `Dotenv::Rails.overwrite` - Overwrite exiting `ENV` variables with contents of `.env*` files
* `Dotenv::Rails.logger` - The logger to use for dotenv's logging. Defaults to `Rails.logger`
* `Dotenv::Rails.autorestore` - Enable or disable [autorestore](#autorestore-in-tests)

### Multi-line values

Multi-line values with line breaks must be surrounded with double quotes.

```shell
PRIVATE_KEY="-----BEGIN RSA PRIVATE KEY-----
...
HkVN9...
...
-----END DSA PRIVATE KEY-----"
```

Prior to 3.0, dotenv would replace `\n` in quoted strings with a newline, but that behavior is deprecated. To use the old behavior, set `DOTENV_LINEBREAK_MODE=legacy` before any variables that include `\n`:

```shell
DOTENV_LINEBREAK_MODE=legacy
PRIVATE_KEY="-----BEGIN RSA PRIVATE KEY-----\nHkVN9...\n-----END DSA PRIVATE KEY-----\n"
```

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

### Exports

For compatability, you may also add `export` in front of each line so you can `source` the file in bash:

```shell
export S3_BUCKET=YOURS3BUCKET
export SECRET_KEY=YOURSECRETKEYGOESHERE
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

### Templates

You can use the `-t` or `--template` flag on the dotenv cli to create a template of your `.env` file.

```console
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

## Frequently Answered Questions

### Can I use dotenv in production?

dotenv was originally created to load configuration variables into `ENV` in *development*. There are typically better ways to manage configuration in production environments - such as `/etc/environment` managed by [Puppet](https://github.com/puppetlabs/puppet) or [Chef](https://github.com/chef/chef), `heroku config`, etc.

However, some find dotenv to be a convenient way to configure Rails applications in staging and production environments, and you can do that by defining environment-specific files like `.env.production` or `.env.test`.

If you use this gem to handle env vars for multiple Rails environments (development, test, production, etc.), please note that env vars that are general to all environments should be stored in `.env`. Then, environment specific env vars should be stored in `.env.<that environment's name>`.

### Should I commit my .env file?

Credentials should only be accessible on the machines that need access to them. Never commit sensitive information to a repository that is not needed by every development machine and server.

Personally, I prefer to commit the `.env` file with development-only settings. This makes it easy for other developers to get started on the project without compromising credentials for other environments. If you follow this advice, make sure that all the credentials for your development environment are different from your other deployments and that the development credentials do not have access to any confidential data.

### Why is it not overwriting existing `ENV` variables?

By default, it **won't** overwrite existing environment variables as dotenv assumes the deployment environment has more knowledge about configuration than the application does. To overwrite existing environment variables you can use `Dotenv.load files, overwrite: true`.

You can also use the `-o` or `--overwrite` flag on the dotenv cli to overwrite existing `ENV` variables.

```console
$ dotenv -o -f ".env.local,.env"
```

## Contributing

If you want a better idea of how dotenv works, check out the [Ruby Rogues Code Reading of dotenv](https://www.youtube.com/watch?v=lKmY_0uY86s).

1. Fork it
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit your changes (`git commit -am 'Added some feature'`)
4. Push to the branch (`git push origin my-new-feature`)
5. Create new Pull Request
