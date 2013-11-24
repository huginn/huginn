# Changes

* 0.2 (Nov 6, 2013)    - PeakDetectorAgent now uses `window_duration_in_days` and `min_peak_spacing_in_days`.  Additionally, peaks trigger when the time series rises over the standard deviation multiple, not after it starts to fall.
* June 29, 2013        - Removed rails\_admin because it was causing deployment issues. Better to have people install their favorite admin tool if they want one.
* June, 2013           - A number of new agents have been contributed, including interfaces to Weibo, Twitter, and Twilio, as well as Agents for translation, sentiment analysis, and for posting and receiving webhooks.
* March 24, 2013 (0.1) - Refactored loading of Agents for `check` and `receive` to use ids instead of full objects.  This should fix the too-large delayed_job issues.  Added `system_timer` and `fastercsv` to the Gemfile for the Ruby 1.8 platform.
* March 18, 2013       - Added Wiki page about the [Agent API](https://github.com/cantino/huginn/wiki/Creating-a-new-agent).
* March 17, 2013       - Switched to JSONPath for defining paths through JSON structures.  The WebsiteAgent can now scrape and parse JSON.
