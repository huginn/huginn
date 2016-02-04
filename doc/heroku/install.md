## Deploy to Heroku

Huginn works very well on the cheapest Heroku paid plan. This is what we recommend if you want to use Huginn on Heroku.

Notes for any Heroku plan:

* The `setup_heroku` command points Heroku at a special Procfile (`deployment/heroku/Procfile.heroku`) that is designed to be run on only one Heroku web worker.  If you want to run multiple workers, change the Heroku config variable `PROCFILE_PATH` with `heroku config:set PROCFILE_PATH=./Procfile` and switch back to the standard Huginn Procfile configuration.

If you still wish to use the Heroku free plan (which won't work very well), please understand the following:

* Heroku's [free plan](https://www.heroku.com/pricing) limits total runtime per day to 18 hours. This means that Huginn must sleep some of the time, and so recurring tasks will only run if their recurrence frequency fits within the free plan's awake time, which is 30 minutes. Therefore, we recommend that you only use the every 1 minute, every 2 minute, and every 5 minute Agent scheduling options.
* If you're using the free plan, you need to signup for a free [uptimerobot](https://uptimerobot.com) account and have it ping your Huginn URL on Heroku once every 70 minutes.  If you still receive warnings from Heroku, try a longer interval.
* Heroku's free Postgres plan limits the number of database rows that you can have to 10,000, so you should be sure to set a low event retention schedule for your agents and set `AGENT_LOG_LENGTH`, the number of log lines kept in the DB per Agent, to something small: `heroku config:set AGENT_LOG_LENGTH=20`.

## Instructions

* Install the [Heroku Toolbelt](https://toolbelt.heroku.com/) and then run `heroku login`
* Go into your huginn directory and run `cp .env.example .env && bundle`
* Now, run the magic setup wizard: `bin/setup_heroku`
* That's it!
* If you make changes, you can re-run `bin/setup_heroku`, or just do `git push heroku master`.
* Follow [these instructions](https://github.com/cantino/huginn/blob/master/doc/heroku/update.md) when you want to update your Huginn installation.

### Using your own mail server

```bash
# Outgoing email settings.  To use Gmail or Google Apps, put your Google Apps domain or gmail.com
# as the SMTP_DOMAIN and your Gmail username and password as the SMTP_USER_NAME and SMTP_PASSWORD.
heroku config:set SMTP_DOMAIN=your-domain-here.com
heroku config:set SMTP_USER_NAME=you@gmail.com
heroku config:set SMTP_PASSWORD=somepassword
heroku config:set SMTP_SERVER=smtp.gmail.com

# The address from which system emails will appear to be sent.
heroku config:set EMAIL_FROM_ADDRESS=you@gmail.com
```

### Backing up your data

See: https://devcenter.heroku.com/articles/heroku-postgres-import-export

### Example output from `bin/setup_heroku`

```
~/projects/oss/huginn (master)$ bin/setup_heroku 

Welcome andrew@example.com!  It looks like you're logged into Heroku.

It looks like you don't have a Heroku app set up yet for this repo.
You can either exit now and run 'heroku create', or I can do it for you.
Would you like me to create a Heroku app for you now in this repo? (y/n) y
Creating radiant-forest-1519... done, stack is cedar
http://radiant-forest-1519.herokuapp.com/ | git@heroku.com:radiant-forest-1519.git
Git remote heroku added
Your Heroku app name is radiant-forest-1519.  Is this correct? (y/n) y
Setting up APP_SECRET_TOKEN...
Setting BUILDPACK_URL to https://github.com/ddollar/heroku-buildpack-multi.git
BUILDPACK_URL: https://github.com/ddollar/heroku-buildpack-multi.git
Setting PROCFILE_PATH to deployment/heroku/Procfile.heroku
PROCFILE_PATH: deployment/heroku/Procfile.heroku
Setting ON_HEROKU to true
Setting FORCE_SSL to true
Setting DOMAIN to radiant-forest-1519.herokuapp.com

You need to set an invitation code for your Huginn instance.  If you plan to share this instance, you will
tell this code to anyone who you'd like to invite.  If you won't share it, then just set this to something
that people will not guess.
What code would you like to use? 
What code would you like to use? something-secret
Setting INVITATION_CODE to something-secret

Okay, let's setup outgoing email settings.  The simplest solution is to use the free sendgrid Heroku addon.
If you'd like to use your own server, or your Gmail account, please see .env.example and set
SMTP_DOMAIN, SMTP_USER_NAME, SMTP_PASSWORD, and SMTP_SERVER with 'heroku config:set'.
Should I enable the free sendgrid addon? (y/n) y
Use `heroku addons:docs sendgrid` to view documentation.
SMTP_SERVER: smtp.sendgrid.net
SMTP_DOMAIN: heroku.com
SMTP_USER_NAME: app27830035@heroku.com
SMTP_PASSWORD: sflajgz0
What email address would you like email to appear to be sent from? andrew@example.com
Setting EMAIL_FROM_ADDRESS to andrew@example.com
EMAIL_FROM_ADDRESS: andrew@example.com

Should I push your current branch (master) to heroku? (y/n) y
This may take a moment...
Initializing repository, done.

-----> Fetching custom git buildpack... done
-----> Multipack app detected
=====> Downloading Buildpack: https://github.com/cantino/heroku-selectable-procfile.git
=====> Detected Framework: Selectable Procfile
-----> Using deployment/heroku/Procfile.heroku as Procfile
=====> Downloading Buildpack: https://github.com/heroku/heroku-buildpack-ruby.git
=====> Detected Framework: Ruby
-----> Compiling Ruby/Rails
-----> Using Ruby version: ruby-2.0.0
-----> Installing dependencies using 1.6.3
       Running: bundle install --without development:test --path vendor/bundle --binstubs vendor/bundle/bin -j4 --deployment
       Fetching source index from https://rubygems.org/
       Fetching git://github.com/cantino/twitter-stream.git
       Installing i18n 0.6.9
       Installing rake 10.3.2
       Installing minitest 5.3.5
       [...gems are installed...]
       Your bundle is complete!
       Gems in the groups development and test were not installed.
       It was installed into ./vendor/bundle
       Post-install message from httparty:
       When you HTTParty, you must party hard!
       Post-install message from rufus-scheduler:
       Bundle completed (133.85s)
       Cleaning up the bundler cache.
-----> Preparing app for Rails asset pipeline
       Running: rake assets:precompile
       I, [2014-07-26T20:36:06.069156 #5939]  INFO -- : Writing /tmp/build_7b0d30bd-3c35-46dc-b73d-b5f05754d340/public/assets/select2x2-ec4bf2b76c97838b357413d72a2f69cf.png [...]
       Asset precompilation completed (42.28s)
       Cleaning assets
       Running: rake assets:clean

Using release configuration from last framework (Ruby).
-----> Discovering process types
       Procfile declares types     -> web
       Default types for Multipack -> console, rake, worker

-----> Compressing... done, 45.1MB
-----> Launching... done, v19
       http://radiant-forest-1519.herokuapp.com/ deployed to Heroku

To git@heroku.com:radiant-forest-1519.git
 * [new branch]      master -> master
Running database migrations...
Running `rake db:migrate` attached to terminal... up, run.3341

[...migrations run...]

I can make an admin user on your new Huginn instance and setup some example Agents.
Should I create a new admin user and some example Agents? (y/n) y

Okay, what is your email address? andrew@example.com
And what username would you like to login as? andrew
Finally, what password would you like to use? 
Just a moment...


Okay, you should be all set!  Visit https://radiant-forest-1519.herokuapp.com and login as 'andrew' with your password.

Done!
```
