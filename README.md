![Huginn](https://raw.github.com/huginn/huginn/master/media/huginn-logo.png "Your agents are standing by.")

-----

[![CI](https://github.com/huginn/huginn/actions/workflows/ci.yml/badge.svg)](https://github.com/huginn/huginn/actions/workflows/ci.yml) [![Coverage Status](https://coveralls.io/repos/huginn/huginn/badge.svg)](https://coveralls.io/r/huginn/huginn) [![Gitter](https://badges.gitter.im/Join%20Chat.svg)](https://gitter.im/huginn/huginn)

## What is Huginn?

Huginn is a system for building agents that perform automated tasks for you online.  They can read the web, watch for events, and take actions on your behalf.  Huginn's Agents create and consume events, propagating them along a directed graph.  Think of it as a hackable version of IFTTT or Zapier on your own server.  You always know who has your data.  You do.

![the origin of the name](https://raw.githubusercontent.com/huginn/huginn/master/doc/imgs/the-name.png)

### Here are some of the things that you can do with Huginn

* Scrape websites and receive an email when they change
* Watch RSS feeds, IMAP mailboxes, webhooks, and MQTT topics, and act on what arrives
* Track the weather and get an email when it's going to rain (or snow) tomorrow ("Don't forget your umbrella!")
* Watch for air travel or shopping deals
* Detect peaks and gaps in a stream of events and send a message within moments when something unusual happens
* Send digest emails with the things you care about at specific times of the day
* Post to Slack, Telegram, Threads, Tumblr, Twitter, Weibo, Pushover, Pushbullet, and Jabber, or send SMS and phone calls with Twilio
* Summarize, classify, and translate text, or generate images and speech, with OpenAI-compatible APIs
* Fetch, transform, and store files on Dropbox, S3, FTP, and the local filesystem
* Write custom logic in JavaScript, Liquid templates, or jq
* Publish your own feeds and JSON endpoints from the events your Agents collect
* Track your location over time
* Send and receive webhooks to connect Huginn with anything else

Join us in our [Gitter room](https://gitter.im/huginn/huginn) to discuss the project.

### Join us!

Want to help with Huginn?  All contributions are encouraged!  You could make UI improvements, [add new Agents](https://github.com/huginn/huginn/wiki/Creating-a-new-agent), write [documentation and tutorials](https://github.com/huginn/huginn/wiki), or try tackling [issues tagged with "help wanted"](https://github.com/huginn/huginn/issues?direction=desc&labels=help+wanted&page=1&sort=created&state=open).  Please fork, add specs, and send pull requests!

Have an awesome idea but not feeling quite up to contributing yet?  Head over to our [official 'suggest an agent' thread](https://github.com/huginn/huginn/issues/353) and tell us!

## Examples

Please check out the [Huginn Introductory Screencast](http://vimeo.com/61976251)!

And now, some example screenshots.  Below them are instructions to get you started.

![Example list of agents](https://raw.githubusercontent.com/huginn/huginn/master/doc/imgs/your-agents.png)

![Event flow diagram](https://raw.githubusercontent.com/huginn/huginn/master/doc/imgs/diagram.png)

![Detecting peaks in a stream of events](https://raw.githubusercontent.com/huginn/huginn/master/doc/imgs/peaks.png)

![Browsing the Events your Agents created](https://raw.githubusercontent.com/huginn/huginn/master/doc/imgs/events.png)

![Logging your location over time](https://raw.githubusercontent.com/huginn/huginn/master/doc/imgs/my-locations.png)

![Making a new agent](https://raw.githubusercontent.com/huginn/huginn/master/doc/imgs/new-agent.png)

## Getting Started

### Try it with Docker

The quickest way to check out Huginn is the official Docker image, which runs everything in one container:

```bash
docker run -it -p 3000:3000 ghcr.io/huginn/huginn
```

Open [http://localhost:3000/](http://localhost:3000/) and log in as `admin` with the password printed once in the container log.  See the [Docker documentation](doc/docker/install.md) for persistent storage, an external database, and the multi-container image.

### Local development

If you want to hack on Huginn, fork this repository and then:

* Run `git remote add upstream https://github.com/huginn/huginn.git` to add the main repository as a remote for your fork.
* Copy `.env.example` to `.env` (`cp .env.example .env`) and edit `.env`, at least updating the `APP_SECRET_TOKEN` variable.
* Make sure that you have MySQL or PostgreSQL installed.  (On a Mac, the easiest way is with [Homebrew](http://brew.sh/).  If you're going to use PostgreSQL, you'll need to prepend all commands below with `DATABASE_ADAPTER=postgresql`.)
* Run `bundle` to install dependencies.
* Run `bundle exec rake db:create`, `bundle exec rake db:migrate`, and then `bundle exec rake db:seed` to create a development database with some example Agents.
* Run `bundle exec foreman start`, visit [http://localhost:3000/](http://localhost:3000/), and log in with the username `admin` and the password printed by `rake db:seed` (or set `SEED_PASSWORD` to choose one).
* Set up some Agents!
* Read the [wiki](https://github.com/huginn/huginn/wiki) for usage examples and to get started making new Agents.
* Periodically run `git fetch upstream` and then `git checkout master && git merge upstream/master` to merge in the newest version of Huginn.

By default, email messages are intercepted in the `development` Rails environment and shown at [http://localhost:3000/letter_opener](http://localhost:3000/letter_opener).  To send real email via SMTP while developing, set `SEND_EMAIL_IN_DEVELOPMENT` to `true` in your `.env` file.

If you need more detailed instructions, see the [Novice setup guide](https://github.com/huginn/huginn/wiki/Novice-setup-guide).

### Running the specs

All Agents have specs, and there are acceptance tests that run Huginn in a headless browser.

* Install Google Chrome and ChromeDriver for local feature specs, or use the Docker-based test environment in [`docker/test/README.md`](docker/test/README.md).
* Run all specs with `bundle exec rspec`, or a single file with `bundle exec rspec path/to/specific/test_spec.rb`.
* Regenerate the screenshots above with `bin/screenshots` after UI changes.

## Deployment

Huginn runs as a web process plus a background worker, backed by MySQL or PostgreSQL.  Pick whichever of the following fits how you run things.

### Docker Compose on your own server

This is the recommended way to run Huginn in production.  The official images are published to `ghcr.io/huginn/huginn` (all processes in one container) and `ghcr.io/huginn/huginn-single-process` (one process per container).  Example Compose files for MySQL and PostgreSQL are in [`docker/single-process/`](docker/single-process/); the [Docker documentation](doc/docker/install.md) explains configuration through environment variables.

The same Compose files work on self-hosted platforms that deploy from Compose, such as [Coolify](https://coolify.io/) and [Dokploy](https://dokploy.com/).

### Managed platforms

Any platform that runs a public Docker image with an always-on worker and a managed database can host Huginn.  Create a web service and a worker service from the single-process image (the worker runs `/scripts/init bin/threaded.rb`), attach a PostgreSQL or MySQL database, and set the environment variables described in the [Docker documentation](doc/docker/install.md).  Platforms known to fit this shape include [Render](https://render.com/docs/deploying-an-image), [Fly.io](https://docs.fly.io/launch/processes), [Railway](https://docs.railway.com/services), and [DigitalOcean App Platform](https://docs.digitalocean.com/products/app-platform/how-to/deploy-from-container-images/).  None of them keeps a worker running on a free tier, so expect a small monthly bill.

Managed Huginn hosting offered by [sponsors](doc/sponsors.md) is listed there, along with the listing policy.  Community-maintained guides for other providers are on the [wiki](https://github.com/huginn/huginn/wiki#deploying-huginn).

### Packaged by the community

Huginn is also packaged for [YunoHost](https://apps.yunohost.org/app/huginn) and available in [Unraid Community Applications](https://unraid.net/community/apps).  These packages are maintained by their communities and may lag behind releases.

### Manual installation on any server

Follow the [installation guide](doc/manual/README.md) to install from source on Ubuntu or Debian.  [Heroku](doc/heroku/install.md) is still supported, but is no longer the cheapest or simplest option.

### Optional configuration

See [doc/manual/configuration.md](doc/manual/configuration.md) for outbound request restrictions on shared instances, the WeatherAgent API key, running without SSL, and private development setups.

## Using Huginn Agent gems

Huginn Agents can be written as external gems and added to your Huginn installation with the `ADDITIONAL_GEMS` environment variable.  See the `Additional Agent gems` section of `.env.example` for more information.

If you'd like to write your own Huginn Agent gem, please see [huginn_agent](https://github.com/huginn/huginn_agent).

Our general intention is to encourage complex and specific Agents to be written as gems, while continuing to add new general-purpose Agents to the core Huginn repository.

## Sponsors

Huginn is maintained in the maintainer's spare time.  You can support its development by [sponsoring the maintainer](https://github.com/sponsors/knu).  Company sponsors and sponsored hosting providers are listed in [doc/sponsors.md](doc/sponsors.md), along with the listing policy.

## License

Huginn is provided under the MIT License.

Huginn was originally created by [@cantino](https://github.com/cantino) in 2013.  Since then, many people's dedicated contributions have made it what it is today.
