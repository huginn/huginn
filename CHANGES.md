# Changes

* 0.5 (April 20, 2014) - Tons of new additions! FtpsiteAgent; WebsiteAgent has xpath, multiple URL, and encoding support; regexp extractions in EventFormattingAgent; PostAgent takes default params and headers, and can make GET requests; local Graphviz support; ShellCommandAgent; BasecampAgent; HipchatAgent; and lots of bug fixes!
* 0.4 (April 10, 2014) - WebHooksController has been renamed to WebRequestsController and all HTTP verbs are now accepted and passed through to Agents' #receive\_web\_request method. The new DataOutputAgent returns JSON or RSS feeds of incoming Events via external web request.  [Documentation is on the wiki.](https://github.com/cantino/huginn/wiki/Creating-a-new-agent#receiving-web-requests).
* 0.31 (Jan 2, 2014)   - Agents now have an optional keep\_events\_for option that is propagated to created events' expires\_at field, and they update their events' expires\_at fields on change.
* 0.3 (Jan 1, 2014)    - Remove symbolization of memory, options, and payloads; convert memory, options, and payloads to JSON from YAML.  Migration will perform conversion and adjust tables to be UTF-8.  Recommend making a DB backup before migrating.
* 0.2 (Nov 6, 2013)    - PeakDetectorAgent now uses `window_duration_in_days` and `min_peak_spacing_in_days`.  Additionally, peaks trigger when the time series rises over the standard deviation multiple, not after it starts to fall.
* June 29, 2013        - Removed rails\_admin because it was causing deployment issues. Better to have people install their favorite admin tool if they want one.
* June, 2013           - A number of new agents have been contributed, including interfaces to Weibo, Twitter, and Twilio, as well as Agents for translation, sentiment analysis, and for posting and receiving webhooks.
* March 24, 2013 (0.1) - Refactored loading of Agents for `check` and `receive` to use ids instead of full objects.  This should fix the too-large delayed\_job issues.  Added `system_timer` and `fastercsv` to the Gemfile for the Ruby 1.8 platform.
* March 18, 2013       - Added Wiki page about the [Agent API](https://github.com/cantino/huginn/wiki/Creating-a-new-agent).
* March 17, 2013       - Switched to JSONPath for defining paths through JSON structures.  The WebsiteAgent can now scrape and parse JSON.
