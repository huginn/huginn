# Changes

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
