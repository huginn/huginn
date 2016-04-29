![Huginn](https://raw.github.com/cantino/huginn/master/media/huginn-logo.png "Your agents are standing by.")

-----

## What is Huginn?

Huginn is a system for building agents that perform automated tasks for you online.  They can read the web, watch for events, and take actions on your behalf.  Huginn's Agents create and consume events, propagating them along a directed graph.  Think of it as a hackable Yahoo! Pipes plus IFTTT on your own server.  You always know who has your data.  You do.

![the origin of the name](https://raw.githubusercontent.com/cantino/huginn/master/doc/imgs/the-name.png)

#### Here are some of the things that you can do with Huginn:

* Track the weather and get an email when it's going to rain (or snow) tomorrow ("Don't forget your umbrella!")
* List terms that you care about and receive emails when their occurrence on Twitter changes.  (For example, want to know when something interesting has happened in the world of Machine Learning?  Huginn will watch the term "machine learning" on Twitter and tell you when there is a spike in discussion.)
* Watch for air travel or shopping deals
* Follow your project names on Twitter and get updates when people mention them
* Scrape websites and receive emails when they change
* Connect to Adioso, HipChat, Basecamp, Growl, FTP, IMAP, Jabber, JIRA, MQTT, nextbus, Pushbullet, Pushover, RSS, Bash, Slack, StubHub, translation APIs, Twilio, Twitter, Wunderground, and Weibo, to name a few.
* Send digest emails with things that you care about at specific times during the day
* Track counts of high frequency events and send an SMS within moments when they spike, such as the term "san francisco emergency"
* Send and receive WebHooks
* Run custom JavaScript or CoffeeScript functions
* Track your location over time
* Create Amazon Mechanical Turk workflows as the inputs, or outputs, of agents (the Amazon Turk Agent is called the "HumanTaskAgent"). For example: "Once a day, ask 5 people for a funny cat photo; send the results to 5 more people to be rated; send the top-rated photo to 5 people for a funny caption; send to 5 final people to rate for funniest caption; finally, post the best captioned photo on my blog."

[![Gitter](https://badges.gitter.im/Join%20Chat.svg)](https://gitter.im/cantino/huginn?utm_source=badge&utm_medium=badge&utm_campaign=pr-badge&utm_content=badge) [![Changelog #199](https://img.shields.io/badge/changelog-%23199-lightgrey.svg)](https://changelog.com/199)

Join us in our [Gitter room](https://gitter.im/cantino/huginn) to discuss the project and follow [@tectonic](https://twitter.com/tectonic) for updates as Huginn evolves.

### Join us!

Want to help with Huginn?  All contributions are encouraged!  You could make UI improvements, [add new Agents](https://github.com/cantino/huginn/wiki/Creating-a-new-agent), write [documentation and tutorials](https://github.com/cantino/huginn/wiki), or try tackling [issues tagged with #help-wanted](https://github.com/cantino/huginn/issues?direction=desc&labels=help-wanted&page=1&sort=created&state=open).  Please fork, add specs, and send pull requests!

Really want a fix or feature? Want to solve some community issues and earn some extra coffee money? Take a look at the [current bounties on Bountysource](https://www.bountysource.com/trackers/282580-huginn).

Have an awesome idea but not feeling quite up to contributing yet? Head over to our [Official 'suggest an agent' thread ](https://github.com/cantino/huginn/issues/353) and tell us!

## Examples

Please checkout the [Huginn Introductory Screencast](http://vimeo.com/61976251)!

And now, some example screenshots.  Below them are instructions to get you started.

![Example list of agents](https://raw.githubusercontent.com/cantino/huginn/master/doc/imgs/your-agents.png)

![Event flow diagram](https://raw.githubusercontent.com/cantino/huginn/master/doc/imgs/diagram.png)

![Detecting peaks in Twitter](https://raw.githubusercontent.com/cantino/huginn/master/doc/imgs/peaks.png)

![Logging your location over time](https://raw.githubusercontent.com/cantino/huginn/master/doc/imgs/my-locations.png)

![Making a new agent](https://raw.githubusercontent.com/cantino/huginn/master/doc/imgs/new-agent.png)

## Getting Started

### Docker

The quickest and easiest way to check out Huginn is to use the official Docker image. Have a look at the [documentation](https://github.com/cantino/huginn/blob/master/doc/docker/install.md).

### Local Installation

If you just want to play around, you can simply fork this repository, then perform the following steps:

* Run `git remote add upstream https://github.com/cantino/huginn.git` to add the main repository as a remote for your fork.
* Copy `.env.example` to `.env` (`cp .env.example .env`) and edit `.env`, at least updating the `APP_SECRET_TOKEN` variable.
* Run `bundle` to install dependencies
* Run `bundle exec rake db:create`, `bundle exec rake db:migrate`, and then `bundle exec rake db:seed` to create a development MySQL database with some example Agents.
* Run `bundle exec foreman start`, visit [http://localhost:3000/][localhost], and login with the username of `admin` and the password of `password`.
* Setup some Agents!
* Read the [wiki][wiki] for usage examples and to get started making new Agents.
* Periodically run `git fetch upstream` and then `git checkout master && git merge upstream/master` to merge in the newest version of Huginn.

Note: By default, emails are intercepted in the `development` Rails environment, which is what you just setup.  You can view 
them at [http://localhost:3000/letter_opener](http://localhost:3000/letter_opener). If you'd like to send real emails via SMTP when playing 
with Huginn locally, set `SEND_EMAIL_IN_DEVELOPMENT` to `true` in your `.env` file.

If you need more detailed instructions, see the [Novice setup guide][novice-setup-guide].

[localhost]: http://localhost:3000/
[wiki]: https://github.com/cantino/huginn/wiki
[novice-setup-guide]: https://github.com/cantino/huginn/wiki/Novice-setup-guide

### Nitrous Quickstart

You can quickly create a free development environment for this Huginn project in the cloud on www.nitrous.io:

<a href="https://www.nitrous.io/quickstart">
  <img src="https://nitrous-image-icons.s3.amazonaws.com/quickstart.png" alt="Nitrous Quickstart" width=142 height=34>
</a>

In the IDE, start Huginn via `Run > Start Huginn` and access your site via `Preview > 3000`.

### Develop

All agents have specs! And there's also acceptance tests that simulate running Huginn in a headless browser. 

* Install PhantomJS 2.1.1 or greater: 
  * Using [Node Package Manager](https://www.npmjs.com/): `npm install phantomjs` 
  * Using [Homebrew](http://brew.sh/) on OSX `brew install phantomjs`
* Run all specs with `bundle exec rspec`
* Run a specific spec with `bundle exec rspec path/to/specific/test_spec.rb`. 
* Read more about rspec for rails [here](https://github.com/rspec/rspec-rails).

## Deployment

### Heroku

Try Huginn on Heroku: [![Deploy](https://www.herokucdn.com/deploy/button.png)](https://heroku.com/deploy) (Takes a few minutes to setup. Read the [documentation](https://github.com/cantino/huginn/blob/master/doc/heroku/install.md) while you are waiting and be sure to click 'View it' after launch!)

Huginn works on the free version of Heroku [with significant limitations](https://github.com/cantino/huginn/blob/master/doc/heroku/install.md). For non-experimental use, we strongly recommend Heroku's cheapest paid plan or our Docker container.

Please see [the Huginn Wiki](https://github.com/cantino/huginn/wiki#deploying-huginn) for detailed deployment strategies for different providers.

### Manual installation on any server

Have a look at the [installation guide](https://github.com/cantino/huginn/blob/master/doc/manual/README.md).

### Optional Setup

#### Setup for private development

See [private development instructions](https://github.com/cantino/huginn/wiki/Private-development-instructions) on the wiki.

#### Enable the WeatherAgent

In order to use the WeatherAgent you need an [API key with Wunderground](http://www.wunderground.com/weather/api/). Signup for one and then change the value of `api_key: your-key` in your seeded WeatherAgent.

#### Disable SSL

We assume your deployment will run over SSL. This is a very good idea! However, if you wish to turn this off, you'll probably need to edit `config/initializers/devise.rb` and modify the line containing `config.rememberable_options = { :secure => true }`.  You will also need to edit `config/environments/production.rb` and modify the value of `config.force_ssl`.

## License

Huginn is provided under the MIT License.

[![Build Status](https://travis-ci.org/cantino/huginn.svg)](https://travis-ci.org/cantino/huginn) [![Coverage Status](https://coveralls.io/repos/cantino/huginn/badge.svg)](https://coveralls.io/r/cantino/huginn) [![Bitdeli Badge](https://d2weczhvl823v0.cloudfront.net/cantino/huginn/trend.png)](https://bitdeli.com/free "Bitdeli Badge") [![Dependency Status](https://gemnasium.com/cantino/huginn.svg)](https://gemnasium.com/cantino/huginn) [![Bountysource](https://www.bountysource.com/badge/tracker?tracker_id=282580)](https://www.bountysource.com/trackers/282580-huginn?utm_source=282580&utm_medium=shield&utm_campaign=TRACKER_BADGE)

