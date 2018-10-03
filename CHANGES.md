# Changes

| DateOfChange   | Changes                                                                                                      |
|----------------|--------------------------------------------------------------------------------------------------------------|
| Oct 03, 2018   | Added support for MySQL 8 and MariaDB 10.3. Dropped support for MySQL < 5.5 and PostgreSQL < 9.2 [2384](https://github.com/huginn/huginn/pull/2384) |
| Sep 15, 2017   | Tweets view of `TwitterStreamAgent` has been enhanced. [2122](https://github.com/huginn/huginn/pull/2122) |
| Sep 09, 2017   | Agent objects in Liquid templating now have new properties `working` and `url`. [2118](https://github.com/huginn/huginn/pull/2118) |
| Sep 06, 2017   | `DataOutputAgent` includes an icon in a podcast feed. [2114](https://github.com/huginn/huginn/pull/2114) |
| Sep 05, 2017   | `DataOutputAgent` can properly output an RSS feed with items containing  multiple categories, enclosures, etc. [2110](https://github.com/huginn/huginn/pull/2110) |
| Aug 07, 2017   | `ImapFolderAgent` can now include a `Message-ID` and optionally a raw mail blob in each created event. [2076](https://github.com/huginn/huginn/pull/2076) |
| Aug 01, 2017   | `GrowlAgent` supports new API parameters `sticky`, `priority` and `callback_url`. [2074](https://github.com/huginn/huginn/pull/2074) |
| Jul 31, 2017   | `PostAgent` now has a `merge` mode that can be enabled via the `output_mode` new option. [2069](https://github.com/huginn/huginn/pull/2069) |
| Jul 20, 2017   | Agent editor has a selectable `contollers` field. [2063](https://github.com/huginn/huginn/pull/2063) |
| Jul 20, 2017   | Receivers are now inherited when cloning an agent. [2063](https://github.com/huginn/huginn/pull/2063)|
| Jul 18, 2017   | `DigestAgent` gets a new option `retained_events`. [2041](https://github.com/huginn/huginn/pull/2041) |
| Jul 10, 2017   | `CommanderAgent` can now refer to `target` to determine what to do for each target agent. [2053](https://github.com/huginn/huginn/pull/2053)   |
| Jul 10, 2017   | Update Google API Client. May break backwards compatibility for GoogleCalendarPublishAgent. [2047](https://github.com/huginn/huginn/pull/2047)   |
| Jun 06, 2017   | Addressed the problem with MySQL resetting auto_increment after events get emptied and the server reboots. [1974](https://github.com/huginn/huginn/pull/1974), [2014](https://github.com/huginn/huginn/pull/2014) |
| May 30, 2017   | Support Ruby 2.4. [1876](https://github.com/huginn/huginn/pull/1876) |
| May 25, 2017   | PeakDetectorAgent now has a configurable `search_url`. [2013](https://github.com/huginn/huginn/pull/2013) |
| May 19, 2017   | Upgrade Rails to 5.1. [1912](https://github.com/huginn/huginn/pull/1912) |
| May 18, 2017   | `ShellCommandAgent` gets a new option `unbundle`. [1990](https://github.com/huginn/huginn/pull/1990) |
| May 11, 2017   | `PeakDetectorAgent` gets a new option `min_events`. [1924](https://github.com/huginn/huginn/pull/1924) |
| May 11, 2017   | Switch back to the much improved `jsonpath` gem after `jsonpathv2` gets merged to mainline. [1996](https://github.com/huginn/huginn/pull/1996), [1997](https://github.com/huginn/huginn/pull/1997), [2017](https://github.com/huginn/huginn/pull/2017) |
| Apr 27, 2017   | Add custom response header support to DataOutputAgent, WebhookAgent and LiquidOutputAgent. [1977](https://github.com/huginn/huginn/pull/1977) |
| Apr 27, 2017   | Upgrade Liquid to 4.0. [1982](https://github.com/huginn/huginn/pull/1982) |
| Apr 26, 2017   | Add `GoogleTranslationAgent`. [1978](https://github.com/huginn/huginn/pull/1978) |
| Apr 19, 2017   | `DataOutputAgent` now serves RSS output as `application/rss+xml` by default. (existing agents are automatically configured to use `text/xml`) [1973](https://github.com/huginn/huginn/pull/1973) |
| Apr 08, 2017   | Add `TumblrLikesAgent`. [1923](https://github.com/huginn/huginn/pull/1923) |
| Mar 31, 2017   | `ChangeDetectorAgent` can now refer to `last_property`. [1950](https://github.com/huginn/huginn/pull/1950) |
| Feb 01, 2017   | `GoogleFlightsAgent` supports choice of carrier and alliance. [1878](https://github.com/huginn/huginn/pull/1878) |
| Jan 29, 2017   | `WebhookAgent` can redirect to any URL after successful submission. [1923](https://github.com/huginn/huginn/pull/1923) |
| Jan 06, 2017   | Agent's id of each incoming event is accessible from Liquid and JavaScriptAgent. [1860](https://github.com/huginn/huginn/pull/1860) |
| Jan 06, 2017   | "Every X" schedules now run on fixed times. [1844](https://github.com/huginn/huginn/pull/1844) |
| Jan 03, 2017   | Twitter agents support "extended" tweets that are longer than 140 characters. [1847](https://github.com/huginn/huginn/pull/1847) |
| Jan 01, 2017   | A new `include_sort_info` Agent option is added to help sort out an Nth event of a series of events created in a run. [1772](https://github.com/huginn/huginn/pull/1772) |
| Nov 30, 2016   | `RssAgent` includes podcast tag values in events created from a podcast feed. [1782](https://github.com/huginn/huginn/pull/1782) |
| Nov 28, 2016   | Remove `BeeperAgent` after Beeper.io shuts down. [1808](https://github.com/huginn/huginn/pull/1808) |
| Nov 27, 2016   | `WebsiteAgent` can interpolate via the `template` option after extraction. [1743](https://github.com/huginn/huginn/pull/1743), [1816](https://github.com/huginn/huginn/pull/1816) |
| Nov 20, 2016   | `WebsiteAgent` provides a new extractor option `repeat`. [1769](https://github.com/huginn/huginn/pull/1769) |
| Oct 27, 2016   | `WebsiteAgent` now has improved encoding detection for HTML/XML documents. [1751](https://github.com/huginn/huginn/pull/1751) |
| Oct 17, 2016   | Normalize URL in `to_uri` and `uri_expand` liquid filters.                                                   |
| Oct 06, 2016   | `RssAgent` is reimplemented migrating its underlying feed parser from FeedNormalizer to Feedjira. [1564](https://github.com/huginn/huginn/pull/1564)     |
| Oct 05, 2016   | Migrate to Rails 5. [1688](https://github.com/huginn/huginn/pull/1688)                                      |
| Oct 05, 2016   | Improve URL normalization in `WebsiteAgent`. [1719](https://github.com/huginn/huginn/pull/1719)             |
| Oct 05, 2016   | `PushoverAgent` now treats parameter options as templates rather than default values. [1720](https://github.com/huginn/huginn/pull/1720) |
| Sep 19, 2016   | Add multipart file upload to `PostAgent`. [1690](https://github.com/huginn/huginn/pull/1690)                |
| Sep 08, 2016   | Allow `TwitterUserAgent` to retry failed actions. [1645](https://github.com/huginn/huginn/pull/1645)        |
| Aug 16, 2016   | `EmailDigestAgent` now relies on received events, rather in memory. [1624](https://github.com/huginn/huginn/pull/1624) |
| Aug 08, 2016   | `DataOutputAgent` now limits events after ordering. [1444](https://github.com/huginn/huginn/pull/1444)      |
| Aug 05, 2016   | Add `api_key` option to `UserLocationAgent`. [1613](https://github.com/huginn/huginn/pull/1613)             |
| Jul 25, 2016   | Add `LiquidOutputAgent`. [1587](https://github.com/huginn/huginn/pull/1587)                                 |
| Jul 25, 2016   | Allow `PostAgent` headers to interpolate event data. [1606](https://github.com/huginn/huginn/pull/1606)     |
| Jul 25, 2016   | Remove `smtp.yml` configuration file, the SMTP configuration now needs to be done via environment variables. [1595](https://github.com/huginn/huginn/pull/1595) |
| Jul 25, 2016   | Change `jsonpath` gem to a fork located at [https://github.com/Skarlso/jsonpathv2](https://github.com/Skarlso/jsonpathv2) [1596](https://github.com/huginn/huginn/pull/1596) |
| Jul 20, 2016   | Add redirection information to the `HttpStatusAgent` [1590](https://github.com/huginn/huginn/pull/1590) |
| Jul 15, 2016   | Add `changes_only` option to `HttpStatusAgent` which only emit events then the HTTP status changed. [1582](https://github.com/huginn/huginn/pull/1582) |
| Jul 09, 2016   | Add `AttributeDifferenceAgent`. [1572](https://github.com/huginn/huginn/pull/1572) |
| Jul 04, 2016   | Add `setMemory` function to the `JavaScriptAgent`. [1576](https://github.com/huginn/huginn/pull/1576) |
| Jul 01, 2016   | Allow decimal values to be shown on the `PeakDetectorAgent` graphs. [1574](https://github.com/huginn/huginn/pull/1574) |
| Jun 30, 2016   | Update Heroku installation documentation to match their recent change of creating empty git repositories. [1570](https://github.com/huginn/huginn/pull/1570) |
| Jun 24, 2016   | Docker images: Fix usage of special characters in environment configuration and passing of additional env variables. [1560](https://github.com/huginn/huginn/pull/1560) |
| Jun 23, 2016   | Return to Agent's Events when clicking on the Back button in the Event show page.  [1555](https://github.com/huginn/huginn/pull/1555) |
| Jun 23, 2016   | Allow usage of the `style` tag in E-Mail Agents [1557](https://github.com/huginn/huginn/pull/1557) |
| Jun 21, 2016   | Allow to create custom Agent gems and load them with `ADDITIONAL_GEMS`. [1366](https://github.com/huginn/huginn/pull/1366)<br> Look at the [huginn_agent README](https://github.com/huginn/huginn_agent/) for documentation on how to create Agent gems.<br>Currently available Agent gems:<ul><li>[HuginnNlpAgents](https://github.com/kreuzwerker/DKT.huginn_nlp_agents) - query the FREME and DKT Natural Language Processing APIs</li><li>[HuginnWebsiteMetadataAgent](https://github.com/kreuzwerker/DKT.huginn_website_metadata_agent) - Extracts schema.org microdata, embedded JSON-LD and common metadata tag attributes from HTML</li><li>[HuginnReadabilityAgent](https://github.com/kreuzwerker/DKT.huginn_readability_agent) - extracts te primary readable content of a website using the [readability](https://github.com/cantino/ruby-readability) gem</li></ul>   |
| Jun 20, 2016   | Allow `HttpStatusAgent` include received HTTP header value in emitted Events. [1521](https://github.com/huginn/huginn/pull/1521) |
| Jun 20, 2016   | Fix setting a memory key to falsy values with `this.memory(key, falsy)` in the `JavaScriptAgent`. [1551](https://github.com/huginn/huginn/pull/1551) |
| Jun 18, 2016   | Add `not in` comparison type to the `TriggerAgent`. [1545](https://github.com/huginn/huginn/pull/1545) |
| Jun 18, 2016   | Ensure the Agent memory is set when triggering a dry run from the Agent show page. [1550](https://github.com/huginn/huginn/pull/1550) |
| Jun 16, 2016   | Allow to set an icon for Scenarios [1427](https://github.com/huginn/huginn/pull/1427) |
| Jun 16, 2016   | Add `deleteKey` function to `JavascriptAgent` to delete a key from the Agent's memory. [1543](https://github.com/huginn/huginn/pull/1543) |
| Jun 14, 2016   | Allow the `DropboxFileUrlAgent` to emit permanent Dropbox links. [1541](https://github.com/huginn/huginn/pull/1541) |
| Jun 14, 2016   | Add button to enable or disable all Agents of a Scenario. [1506](https://github.com/huginn/huginn/pull/1506) |
| Jun 14, 2016   | Update nokogiri to 1.6.8 for security fixes. [1540](https://github.com/huginn/huginn/pull/1540) |
| Jun 08, 2016   | Fix multi-process Docker image on the overlay storage driver. [1537](https://github.com/huginn/huginn/pull/1537) |
| Jun 05, 2016   | Fix storing array/hashes in the `JavaScriptAgent`s memory. [1524](https://github.com/huginn/huginn/pull/1524) |
| May 31, 2016   | Add Agent connection status icons to Agent table. [1482](https://github.com/huginn/huginn/pull/1482) |
| May 29, 2016   | Add time tracking to `HttpStatusAgent`. [1517](https://github.com/huginn/huginn/pull/1517) |
| May 20, 2016   | Add `parse_mode` option to `TelegramAgent` to embed HTML or Markdown. [1509](https://github.com/huginn/huginn/pull/1509) |
| May 18, 2016   | Show recently received events in dry run modal. [1483](https://github.com/huginn/huginn/pull/1483) |
| May 16, 2016   | Prevent duplicate events from being generated when using DelayedJob and Postgres. [1501](https://github.com/huginn/huginn/pull/1501) |
| May 12, 2016   | Improve Agent and Scenario forms: Allow to configure the Agents event target and to jump to source/target Agent from the edit form. [1447](https://github.com/huginn/huginn/pull/1447) |
| May 10, 2016   | Add button to toggle visibility of disabled Agents. [1464](https://github.com/huginn/huginn/pull/1464) |
| May 09, 2016   | Fix usage of deprecated API version in `TwitterStreamAgent`. [1492](https://github.com/huginn/huginn/pull/1492) |
| Apr 30, 2016   | Make XML namespaces of `DataOutputAgent` optional. [1411](https://github.com/huginn/huginn/pull/1411) |
| Apr 29, 2016   | Fix internal Jobs being shown as deleted in Job Management page. [1462](https://github.com/huginn/huginn/pull/1462) |
| Apr 27, 2016   | Fix issue in default NGINX SSL configuration. [1455](https://github.com/huginn/huginn/pull/1455) |
| Apr 26, 2016   | Add `TwitterActionAgent` to retweet or favorite tweets. [#1181](https://github.com/huginn/huginn/pull/1181) |
| Apr 26, 2016   | Validate Agent options JSON before submitting it. [1434](https://github.com/huginn/huginn/pull/1434) |
| Apr 24, 2016   | Allow to delete the Scenario's Agents with it. [1446](https://github.com/huginn/huginn/pull/1446) |
| Apr 22, 2016   | Allow to (re)import exported Credential JSON files. [1394](https://github.com/huginn/huginn/pull/1394) |
| Apr 20, 2016   | Add `TwilioReceiveTextAgent`. [1418](https://github.com/huginn/huginn/pull/1418) |
| Apr 19, 2016   | Add Nitrous.io Quickstart button. [1428](https://github.com/huginn/huginn/pull/1428) |
| Apr 19, 2016   | Do not run/enqueue event propagation when a `AgentPropagateJob` is already enqueued. [1432](https://github.com/huginn/huginn/pull/1432) |
| Apr 19, 2016   | Fix publishing to MQTT channels with the `MqttAgent`. [1440](https://github.com/huginn/huginn/pull/1440) |
| Apr 16, 2016   | Pass request headers to receive_web_request. [1415](https://github.com/huginn/huginn/pull/1415) |
| Apr 13, 2016   | Add button to Job Management page retry all queued Jobs. [1423](https://github.com/huginn/huginn/pull/1423) |
| Apr 12, 2016   | Allow to configure the format of header names in Events that `PostAgent` emits. [1340](https://github.com/huginn/huginn/pull/1340) |
| Apr 11, 2016   | Allow to provide a custom scenario JSON for new Users via `DEFAULT_SCENARIO_FILE`. [1404](https://github.com/huginn/huginn/pull/1404) |
| Apr 10, 2016   | Improve docker images and tag every image with the commit SHA. [1359](https://github.com/huginn/huginn/pull/1359) |
| Apr 10, 2016   | Fix SMS sending in `TwilloAgent`. [1414](https://github.com/huginn/huginn/pull/1414) |
| Apr 05, 2016   | Simplify the log format for Dry Run. [1386](https://github.com/huginn/huginn/pull/1386) |
| Apr 04, 2016   | `PostAgent` allow sending arbitrary string data. [1402](https://github.com/huginn/huginn/pull/1402) |
| Mar 31, 2016   | Add `TelegramAgent`. [1381](https://github.com/huginn/huginn/pull/1381) |
| Mar 30, 2016   | Add Agent actions menu to Agent show and Agent Events page. [1374](https://github.com/huginn/huginn/pull/1374) |
| Mar 30, 2016   | Add round trip option to `GoogleFlightsAgent`. [1384](https://github.com/huginn/huginn/pull/1384) |
| Mar 30, 2016   | Ensure cloned Agents stay in the same Scenario. [1377](https://github.com/huginn/huginn/pull/1377) |
| Mar 27, 2016   | Allow usage of HTML table tags/attributes in E-Mail Agents. [1380](https://github.com/huginn/huginn/pull/1380) |
| Mar 27, 2016   | Add tabs to Dry Run result modal. [1371](https://github.com/huginn/huginn/pull/1371) |
| Mar 26, 2016   | Make DelayedJob logs visible when running in foreground. [1360](https://github.com/huginn/huginn/pull/1360) |
| Mar 26, 2016   | Add `GoogleFlightsAgent`. [1367](https://github.com/huginn/huginn/pull/1367) |
| Mar 22, 2016   | Add `JsonParseAgent`. [1364](https://github.com/huginn/huginn/pull/1364) |
| Mar 21, 2016   | Add `AftershipAgent`. [1354](https://github.com/huginn/huginn/pull/1354) |
| Mar 18, 2016   | Introduce concept to handle files, introduces four new agents: [1301](https://github.com/huginn/huginn/pull/1301)<ul><li>`LocalFileAgent` (source/consumer), can watch for changes of a file/directory, when schedules just emits an event for every file. Writes received event data to a local file.</li><li>`S3Agent` (source/consumer), watches an S3 bucket for changes or emits the files on interval. Writes received event data to a S3 Bucket.</li><li>`ReadFileAgent` (birdge/consumer), takes the file pointer from one of the source agents, reads the file and emits to contents so that other agents that do not yet support the file pointers can work with the data.</li><li> `CsvAgent` (consumer),parses CSV data, it can consume a file pointer or with with data supplied via the event payload. Generates CSV from received events.</li></ul> |
| Mar 17, 2016   | Add admin user management interface to create, edit, deactivate and delete users. [1330](https://github.com/huginn/huginn/pull/1330) |
| Mar 16, 2016   | Ensure the `JavaScriptAgent` uses the configured timezone. [1356](https://github.com/huginn/huginn/pull/1356) |
| Mar 16, 2016   | Add `age` column with default sort to prioritize new Agents in the index view. [1348](https://github.com/huginn/huginn/pull/1348) |
| Mar 13, 2016   | Rescue and log email sending errors. [1335](https://github.com/huginn/huginn/pull/1335) |
| Mar 12, 2016   | Hide the Agent's memory in Agent show page per default. [1326](https://github.com/huginn/huginn/pull/1326) |
| Mar 12, 2016   | Fix TwitterStreamAgent database connection in use and restart issues. [6ee094af9](https://github.com/huginn/huginn/commit/6ee094af95747f65800c9e822e5566f1c5cf0bfe) |
| Mar 09, 2016   | Add support for ruby `2.3.0` by ensuring the tests pass. [7f50503da](https://github.com/huginn/huginn/commit/7f50503da952522ad71da5d91256c6714ddf5edd) |
| Mar 08, 2016   | Add `json` liquid filter to serialize data to a JSON string. [1329](https://github.com/huginn/huginn/pull/1329) |
| Mar 07, 2016   | Allow specifying the content-type of send E-Mails. [1325](https://github.com/huginn/huginn/pull/1325) |
| Mar 06, 2016   | Add BoxcarAgent for Boxcar.io. [1323](https://github.com/huginn/huginn/pull/1323) |
| Mar 02, 2016   | Update Rails to `4.2.5.2`. [cf9e9bd04](https://github.com/huginn/huginn/commit/cf9e9bd0454bfc0c12fbc229dc5e0c34535605e2) |
| Mar 02, 2016   | Allow TwitterUserAgent to follow the users own timeline. [1321](https://github.com/huginn/huginn/pull/1321) |
| Feb 26, 2016   | Added TwitterFavorites Agent for following the favorites of a Twitter user. Thanks @jngai and @bigretromike! |
| Feb 26, 2016   | Added HttpStatusAgent for pinging web servers and returning the resulting HTTP status code. Thanks @darrencauthon! |
| Feb 20, 2016   | A `from` option can now be specified on email agents. (If you're using Gmail, it may still show your normal address unless you add the new address as a valid sender on the account.) |
| Feb 20, 2016   | Added a recommended PORT to the .env.example file. |
| Feb 15, 2016   | Allow usage of spring in development by setting SPRING in .env. |
| Feb 14, 2016   | Bug fix: missing Credential no longer 500 errors during an import. |
| Feb 12, 2016   | Add `no_bulk_receive!` option to ensure Events are processed individually in certain Agents. |
| Feb 7, 2016    | Add `http_success_codes` option to the WebsiteAgent to treat more than just 200 as success codes. |
| Feb 7, 2016    | Add support for writing Capybara specs. |
| Feb 4, 2016    | Bug fix: Fix mysql connection check for multi-process docker image. |
| Feb 3, 2016    | The GoogleCalendarPublishAgent now accepts Liquid in the `calendar_id` option. |
| Feb 1, 2016    | Fix Guard and add rack-livereload for development. |
| Jan 30, 2016   | Add support to the ManualEventAgent for Liquid formatting and creating multiple Events. |
| Jan 28, 2016   | PushbulletAgent can push to all devices. |
| Jan 26, 2016   | Update Rails to 4.2.5.1 for security and unify configuration files. |
| Jan 24, 2016   | Docker upgrades and fixes. |
| Jan 22, 2016   | Upgrade devise to 3.5.4 to address CVE-2015-8314. |
| Jan 20, 2016   | Update nokogiri for CVE-2015-7499. |
| Jan 20, 2016   | Add DigestAgent which collects any Events sent to it and emits them as a single event. |
| Jan 16, 2016   | Update celluloid and delayed_job to avoid potential memory issues. |
| Jan 16, 2016   | PostAgent can emit Events with the resulting data from the server. |
| Jan 15, 2016   | Allow Liquid formatting of the `recipients` option of email Agents. |
| Jan 14, 2016   | Add new block tags `regex_replace`/`regex_replace_first` to Liquid. |
| Jan 14, 2016   | Events received by the WebsiteAgent do not need to contain a `url` value, switching to usage of `url_from_event` instead. |
| Jan 14, 2016   | Liquid block tag `regex_replace` and `regex_replace_first` added. |
| Jan 12, 2016   | WebhookAgent supports reCAPTCHA. |
| Jan 8, 2016    | Remove schema.rb from git. |
| Jan 3, 2016    | Add itunes namespace to DataOutputAgent. |
| Dec 26, 2015   | Allow multiple users to import the same Scenario. |
| Dec 26, 2015   | WebsiteAgent can accept a `data_from_event` Liquid template instead of a URL. |
| Dec 19, 2015   | Update nokogiri to 1.6.7.1 because of security CVEs. |
| Dec 10, 2015   | Bug fix: Do not try to load .env file on Heroku. |
| Dec 8, 2015    | Export Agents in GUID order in Scenarios. |
| Nov 25, 2015   | Update to newest uglifier and nokogiri gems due to security alerts. |
| Nov 14, 2015   | Bug fix: WebsiteAgent handles unicode URLs better. |
| Nov 12, 2015   | Bug fix: fix a memory leak caused by starting a new LongRunnable::Worker when the old one is still restarting. |
| Nov 11, 2015   | EventFormattinghAgent can be dry run. |
| Nov 8, 2015    | Added media namespace to DataOutputAgent output, supporting 'media:content' nodes. |
| Nov 5, 2015    | Bug fix: CommanderAgent can now be manually run correctly. |
| Nov 4, 2015    | DataOutputAgent can push to PubSubHubbub hubs with `push_hubs` option. |
| Oct 31, 2015   | DelayAgent `max_emitted_events` option added to limit the number of events which should be created. |
| Oct 30, 2015   | TumblrPublishAgent reblog `post_type` added. |
| Oct 28, 2015   | TumblrPublishAgent emits the created post. |
| Oct 27, 2015   | WebhookAgent can have a custom `response` message. |
| Oct 27, 2015   | `DIAGRAM_DEFAULT_LAYOUT` option added to select Graphviz layout. |
| Oct 27, 2015   | ShellCommandAgent has new `suppress_on_failure` and `suppress_on_empty_output` options. |
| Oct 24, 2015   | TwitterStream does not complain when not configured. |
| Oct 23, 2015   | Bug fix: RSSAgent now sorts correctly with `events_order`. |
| Oct 22, 2015   | Bug fix: BeeperAgent added to push messages to the Beeper mobile app. |
| Oct 20, 2015   | WebsiteAgent unwraps cdata sections in XML. |
| Oct 20, 2015   | `force_stop` command added to production.rake. |
| Oct 18, 2015   | Bug fix: CommanderAgent can now control any other Agent type. |
| Oct 17, 2015   | TwitterSearchAgent added for running period Twitter searches. |
| Oct 17, 2015   | GapDetectorAgent added to alert when no data has been seen in a certain period of time. |
| Oct 12, 2015   | Slack agent supports attachments. |
| Oct 9, 2015    | The TriggerAgent can be asked to match on fewer then all match groups. |
| Oct 4, 2015    | Add DelayAgent for buffering incoming Events |
| Oct 3, 2015    | Add SSL verification options to smtp.yml |
| Oct 3, 2015    | Better handling of 'Back' links in the UI. |
| Sep 22, 2015   | Comprehensive EvernoteAgent added |
| Sep 13, 2015   | JavaScriptAgent can access and set Credentials. |
| Sep 9, 2015    | Add AgentRunner and LongRunnable to support long running agents. |
| Sep 8, 2015    | Allow `url_from_event` in the WebsiteAgent to be an Array |
| Sep 7, 2015    | Enable `strict: false` in database.yml |
| Sep 2, 2015    | WebRequestConcern Agents automatically decode gzip/inflate encodings. |
| Sep 1, 2015    | WebhookAgent can configure allowed verbs (GET, POST, PUT, ...) for incoming requests. |
| Aug 21, 2015   | PostAgent supports "xml" as `content_type`. |
| Aug 3, 2015    | Dry Run allows user to input an event payload. |
| Aug 1, 2015    | Huginn now requires Ruby >=2.0 to run. |
| Jul 30, 2015   | RssAgent can configure the order of events created via `events_order`. |
| Jul 29, 2015   | WebsiteAgent can configure the order of events created via `events_order`. |
| Jul 29, 2015   | DataOutputAgent can configure the order of events in the output via `events_order`. |
| Jul 20, 2015   | Control Links (used by the SchedularAgent) are correctly exported in Scenarios. |
| Jul 20, 2015   | keep\_events\_for was moved from days to seconds; Scenarios have a schema verison. |
| Jul 8, 2015    | DataOutputAgent supports feed icon, and a new template variable `events`. |
| Jul 1, 2015    | DeDuplicationAgent properly handles destruction of memory. |
| Jun 26, 2015   | Add `max_events_per_run` to RssAgent. |
| Jun 19, 2015   | Add `url_from_event` to WebsiteAgent. |
| Jun 17, 2015   | RssAgent emits events for new feed items in chronological order. |
| Jun 17, 2015   | Liquid filter `unescape` added. |
| Jun 17, 2015   | Liquid filter `regex_replace` and `regex_replace_first` added, with escape sequence support. |
| Jun 15, 2015   | Liquid filter `uri_expand` added. |
| Jun 13, 2015   | Liquid templating engine is upgraded to version 3. |
| Jun 12, 2015   | RSSAgent can now accept an array of URLs. |
| Jun 8, 2015    | WebsiteAgent includes a `use_namespaces` option to enable XML namespaces. |
| May 27, 2015   | Validation warns user if they have not provided a `path` when using JSONPath in WebsiteAgent. |
| May 24, 2015   | Show Agents' name and user in the jobs panel. |
| May 19, 2015   | Add "Dry Run" to the action menu. |
| May 23, 2015   | JavaScriptAgent has dry run and inline syntax highlighting JavaScript and CoffeeScript. |
| May 11, 2015   | Make delayed\_job sleep\_delay and max\_run\_time .env configurable. |
| May 9, 2015    | Add 'unescapeHTML' functionality to the javascript agent. |
| May 3, 2015    | Use ActiveJobs interface.  |
| Apr 28, 2015   | Adds Wunderlist agent. |
| Apr 25, 2015   | Allow user to clear memory of an agent. |
| Apr 25, 2015   | Allow WebsiteAgent to unzip compressed JSON. |
| Apr 12, 2015   | Allow the webhook agent to loop over returned results if the payload\_path points to an array. |
| Mar 27, 2015   | Add wit.ai Agent. |
| Mar 24, 2015   | CloudFoundry integration. |
| Mar 20, 2015   | Upgrade to Rails 4.2. |
| Mar 17, 2015   | Add new "Dry Run" feature for some Agents. |
| Feb 26, 2015   | Update to PushBullet API version 2. |
| Feb 22, 2015   | Allow Agents to request immediate propagation of Events. |
| Feb 18, 2015   | Convert \n to actual line breaks after interpolating liquid and add `line_break_tag`. |
| Feb 6, 2015    | Allow UserLocationAgent to accept `min_distance` to require a certain distance traveled. |
| Feb 1, 2015    | Allow a `body` key to be provided to set email body in the EmailAgent. |
| Jan 21, 2015   | Allow custom icon for Slack webhooks. |
| Jan 20, 2015   | Add `max_accuracy` to UserLocationAgent. |
| Jan 19, 2015   | WebRequestConcern Agents can supply `disable_ssl_verification` to disable ssl verification. |
| Jan 13, 2015   | Docker image updated. |
| Jan 8, 2015    | Allow toggling of accuracy when displaying locations in the UserLocationAgent map. |
| Dec 26, 2014   | Do not try to monkey patch the mysql adapter on heroku |
| Dec 7, 2014    | Update Rails to 4.1.8 |
| Dec 3, 2014    | Access sites with invalid SSL |
| Nov 22, 2014   | Make the website agent support merge events |
| Nov 8, 2014    | Added DeDuplicationAgent |
| Nov 5, 2014    | Made latlng accessible to liquid |
| Nov 4, 2014    | Enable AgentLog to handle a message with invalid byte sequences; upgrade slack-notifier to 1.0.0; use webhook URLs instead of tokens. |
| Nov 2, 2014    | Fixes WorkerStatusController for postgresql; updated rails to 4.1.7; added a PDF info agent; commander agent can configure other Agents. |
| Nov 1, 2014    | Fixes postgres and DST related spec issues |
| Oct 27, 2014   | RSSAgent: Include `url` in addition to `urls` in each event. |
| Oct 23, 2014   | Assume an uploaded scenario file (JSON) is encoded in UTF-8 |
| Oct 20, 2014   | Made weather agent dependent on user location |
| Oct 16, 2014   | Make event-indicator a link to the events page, with new events highlighted |
| Oct 15, 2014   | Add dropbox agent to emit urls for the given paths |
| Oct 14, 2014   | Upgrade Devise to 3.4.0; mqttAgent: Ignore a retained message previously received |
| Oct 12, 2014   | Add a button to view full error logs; allow longer than 2000 characters |
| Oct 10, 2014   | Dropbox watch agent |
| Oct 9, 2014    | Make the scheduler frequency tunable via ENV; add CommanderAgent, which controls other agents on a schedule or incoming event; disable the CSRF warning in WebRequestsController. |
| Oct 5, 2014    | OpenShift deployment |
| Oct 1, 2014    | Migrate to Rspec3 |
| Sep 29, 2014   | Refactor OmniAuth integration |
| Sep 25, 2014   | TumblrPublishAgent |
| Sep 24, 2014   | Refactor OmniAuth configuration and fix it with 37Signals; introduce FontAwesome; enable download of user credentials; improve docs for ForecastIO in WeatherAgent. |
| Sep 22, 2014   | Improvements to bin/setup_heroku |
| Sep 21, 2014   | Reduce gems to save RAM |
| Sep 17, 2014   | Give user an option to drop pending events when enabling an agent. |
| Sep 16, 2014   | Improvements to UserLocationAgent |
| Sep 14, 2014   | Allow some agents to be configured via HTML forms rather then JSON. |
| Sep 13, 2014   | Calculate IDs in RssAgent if none are available. |
| Sep 12, 2014   | Make tables sortable by most columns. |
| Sep 8, 2014    | SchedulerAgent added, allowing granular control of Agent schedules.  Agents can now control other Agents via `ControlLinks`. <br>Liquid filter `to_uri` added. |
| Sep 7, 2014    | Optional delayed\_job\_web replaced by a custom UI for managing failed and queued jobs. |
| Sep 6, 2014    | Agent's `last_event_at` is now updated only on Event creation, not on updates. |
| Sep 4, 2014    | Spring, an application preloader intergated with Rails 4.1, has been added. |
| Sep 3, 2014    | Liquid interpolation in the WebsiteAgent now has a `_response_` variable available. |
| Aug 31, 2014   | Fix a bug where AgentLogs errored after a referenced Event was deleted. <br> HumanTaskAgent can emit separate events for each answer. |
| Aug 30, 2014   | Set charset/collation properly for each text column if using MySQL. <br> One-click "Deploy to Heroku" button added in README. |
| Aug 28, 2014   | Liquid filter `to_xpath` added, which quotes a string for use in XPath expression. |
| Aug 26, 2014   | Transition to new Services model for managing external authorization with omniauth. |
| Aug 21, 2014   | WebsiteAgent has a new `text` parser type. <br> Scenario tags have a customizable foreground and background color. <br> HTML is sanitized and supported in emails. |
| Aug 20, 2014   | Support for markdown in Scenario descriptions added. |
| Aug 17, 2014   | TwitterStream no longer tries to run disabled Agents.  Sleep and thread bugs fixed in the EM code. |
| Aug 13, 2014   | `created_at` added as an available Liquid variable. <br> Enable Graphviz on Heroku. |
| Aug 12, 2014   | Add an environment variable (`DEFAULT_HTTP_USER_AGENT`) to set a global default User-Agent value. <br> Hover menu to the "Agents" nav link added. |
| Aug 9, 2014    | ChangeDetectorAgent added. |
| Aug 8, 2014    | Make PostAgent use WebRequestConcern, adding options for Basic Auth and User-Agent. |
| Aug 5, 2014    | Use 'net-ftp-list' gem to parse ftp directory listing. |
| Aug 1, 2014    | Adding a badge to each Agent node in a diagram. |
| Jul 31, 2014   | Allow HipchatAgent to use a shared Credential. |
| Jul 29, 2014   | The upstream Agent is now available in the EventFormattingAgent in Liquid via the `agent` key. <br> The WebsiteAgent is now much more powerful, supporting full XPath evaluations in extractions. |
| Jul 26, 2014   | Easy Heroku deployment added and document in the wiki! |
| Jul 25, 2014   | Simple RSSAgent added for parsing RSS feeds (the WebsiteAgent has always been able to do this, but this new Agent is simpler). <br> Nicer Agent diagrams. |
| Jul 20, 2014   | Email Agents can send to more than one recipient using the new `recipients` array. |
| Jun 29, 2014   | PostAgent can send more HTTP verbs, use both json and html form encoding, and merge event payloads. |
| Jun 18, 2014   | Scenarios added, allowing Agents to be grouped, imported, and exported. <br> `interpolated_options` added so that most Agent options can contain Liquid markup. |
| Jun 12, 2014   | XML namespaces are ignored by the WebsiteAgent when evaluating XPath. |
| Jun 9, 2014    | User edit form split and cleaned up. |
| Jun 8, 2014    | Upgraded to Rails 4.1.1. |
| Jun 5, 2014    | MQTTAgent added. |
| Jun 1, 2014    | SlackAgent added. <br> Liquid tag for accessing Credentials added. <br> Requests to /worker\_status  no longer spam the log. <br> GoogleCalendarAgent added. |
| May 19, 2014   | ImapFolderAgent added. |
| May 11, 2014   | Combine some of the Foreman processes into threads for lower memory usage. |
| May 6, 2014    | Agents can be disabled or enabled. |
| May 5, 2014    | JiraAgent added. |
| May 3, 2014    | If you're using Capistrano, `cap sync:db:down` now works correctly to pull your production DB to your local environment. |
| May 1, 2014    | Upgrade to Bootstrap 3.1.1 |
| Apr 20, 2014   | Tons of new additions! FtpsiteAgent; WebsiteAgent has xpath, multiple URL, and encoding support; regexp extractions in EventFormattingAgent; PostAgent takes default params and headers, and can make GET requests; local Graphviz support; ShellCommandAgent; BasecampAgent; HipchatAgent; and lots of bug fixes! |
| Apr 10, 2014   | WebHooksController has been renamed to WebRequestsController and all HTTP verbs are now accepted and passed through to Agents' #receive\_web\_request method. The new DataOutputAgent returns JSON or RSS feeds of incoming Events via external web request.  [Documentation is on the wiki.](https://github.com/huginn/huginn/wiki/Creating-a-new-agent#receiving-web-requests). |
| Jan 2, 2014    | Agents now have an optional keep\_events\_for option that is propagated to created events' expires\_at field, and they update their events' expires\_at fields on change. |
| Jan 1, 2014    | Remove symbolization of memory, options, and payloads; convert memory, options, and payloads to JSON from YAML.  Migration will perform conversion and adjust tables to be UTF-8.  Recommend making a DB backup before migrating. |
| Nov 6, 2013    | PeakDetectorAgent now uses `window_duration_in_days` and `min_peak_spacing_in_days`.  Additionally, peaks trigger when the time series rises over the standard deviation multiple, not after it starts to fall. |
| Jun 29, 2013   | Removed rails\_admin because it was causing deployment issues. Better to have people install their favorite admin tool if they want one. |
| Jun, 2013      | A number of new agents have been contributed, including interfaces to Weibo, Twitter, and Twilio, as well as Agents for translation, sentiment analysis, and for posting and receiving webhooks. |
| Mar 24, 2013   | Refactored loading of Agents for `check` and `receive` to use ids instead of full objects.  This should fix the too-large delayed\_job issues.  Added `system_timer` and `fastercsv` to the Gemfile for the Ruby 1.8 platform. |
| Mar 18, 2013   | Added Wiki page about the [Agent API](https://github.com/huginn/huginn/wiki/Creating-a-new-agent). |
| Mar 17, 2013   | Switched to JSONPath for defining paths through JSON structures.  The WebsiteAgent can now scrape and parse JSON. |
