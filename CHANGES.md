# Changes

* Feb 26, 2016   - Added TwitterFavorites Agent for following the favorites of a Twitter user. Thanks @jngai and @bigretromike!
* Feb 26, 2016   - Added HttpStatusAgent for pinging web servers and returning the resulting HTTP status code. Thanks @darrencauthon!
* Feb 20, 2016   - A `from` option can now be specified on email agents. (If you're using Gmail, it may still show your normal address unless you add the new address as a valid sender on the account.)
* Feb 20, 2016   - Added a recommended PORT to the .env.example file.
* Feb 15, 2016   - Allow usage of spring in development by setting SPRING in .env.
* Feb 14, 2016   - Bug fix: missing Credential no longer 500 errors during an import.
* Feb 12, 2016   - Add `no_bulk_receive!` option to ensure Events are processed individually in certain Agents.
* Feb 7, 2016    - Add `http_success_codes` option to the WebsiteAgent to treat more than just 200 as success codes.
* Feb 7, 2016    - Add support for writing Capybara specs.
* Feb 4, 2016    - Bug fix: Fix mysql connection check for multi-process docker image.
* Feb 3, 2016    - The GoogleCalendarPublishAgent now accepts Liquid in the `calendar_id` option.
* Feb 1, 2016    - Fix Guard and add rack-livereload for development.
* Jan 30, 2016   - Add support to the ManualEventAgent for Liquid formatting and creating multiple Events.
* Jan 28, 2016   - PushbulletAgent can push to all devices.
* Jan 26, 2016   - Update Rails to 4.2.5.1 for security and unify configuration files.
* Jan 24, 2016   - Docker upgrades and fixes.
* Jan 22, 2016   - Upgrade devise to 3.5.4 to address CVE-2015-8314.
* Jan 20, 2016   - Update nokogiri for CVE-2015-7499.
* Jan 20, 2016   - Add DigestAgent which collects any Events sent to it and emits them as a single event.
* Jan 16, 2016   - Update celluloid and delayed_job to avoid potential memory issues.
* Jan 16, 2016   - PostAgent can emit Events with the resulting data from the server.
* Jan 15, 2016   - Allow Liquid formatting of the `recipients` option of email Agents.
* Jan 14, 2016   - Add new block tags `regex_replace`/`regex_replace_first` to Liquid.
* Jan 14, 2016   - Events received by the WebsiteAgent do not need to contain a `url` value, switching to usage of `url_from_event` instead.
* Jan 14, 2016   - Liquid block tag `regex_replace` and `regex_replace_first` added.
* Jan 12, 2016   - WebhookAgent supports reCAPTCHA.
* Jan 8, 2016    - Remove schema.rb from git.
* Jan 3, 2016    - Add itunes namespace to DataOutputAgent.
* Dec 26, 2015   - Allow multiple users to import the same Scenario.
* Dec 26, 2015   - WebsiteAgent can accept a `data_from_event` Liquid template instead of a URL.
* Dec 19, 2015   - Update nokogiri to 1.6.7.1 because of security CVEs.
* Dec 10, 2015   - Bug fix: Do not try to load .env file on Heroku.
* Dec 8, 2015    - Export Agents in GUID order in Scenarios.
* Nov 25, 2015   - Update to newest uglifier and nokogiri gems due to security alerts.
* Nov 14, 2015   - Bug fix: WebsiteAgent handles unicode URLs better.
* Nov 12, 2015   - Bug fix: fix a memory leak caused by starting a new LongRunnable::Worker when the old one is still restarting.
* Nov 11, 2015   - EventFormattinghAgent can be dry run.
* Nov 8, 2015    - Added media namespace to DataOutputAgent output, supporting 'media:content' nodes.
* Nov 5, 2015    - Bug fix: CommanderAgent can now be manually run correctly.
* Nov 4, 2015    - DataOutputAgent can push to PubSubHubbub hubs with `push_hubs` option.
* Oct 31, 2015   - DelayAgent `max_emitted_events` option added to limit the number of events which should be created.
* Oct 30, 2015   - TumblrPublishAgent reblog `post_type` added.
* Oct 28, 2015   - TumblrPublishAgent emits the created post.
* Oct 27, 2015   - WebhookAgent can have a custom `response` message.
* Oct 27, 2015   - `DIAGRAM_DEFAULT_LAYOUT` option added to select Graphviz layout.
* Oct 27, 2015   - ShellCommandAgent has new `suppress_on_failure` and `suppress_on_empty_output` options.
* Oct 24, 2015   - TwitterStream does not complain when not configured.
* Oct 23, 2015   - Bug fix: RSSAgent now sorts correctly with `events_order`.
* Oct 22, 2015   - Bug fix: BeeperAgent added to push messages to the Beeper mobile app.
* Oct 20, 2015   - WebsiteAgent unwraps cdata sections in XML.
* Oct 20, 2015   - `force_stop` command added to production.rake.
* Oct 18, 2015   - Bug fix: CommanderAgent can now control any other Agent type.
* Oct 17, 2015   - TwitterSearchAgent added for running period Twitter searches.
* Oct 17, 2015   - GapDetectorAgent added to alert when no data has been seen in a certain period of time.
* Oct 12, 2015   - Slack agent supports attachments.
* Oct 9, 2015    - The TriggerAgent can be asked to match on fewer then all match groups.
* Oct 4, 2015    - Add DelayAgent for buffering incoming Events
* Oct 3, 2015    - Add SSL verification options to smtp.yml
* Oct 3, 2015    - Better handling of 'Back' links in the UI.
* Sep 22, 2015   - Comprehensive EvernoteAgent added
* Sep 13, 2015   - JavaScriptAgent can access and set Credentials.
* Sep 9, 2015    - Add AgentRunner and LongRunnable to support long running agents.
* Sep 8, 2015    - Allow `url_from_event` in the WebsiteAgent to be an Array
* Sep 7, 2015    - Enable `strict: false` in database.yml
* Sep 2, 2015    - WebRequestConcern Agents automatically decode gzip/inflate encodings.
* Sep 1, 2015    - WebhookAgent can configure allowed verbs (GET, POST, PUT, ...) for incoming requests.
* Aug 21, 2015   - PostAgent supports "xml" as `content_type`.
* Aug 3, 2015    - Dry Run allows user to input an event payload.
* Aug 1, 2015    - Huginn now requires Ruby >=2.0 to run.
* Jul 30, 2015   - RssAgent can configure the order of events created via `events_order`.
* Jul 29, 2015   - WebsiteAgent can configure the order of events created via `events_order`.
* Jul 29, 2015   - DataOutputAgent can configure the order of events in the output via `events_order`.
* Jul 20, 2015   - Control Links (used by the SchedularAgent) are correctly exported in Scenarios.
* Jul 20, 2015   - keep\_events\_for was moved from days to seconds; Scenarios have a schema verison.
* Jul 8, 2015    - DataOutputAgent supports feed icon, and a new template variable `events`.
* Jul 1, 2015    - DeDuplicationAgent properly handles destruction of memory.
* Jun 26, 2015   - Add `max_events_per_run` to RssAgent.
* Jun 19, 2015   - Add `url_from_event` to WebsiteAgent.
* Jun 17, 2015   - RssAgent emits events for new feed items in chronological order.
* Jun 17, 2015   - Liquid filter `unescape` added.
* Jun 17, 2015   - Liquid filter `regex_replace` and `regex_replace_first` added, with escape sequence support.
* Jun 15, 2015   - Liquid filter `uri_expand` added.
* Jun 13, 2015   - Liquid templating engine is upgraded to version 3.
* Jun 12, 2015   - RSSAgent can now accept an array of URLs.
* Jun 8, 2015    - WebsiteAgent includes a `use_namespaces` option to enable XML namespaces.
* May 27, 2015   - Validation warns user if they have not provided a `path` when using JSONPath in WebsiteAgent.
* May 24, 2015   - Show Agents' name and user in the jobs panel.
* May 19, 2015   - Add "Dry Run" to the action menu.
* May 23, 2015   - JavaScriptAgent has dry run and inline syntax highlighting JavaScript and CoffeeScript.
* May 11, 2015   - Make delayed\_job sleep\_delay and max\_run\_time .env configurable.
* May 9, 2015    - Add 'unescapeHTML' functionality to the javascript agent.
* May 3, 2015    - Use ActiveJobs interface. 
* Apr 28, 2015   - Adds Wunderlist agent.
* Apr 25, 2015   - Allow user to clear memory of an agent.
* Apr 25, 2015   - Allow WebsiteAgent to unzip compressed JSON.
* Apr 12, 2015   - Allow the webhook agent to loop over returned results if the payload\_path points to an array.
* Mar 27, 2015   - Add wit.ai Agent.
* Mar 24, 2015   - CloudFoundry integration.
* Mar 20, 2015   - Upgrade to Rails 4.2.
* Mar 17, 2015   - Add new "Dry Run" feature for some Agents.
* Feb 26, 2015   - Update to PushBullet API version 2.
* Feb 22, 2015   - Allow Agents to request immediate propagation of Events.
* Feb 18, 2015   - Convert \n to actual line breaks after interpolating liquid and add `line_break_tag`.
* Feb 6, 2015    - Allow UserLocationAgent to accept `min_distance` to require a certain distance traveled.
* Feb 1, 2015    - Allow a `body` key to be provided to set email body in the EmailAgent.
* Jan 21, 2015   - Allow custom icon for Slack webhooks.
* Jan 20, 2015   - Add `max_accuracy` to UserLocationAgent.
* Jan 19, 2015   - WebRequestConcern Agents can supply `disable_ssl_verification` to disable ssl verification.
* Jan 13, 2015   - Docker image updated.
* Jan 8, 2015    - Allow toggling of accuracy when displaying locations in the UserLocationAgent map.
* Dec 26, 2014   - Do not try to monkey patch the mysql adapter on heroku
* Dec 7, 2014    - Update Rails to 4.1.8
* Dec 3, 2014    - Access sites with invalid SSL
* Nov 22, 2014   - Make the website agent support merge events
* Nov 8, 2014    - Added DeDuplicationAgent
* Nov 5, 2014    - Made latlng accessible to liquid
* Nov 4, 2014    - Enable AgentLog to handle a message with invalid byte sequences; upgrade slack-notifier to 1.0.0; use webhook URLs instead of tokens.
* Nov 2, 2014    - Fixes WorkerStatusController for postgresql; updated rails to 4.1.7; added a PDF info agent; commander agent can configure other Agents.
* Nov 1, 2014    - Fixes postgres and DST related spec issues
* Oct 27, 2014   - RSSAgent: Include `url` in addition to `urls` in each event.
* Oct 23, 2014   - Assume an uploaded scenario file (JSON) is encoded in UTF-8
* Oct 20, 2014   - Made weather agent dependent on user location
* Oct 16, 2014   - Make event-indicator a link to the events page, with new events highlighted
* Oct 15, 2014   - Add dropbox agent to emit urls for the given paths
* Oct 14, 2014   - Upgrade Devise to 3.4.0; mqttAgent: Ignore a retained message previously received
* Oct 12, 2014   - Add a button to view full error logs; allow longer than 2000 characters
* Oct 10, 2014   - Dropbox watch agent
* Oct 9, 2014    - Make the scheduler frequency tunable via ENV; add CommanderAgent, which controls other agents on a schedule or incoming event; disable the CSRF warning in WebRequestsController.
* Oct 5, 2014    - OpenShift deployment
* Oct 1, 2014    - Migrate to Rspec3
* Sep 29, 2014   - Refactor OmniAuth integration
* Sep 25, 2014   - TumblrPublishAgent
* Sep 24, 2014   - Refactor OmniAuth configuration and fix it with 37Signals; introduce FontAwesome; enable download of user credentials; improve docs for ForecastIO in WeatherAgent.
* Sep 22, 2014   - Improvements to bin/setup_heroku
* Sep 21, 2014   - Reduce gems to save RAM
* Sep 17, 2014   - Give user an option to drop pending events when enabling an agent.
* Sep 16, 2014   - Improvements to UserLocationAgent
* Sep 14, 2014   - Allow some agents to be configured via HTML forms rather then JSON.
* Sep 13, 2014   - Calculate IDs in RssAgent if none are available.
* Sep 12, 2014   - Make tables sortable by most columns.
* Sep 8, 2014    - SchedulerAgent added, allowing granular control of Agent schedules.  Agents can now control other Agents via `ControlLinks`.
                 - Liquid filter `to_uri` added.
* Sep 7, 2014    - Optional delayed\_job\_web replaced by a custom UI for managing failed and queued jobs.
* Sep 6, 2014    - Agent's `last_event_at` is now updated only on Event creation, not on updates.
* Sep 4, 2014    - Spring, an application preloader intergated with Rails 4.1, has been added.
* Sep 3, 2014    - Liquid interpolation in the WebsiteAgent now has a `_response_` variable available.
* Aug 31, 2014   - Fix a bug where AgentLogs errored after a referenced Event was deleted.
                 - HumanTaskAgent can emit separate events for each answer.
* Aug 30, 2014   - Set charset/collation properly for each text column if using MySQL.
                 - One-click "Deploy to Heroku" button added in README.
* Aug 28, 2014   - Liquid filter `to_xpath` added, which quotes a string for use in XPath expression.
* Aug 26, 2014   - Transition to new Services model for managing external authorization with omniauth.
* Aug 21, 2014   - WebsiteAgent has a new `text` parser type.
                 - Scenario tags have a customizable foreground and background color.
                 - HTML is sanitized and supported in emails.
* Aug 20, 2014   - Support for markdown in Scenario descriptions added.
* Aug 17, 2014   - TwitterStream no longer tries to run disabled Agents.  Sleep and thread bugs fixed in the EM code.
* Aug 13, 2014   - `created_at` added as an available Liquid variable.
                 - Enable Graphviz on Heroku.
* Aug 12, 2014   - Add an environment variable (`DEFAULT_HTTP_USER_AGENT`) to set a global default User-Agent value.
                 - Hover menu to the "Agents" nav link added.
* Aug 9, 2014    - ChangeDetectorAgent added.
* Aug 8, 2014    - Make PostAgent use WebRequestConcern, adding options for Basic Auth and User-Agent.
* Aug 5, 2014    - Use 'net-ftp-list' gem to parse ftp directory listing.
* Aug 1, 2014    - Adding a badge to each Agent node in a diagram.
* Jul 31, 2014   - Allow HipchatAgent to use a shared Credential.
* Jul 29, 2014   - The upstream Agent is now available in the EventFormattingAgent in Liquid via the `agent` key.
                 - The WebsiteAgent is now much more powerful, supporting full XPath evaluations in extractions.
* Jul 26, 2014   - Easy Heroku deployment added and document in the wiki!
* Jul 25, 2014   - Simple RSSAgent added for parsing RSS feeds (the WebsiteAgent has always been able to do this, but this new Agent is simpler).
                 - Nicer Agent diagrams.
* Jul 20, 2014   - Email Agents can send to more than one recipient using the new `recipients` array.
* Jun 29, 2014   - PostAgent can send more HTTP verbs, use both json and html form encoding, and merge event payloads.
* Jun 18, 2014   - Scenarios added, allowing Agents to be grouped, imported, and exported.
                 - `interpolated_options` added so that most Agent options can contain Liquid markup.
* Jun 12, 2014   - XML namespaces are ignored by the WebsiteAgent when evaluating XPath.
* Jun 9, 2014    - User edit form split and cleaned up.
* Jun 8, 2014    - Upgraded to Rails 4.1.1.
* Jun 5, 2014    - MQTTAgent added.
* Jun 1, 2014    - SlackAgent added.
                 - Liquid tag for accessing Credentials added.
                 - Requests to /worker\_status  no longer spam the log.
                 - GoogleCalendarAgent added.
* May 19, 2014   - ImapFolderAgent added.
* May 11, 2014   - Combine some of the Foreman processes into threads for lower memory usage.
* May 6, 2014    - Agents can be disabled or enabled.
* May 5, 2014    - JiraAgent added.
* May 3, 2014    - If you're using Capistrano, `cap sync:db:down` now works correctly to pull your production DB to your local environment.
* May 1, 2014    - Upgrade to Bootstrap 3.1.1
* Apr 20, 2014   - Tons of new additions! FtpsiteAgent; WebsiteAgent has xpath, multiple URL, and encoding support; regexp extractions in EventFormattingAgent; PostAgent takes default params and headers, and can make GET requests; local Graphviz support; ShellCommandAgent; BasecampAgent; HipchatAgent; and lots of bug fixes!
* Apr 10, 2014   - WebHooksController has been renamed to WebRequestsController and all HTTP verbs are now accepted and passed through to Agents' #receive\_web\_request method. The new DataOutputAgent returns JSON or RSS feeds of incoming Events via external web request.  [Documentation is on the wiki.](https://github.com/cantino/huginn/wiki/Creating-a-new-agent#receiving-web-requests).
* Jan 2, 2014    - Agents now have an optional keep\_events\_for option that is propagated to created events' expires\_at field, and they update their events' expires\_at fields on change.
* Jan 1, 2014    - Remove symbolization of memory, options, and payloads; convert memory, options, and payloads to JSON from YAML.  Migration will perform conversion and adjust tables to be UTF-8.  Recommend making a DB backup before migrating.
* Nov 6, 2013    - PeakDetectorAgent now uses `window_duration_in_days` and `min_peak_spacing_in_days`.  Additionally, peaks trigger when the time series rises over the standard deviation multiple, not after it starts to fall.
* Jun 29, 2013   - Removed rails\_admin because it was causing deployment issues. Better to have people install their favorite admin tool if they want one.
* Jun, 2013      - A number of new agents have been contributed, including interfaces to Weibo, Twitter, and Twilio, as well as Agents for translation, sentiment analysis, and for posting and receiving webhooks.
* Mar 24, 2013   - Refactored loading of Agents for `check` and `receive` to use ids instead of full objects.  This should fix the too-large delayed\_job issues.  Added `system_timer` and `fastercsv` to the Gemfile for the Ruby 1.8 platform.
* Mar 18, 2013   - Added Wiki page about the [Agent API](https://github.com/cantino/huginn/wiki/Creating-a-new-agent).
* Mar 17, 2013   - Switched to JSONPath for defining paths through JSON structures.  The WebsiteAgent can now scrape and parse JSON.
