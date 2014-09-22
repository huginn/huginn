# Huginn.  Your agents are standing by.

## What is Huginn?

Huginn is a system for building agents that perform automated tasks for you online.  They can read the web, watch for events, and take actions on your behalf.  Huginn's Agents create and consume events, propagating them along a directed graph.  Think of it as a hackable Yahoo! Pipes plus IFTTT on your own server.  You always know who has your data.  You do.

![the origin of the name](doc/imgs/the-name.png)

#### We're just getting started, but here are some of the things that you can do with Huginn right now:

* Track the weather and get an email when it's going to rain (or snow) tomorrow ("Don't forget your umbrella!")
* List terms that you care about and receive emails when their occurrence on Twitter changes.  (For example, want to know when something interesting has happened in the world of Machine Learning?  Huginn will watch the term "machine learning" on Twitter and tell you when there is a large spike.)
* Watch for air travel or shopping deals
* Follow your project names on Twitter and get updates when people mention them
* Scrape websites and receive emails when they change
* Connect to Adioso, HipChat, Basecamp, Growl, FTP, IMAP, Jabber, JIRA, MQTT, nextbus, Pushbullet, Pushover, RSS, Bash, Slack, StubHub, translation APIs, Twilio, Twitter, Wunderground, and Weibo, to name a few.
* Compose digest emails about things you care about to be sent at specific times of the day
* Track counts of high frequency events and send an SMS within moments when they spike, such as the term "san francisco emergency"
* Send and receive WebHooks
* Run arbitrary JavaScript Agents on the server
* Track your location over time
* Create Amazon Mechanical Turk workflows as the inputs, or outputs, of agents.  ("Once a day, ask 5 people for a funny cat photo; send the results to 5 more people to be rated; send the top-rated photo to 5 people for a funny caption; send to 5 final people to rate for funniest caption; finally, post the best captioned photo on my blog.")

Follow [@tectonic](https://twitter.com/tectonic) for updates as Huginn evolves, and join us in [our IRC channel](https://kiwiirc.com/client/irc.freenode.net/?nick=huginn-user|?#huginn) (\#huginn on Freenode) to discuss the project.

### We need your help!

Want to help with Huginn?  All contributions are encouraged!  You could make UI improvements, add new Agents, write documentation and tutorials, or try tackling [issues tagged with #help-wanted](https://github.com/cantino/huginn/issues?direction=desc&labels=help-wanted&page=1&sort=created&state=open).

Really want an issue fixed/feature implemented? Or maybe you just want to solve some community issues and earn some extra coffee money? Then you should take a look at the [current bounties on Bountysource](https://www.bountysource.com/trackers/282580-huginn).

Have an awesome an idea but not feeling quite up to contributing yet? Head over to our [Official 'suggest an agent' thread ](https://github.com/cantino/huginn/issues/353) and tell us about your cool idea!

## Examples

Please checkout the [Huginn Introductory Screencast](http://vimeo.com/61976251)!

And now, some example screenshots.  Below them are instructions to get you started.

![Example list of agents](doc/imgs/your-agents.png)

![Event flow diagram](doc/imgs/diagram.png)

![Detecting peaks in Twitter](doc/imgs/peaks.png)

![Logging your location over time](doc/imgs/my-locations.png)

![Making a new agent](doc/imgs/new-agent.png)

## Getting Started

### Quick Start

If you just want to play around, you can simply fork this repository, then perform the following steps:

* Run `git remote add upstream https://github.com/cantino/huginn.git` to add the main repository as a remote for your fork.
* Copy `.env.example` to `.env` (`cp .env.example .env`) and edit `.env`, at least updating the `APP_SECRET_TOKEN` variable.
* Run `bundle` to install dependencies
* Run `rake db:create`, `rake db:migrate`, and then `rake db:seed` to create a development MySQL database with some example Agents.
* Run `foreman start`, visit [http://localhost:3000/][localhost], and login with the username of `admin` and the password of `password`.
* Setup some Agents!
* Read the [wiki][wiki] for usage examples and to get started making new Agents.
* Periodically run `git fetch upstream` and then `git checkout master && git merge upstream/master` to merge in the newest version of Huginn.

Note: by default, emails are not sent in the `development` Rails environment, which is what you just setup.  If you'd like to enable emails when playing with Huginn locally, edit `config.action_mailer.perform_deliveries` in `config/environments/development.rb`.

If you need more detailed instructions, see the [Novice setup guide][novice-setup-guide].

[localhost]: http://localhost:3000/
[wiki]: https://github.com/cantino/huginn/wiki
[novice-setup-guide]: https://github.com/cantino/huginn/wiki/Novice-setup-guide

## Deployment

[![Deploy](https://www.herokucdn.com/deploy/button.png)](https://heroku.com/deploy)

Huginn can run on Heroku for free!  Please see [the Huginn Wiki](https://github.com/cantino/huginn/wiki#deploying-huginn) for detailed deployment strategies for different providers.

### Optional Setup

#### Setup for private development

See [private development instructions](https://github.com/cantino/huginn/wiki/Private-development-instructions) on the wiki.

#### Enable the WeatherAgent

In order to use the WeatherAgent you need an [API key with Wunderground](http://www.wunderground.com/weather/api/). Signup for one and then change the value of `api_key: your-key` in your seeded WeatherAgent.

#### Disable SSL

We assume your deployment will run over SSL. This is a very good idea! However, if you wish to turn this off, you'll probably need to edit `config/initializers/devise.rb` and modify the line containing `config.rememberable_options = { :secure => true }`.  You will also need to edit `config/environments/production.rb` and modify the value of `config.force_ssl`.

## License

Huginn is provided under the MIT License.

## Community
Huginn has its own IRC channel on freenode: #huginn.
Some of us are hanging out there, come and say hello.

## Contribution

Huginn is a work in progress and is just getting started.  Please get involved!  You can [add new Agents](https://github.com/cantino/huginn/wiki/Creating-a-new-agent), expand the [Wiki](https://github.com/cantino/huginn/wiki), or help us simplify and strengthen the Agent API or core application.

Please fork, add specs, and send pull requests!

[![Build Status](https://travis-ci.org/cantino/huginn.png)](https://travis-ci.org/cantino/huginn) [![Coverage Status](https://coveralls.io/repos/cantino/huginn/badge.png)](https://coveralls.io/r/cantino/huginn) [![Bitdeli Badge](https://d2weczhvl823v0.cloudfront.net/cantino/huginn/trend.png)](https://bitdeli.com/free "Bitdeli Badge") [![Dependency Status](https://gemnasium.com/cantino/huginn.svg)](https://gemnasium.com/cantino/huginn) [![Bountysource](https://www.bountysource.com/badge/tracker?tracker_id=282580)](https://www.bountysource.com/trackers/282580-huginn?utm_source=282580&utm_medium=shield&utm_campaign=TRACKER_BADGE)

