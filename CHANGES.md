# Changes

* March 24, 2013 (Huginn 0.1) - Refactored loading of Agents for `check` and `receive` to use ids instead of full objects.  This should fix the too-large delayed_job issues.  Added `system_timer` and `fastercsv` to the Gemfile for the Ruby 1.8 platform.
* March 18, 2013 - Added Wiki page about the [Agent API](https://github.com/cantino/huginn/wiki/Creating-a-new-agent).
* March 17, 2013 - Switched to JSONPath for defining paths through JSON structures.  The WebsiteAgent can now scrape and parse JSON.
