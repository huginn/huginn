# Changes

| DateOfChange   | Changes                                                                                                      |
|----------------|--------------------------------------------------------------------------------------------------------------|
| Apr 04, 2020   | Upgrade ubuntu versions of docker images to 18.04. [2603](https://github.com/huginn/huginn/pull/2603) **If you are using the `huginn/huginn` image with a internal MySQL database, back up your database volume before updating**  |
| Mar 31, 2020   | Add FUNDING.yml [2728](https://github.com/huginn/huginn/pull/2728) |
| Mar 30, 2020   | Improve formatting of OpenShift documentation [2724](https://github.com/huginn/huginn/pull/2724) |
| Mar 30, 2020   | Fix deployment via OpenShift [2726](https://github.com/huginn/huginn/pull/2726) |
| Mar 29, 2020   | Fix UserLocationAgent never displayed the course of the user [2709](https://github.com/huginn/huginn/pull/2709) |
| Mar 29, 2020   | Allow email agent to dry run [2706](https://github.com/huginn/huginn/pull/2706) |
| Feb 29, 2020   | Allow slack agent to dry run [2694](https://github.com/huginn/huginn/pull/2694) |
| Feb 29, 2020   | Upgrade rake and nokogiri to fix CVEs [2698](https://github.com/huginn/huginn/pull/2698) |
| Feb 16, 2020   | Simplify the download of the latest version of jq [2683](https://github.com/huginn/huginn/pull/2683) |
| Feb 11, 2020   | Make sure to download the latest release of jq from GitHub [2681](https://github.com/huginn/huginn/pull/2681) |
| Feb 06, 2020   | Install the latest jq for JqAgent [2675](https://github.com/huginn/huginn/pull/2675) |
| Jan 11, 2020   | Drop support for Ruby 2.3 which reached EOL |
| Jan 11, 2020   | Add Jq Agent [2665](https://github.com/huginn/huginn/pull/2665) |
| Jan 10, 2020   | Update README.md about dockers images, adds details about seeding [2669](https://github.com/huginn/huginn/pull/2669) |
| Jan 09, 2020   | Upgrade mini-racer to 0.2.9 and libv8 to 7.3.492.27.1 [2664](https://github.com/huginn/huginn/pull/2664) |
| Jan 07, 2020   | Allow Agents injected as GEMs to define a UI [2659](https://github.com/huginn/huginn/pull/2659) |
| Dec 19, 2019   | Upgrade rack to 2.0.8 to fix CVE [2651](https://github.com/huginn/huginn/pull/2651) |
| Dec 19, 2019   | Fix TravisCI build [2650](https://github.com/huginn/huginn/pull/2650) |
| Dec 18, 2019   | Fix link to andrewcurioso/huginn [2647](https://github.com/huginn/huginn/pull/2647) |
| Dec 14, 2019   | Sql installation info [2646](https://github.com/huginn/huginn/pull/2646) |
| Dec 14, 2019   | FIX broken link to docker container [2645](https://github.com/huginn/huginn/pull/2645) |
| Dec 13, 2019   | fix: password prompt at sql secure step [2643](https://github.com/huginn/huginn/pull/2643) |
| Dec 08, 2019   | Allow dry-run of PushoverAgent [2640](https://github.com/huginn/huginn/pull/2640) |
| Dec 03, 2019   | Prevent `GoogleCalendar.open` from raising exception in ensure block [2634](https://github.com/huginn/huginn/pull/2634) |
| Dec 03, 2019   | Upgrade rubies to the latest minor releases [2630](https://github.com/huginn/huginn/pull/2630) |
| Nov 27, 2019   | Upgrade Feedjira to 3.1.0 that improves RssAgent [2629](https://github.com/huginn/huginn/pull/2629) |
| Nov 16, 2019   | email is the plural of email [2623](https://github.com/huginn/huginn/pull/2623) |
| Nov 10, 2019   | Upgrade loofah and nokogiri [2621](https://github.com/huginn/huginn/pull/2621) |
| Oct 06, 2019   | Escape MySQL database name during migration [2608](https://github.com/huginn/huginn/pull/2608) |
| Oct 03, 2019   | Upgrade typhoeus to fix obscure error SSL validation error [2602](https://github.com/huginn/huginn/pull/2602) |
| Sep 14, 2019   | Do not sanitize `@body` in a text part in EmailAgent [2595](https://github.com/huginn/huginn/pull/2595) |
| Aug 25, 2019   | Make JavaScript Agent optional [2590](https://github.com/huginn/huginn/pull/2590) |
| Aug 17, 2019   | Remove support for the Weather Underground API [2396](https://github.com/huginn/huginn/pull/2396) |
| Aug 17, 2019   | Add ability to reemit all of an Agent's events from the UI [2573](https://github.com/huginn/huginn/pull/2573) |
| Aug 17, 2019   | Improve Utils.normalize_uri() [2585](https://github.com/huginn/huginn/pull/2585) |
| Aug 12, 2019   | Upgrade `nokogiri` to 1.10.4 for CVE-2019-5477 [2582](https://github.com/huginn/huginn/pull/2582) |
| Aug 01, 2019   | Add `group_by` liquid filter [2572](https://github.com/huginn/huginn/pull/2572) |
| Jul 29, 2019   | Upgrade `mini_magic`, fix focus rspec filter limiting test suit on CI [2568](https://github.com/huginn/huginn/pull/2568) |
| Jul 28, 2019   | Fix description of `EmailDigestAgent` [2567](https://github.com/huginn/huginn/pull/2567) |
| Jul 27, 2019   | Increase `TelegramAgent` Caption Length [2560](https://github.com/huginn/huginn/pull/2560) |
| Jun 30, 2019   | Install Node 10 instead of Node 0.12 in the install guide [2551](https://github.com/huginn/huginn/pull/2551) |
| Jun 10, 2019   | Improve Docker README.md [2546](https://github.com/huginn/huginn/pull/2546) |
| May 19, 2019   | Update `liquid` to the latest version 4.0.3 [2536](https://github.com/huginn/huginn/pull/2536) |
| May 07, 2019   | Add `drop_pending_events` option to `AgentControllerConcern` [2532](https://github.com/huginn/huginn/pull/2532) |
| Apr 30, 2019   | Update `nokogiri` for CVEs [2531](https://github.com/huginn/huginn/pull/2531) |
| Apr 28, 2019   | Set `inbound_event` when creating `AgentLog` entries [2530](https://github.com/huginn/huginn/pull/2530) |
| Apr 18, 2019   | Replace rubyracer with mini_racer, dropped support for Debian 7 aka Wheezy [1961](https://github.com/huginn/huginn/pull/1961) |
| Apr 16, 2019   | Force SNI support in Net modules for IMAP/POP3/SMTP [2523](https://github.com/huginn/huginn/pull/2523) |
| Apr 15, 2019   | Upgrade `devise` to fix CVE [2525](https://github.com/huginn/huginn/pull/2525) |
| Apr 14, 2019   | Set Heroku stack to `heroku-18` in app.json [2524](https://github.com/huginn/huginn/pull/2524) |
| Mar 29, 2019   | Add digest filters to our Liquid engine [2516](https://github.com/huginn/huginn/pull/2516) |
| Mar 29, 2019   | Add Liquid based rule support to `TriggerAgent` [2514](https://github.com/huginn/huginn/pull/2514) |
| Mar 29, 2019   | Add a `delete` option to `ImapFolderAgent` [2515](https://github.com/huginn/huginn/pull/2515) |
| Mar 17, 2019   | Update `rails` for CVEs [2508](https://github.com/huginn/huginn/pull/2508) |
| Mar 02, 2019   | Revert "Update DataOutputAgent accept header for browser compatibilit… [2499](https://github.com/huginn/huginn/pull/2499) |
| Feb 14, 2019   | Improve description of `TriggerAgent` [2489](https://github.com/huginn/huginn/pull/2489) |
| Jan 29, 2019   | Add `event_headers` support to `ImapFolderAgent` [2476](https://github.com/huginn/huginn/pull/2476) |
| Jan 26, 2019   | Make the `mail` gem use real-world encoders for some Japanese charsets [2477](https://github.com/huginn/huginn/pull/2477) |
| Jan 25, 2019   | Update `jsonpath` gem [2474](https://github.com/huginn/huginn/pull/2474) |
| Jan 25, 2019   | Ddd jpg as renderType to phantomjscloud setting [2470](https://github.com/huginn/huginn/pull/2470) |
| Jan 09, 2019   | Update manual installation instructions [2461](https://github.com/huginn/huginn/pull/2461) |
| Jan 08, 2019   | Improve #2434 (Add HTTP Headers to Webhook Agent) [2454](https://github.com/huginn/huginn/pull/2454) |
| Jan 08, 2019   | Fix for Bundler 2 [2455](https://github.com/huginn/huginn/pull/2455) |
| Jan 07, 2019   | Winter cleaning [2452](https://github.com/huginn/huginn/pull/2452) |
| Jan 07, 2019   | Persist override of HUGINN_PORT [2448](https://github.com/huginn/huginn/pull/2448) |
| Dec 15, 2018   | Bump `capistrano` to latest version to avoid OpenSSL error [2437](https://github.com/huginn/huginn/pull/2437) |
| Dec 02, 2018   | Update `rails` to 5.2.1.1 for CVE-2018-16476 [2428](https://github.com/huginn/huginn/pull/2428) |
| Nov 22, 2018   | Bump `rack and` `nokogiri` [2425](https://github.com/huginn/huginn/pull/2425) |
| Nov 21, 2018   | Improve usability of `DelayAgent` [2422](https://github.com/huginn/huginn/pull/2422) |
| Nov 15, 2018   | Bug fix: restrict IFS to only the read builtin [2413](https://github.com/huginn/huginn/pull/2413) |
| Nov 14, 2018   | Added better validations for the `WatherAgent`. [2414](https://github.com/huginn/huginn/pull/2414) |
| Nov 03, 2018   | Updated link to Kitematic [2406](https://github.com/huginn/huginn/pull/2406) |
| Oct 29, 2018   | Move method `is_positive_integer?` to "agent.rb" [2402](https://github.com/huginn/huginn/pull/2402) |
| Oct 12, 2018   | Do not seed databnase when a user exists [2386](https://github.com/huginn/huginn/pull/2386) |
| Oct 12, 2018   | Fix name of Twitter event field in `TwitterUserAgent` [2388](https://github.com/huginn/huginn/pull/2388) |
| Oct 03, 2018   | Delete stale delayed_job pid file when starting docker containers [2385](https://github.com/huginn/huginn/pull/2385) |
| Oct 03, 2018   | Update `jsonpath` to 0.9.4 [2383](https://github.com/huginn/huginn/pull/2383) |
| Oct 03, 2018   | Added support for MySQL 8 and MariaDB 10.3. Dropped support for MySQL < 5.5 and PostgreSQL < 9.2 [2384](https://github.com/huginn/huginn/pull/2384) |
| Aug 30, 2018   | Support merge mode in `JsonParseAgent`  [2353](https://github.com/huginn/huginn/pull/2353) |
| Aug 27, 2018   | Docker: extract heredocs from multi-process init and update docker-compose files [2298](https://github.com/huginn/huginn/pull/2298) |
| Aug 18, 2018   | Remove `GoogleFlightsAgent` [2351](https://github.com/huginn/huginn/pull/2351) |
| Aug 07, 2018   | Fix IMAP encoding issues [2346](https://github.com/huginn/huginn/pull/2346) |
| Aug 07, 2018   | Upgrade rubies to their latest patch release [2267](https://github.com/huginn/huginn/pull/2267) |
| Aug 07, 2018   | Fix "already retweeted" error detection [2174](https://github.com/huginn/huginn/pull/2174) |
| Aug 07, 2018   | Update twitter-stream and its dependency, eventmachine [2345](https://github.com/huginn/huginn/pull/2345) |
| Aug 01, 2018   | Respect WEB_CONCURRENCY env in unicorn.rb.example [2342](https://github.com/huginn/huginn/pull/2342) |
| Jul 31, 2018   | Update DataOutputAgent accept header for browser compatibility [2338](https://github.com/huginn/huginn/pull/2338) |
| Jul 16, 2018   | Make 'expected_receive_period_in_days' optional [2333](https://github.com/huginn/huginn/pull/2333) |
| Jul 14, 2018   | Fix "working?" of PostAgent [2329](https://github.com/huginn/huginn/pull/2329) |
| Jun 22, 2018   | Bump sprockets version [2321](https://github.com/huginn/huginn/pull/2321) |
| Jun 17, 2018   | Upgrade to Rails 5.2 [2266](https://github.com/huginn/huginn/pull/2266) |
| Jun 17, 2018   | Add link for darksky api key since wunderground no longer free [2313](https://github.com/huginn/huginn/pull/2313) |
| Jun 08, 2018   | Update google_translation_agent.rb [2309](https://github.com/huginn/huginn/pull/2309) |
| Jun 04, 2018   | Improve logic of "working?" in MqttAgent [2307](https://github.com/huginn/huginn/pull/2307) |
| May 18, 2018   | Pass URLs to Telegram API directly [2285](https://github.com/huginn/huginn/pull/2285) |
| May 02, 2018   | Bump binding of caller to fix incompatibility with ruby 2.5 [2276](https://github.com/huginn/huginn/pull/2276) |
| Apr 30, 2018   | Bump rails-html-sanitizer to 1.0.4 to address CVE [2274](https://github.com/huginn/huginn/pull/2274) |
| Apr 28, 2018   | Add ssl support for mail config [2270](https://github.com/huginn/huginn/pull/2270) |
| Apr 21, 2018   | PushoverAgent: HTML message support [2264](https://github.com/huginn/huginn/pull/2264) |
| Apr 04, 2018   | Allow to run on ruby 2.5 and fix warnings [2216](https://github.com/huginn/huginn/pull/2216) |
| Apr 04, 2018   | [#2248] Allow the `PostAgent` to consume arrays [2249](https://github.com/huginn/huginn/pull/2249) |
| Mar 21, 2018   | Update loofah due to CVE-2018-8048 [2243](https://github.com/huginn/huginn/pull/2243) |
| Feb 13, 2018   | Clarify xpath usage with example [2217](https://github.com/huginn/huginn/pull/2217) |
| Feb 03, 2018   | Fix syntax error in Website Agent description [2207](https://github.com/huginn/huginn/pull/2207) |
| Jan 31, 2018   | Upgrade nokogiri to 1.8.2 to address vulnerabilities found in libxml2 [2205](https://github.com/huginn/huginn/pull/2205) |
| Jan 29, 2018   | Split long Telegram messages [2171](https://github.com/huginn/huginn/pull/2171) |
| Jan 08, 2018   | Rescue ZeroDivisionError on validation [2189](https://github.com/huginn/huginn/pull/2189) |
| Jan 05, 2018   | Fix Liquid interpolation in TwilioAgent helper methods [2187](https://github.com/huginn/huginn/pull/2187) |
| Jan 02, 2018   | Fix Docker testing README for better GitHub readability [2183](https://github.com/huginn/huginn/pull/2183) |
| Dec 01, 2017   | Add `array` extraction option to WebsiteAgent in HTML/XML mode [2170](https://github.com/huginn/huginn/pull/2170) |
| Nov 30, 2017   | Add options to Telegram Agent [2168](https://github.com/huginn/huginn/pull/2168) |
| Nov 11, 2017   | Upgrade Dropbox Agents to new v2 API [2146](https://github.com/huginn/huginn/pull/2146) |
| Nov 11, 2017   | Add proxy support for WebRequestConcern [2157](https://github.com/huginn/huginn/pull/2157) |
| Nov 11, 2017   | Allow usage of custom Liquid tags in LiquidOutputAgent [2160](https://github.com/huginn/huginn/pull/2160) |
| Oct 30, 2017   | Add a workaround for broken AlreadyRetweeted error detection [2155](https://github.com/huginn/huginn/pull/2155) |
| Oct 27, 2017   | Clarifying no authentication scenario [2153](https://github.com/huginn/huginn/pull/2153) |
| Oct 22, 2017   | Make Docker image runnable as non-root user [2112](https://github.com/huginn/huginn/pull/2112) |
| Oct 16, 2017   | Fix running specs with guard and spring [2145](https://github.com/huginn/huginn/pull/2145) |
| Oct 11, 2017   | Do not treat already retweeted/favorited error as failure [2140](https://github.com/huginn/huginn/pull/2140) |
| Oct 03, 2017   | Make TelegramAgent FormConfigurable, DryRunable and add logging [2138](https://github.com/huginn/huginn/pull/2138) |
| Sep 21, 2017   | Fix Run Event Propagation search action [2124](https://github.com/huginn/huginn/pull/2124) |
| Sep 21, 2017   | Update to nokogiri 1.8.1 [2132](https://github.com/huginn/huginn/pull/2132) |
| Sep 20, 2017   | Update rubies: 2017-09 [2129](https://github.com/huginn/huginn/pull/2129) |
| Sep 19, 2017   | Fix default scenario links [2123](https://github.com/huginn/huginn/pull/2123) |
| Sep 19, 2017   | Upgrade jquery.jsoneditor to handle null values [2127](https://github.com/huginn/huginn/pull/2127) |
| Sep 16, 2017   | Update Ruby version in instructions [2015](https://github.com/huginn/huginn/pull/2015) |
| Sep 16, 2017   | Handle lazy loading of Agents in gems during Agent.receive! [2125](https://github.com/huginn/huginn/pull/2125) |
| Sep 16, 2017   | Fix dry-run modal when clicking on icon in 'Dry Run' button [2126](https://github.com/huginn/huginn/pull/2126) |
| Sep 16, 2017   | OpenShift v3 quickstart [2108](https://github.com/huginn/huginn/pull/2108) |
| Sep 15, 2017   | Tweets view of `TwitterStreamAgent` has been enhanced. [2122](https://github.com/huginn/huginn/pull/2122) |
| Sep 11, 2017   | Do not instantiate all records when liquidizing a record collection [2119](https://github.com/huginn/huginn/pull/2119) |
| Sep 09, 2017   | Agent objects in Liquid templating now have new properties `working` and `url`. [2118](https://github.com/huginn/huginn/pull/2118) |
| Sep 06, 2017   | `DataOutputAgent` includes an icon in a podcast feed. [2114](https://github.com/huginn/huginn/pull/2114) |
| Sep 06, 2017   | Add documentation for `force_stop` rake task [2115](https://github.com/huginn/huginn/pull/2115) |
| Sep 05, 2017   | Fix flaky spec [2113](https://github.com/huginn/huginn/pull/2113) |
| Sep 05, 2017   | `DataOutputAgent` can properly output an RSS feed with items containing  multiple categories, enclosures, etc. [2110](https://github.com/huginn/huginn/pull/2110) |
| Sep 04, 2017   | Replace references to https://github.com/cantino/huginn with huginn/huginn [2106](https://github.com/huginn/huginn/pull/2106) |
| Sep 01, 2017   | Switch back to the upstream heroku-buildpack-graphviz [2105](https://github.com/huginn/huginn/pull/2105) |
| Aug 31, 2017   | Prevent PeakDetectorAgent from storing invalid data in it's memory [2103](https://github.com/huginn/huginn/pull/2103) |
| Aug 10, 2017   | Upgrade omniauth to prevent Hashie warning [2084](https://github.com/huginn/huginn/pull/2084) |
| Aug 10, 2017   | Load .env.test instead of .env.development when running rspec [2083](https://github.com/huginn/huginn/pull/2083) |
| Aug 08, 2017   | Add logging output for pushover agent [2081](https://github.com/huginn/huginn/pull/2081) |
| Aug 07, 2017   | `ImapFolderAgent` can now include a `Message-ID` and optionally a raw mail blob in each created event. [2076](https://github.com/huginn/huginn/pull/2076) |
| Aug 06, 2017   | Increase upper user name limit to 190 [2078](https://github.com/huginn/huginn/pull/2078) |
| Aug 01, 2017   | `GrowlAgent` supports new API parameters `sticky`, `priority` and `callback_url`. [2074](https://github.com/huginn/huginn/pull/2074) |
| Jul 31, 2017   | `PostAgent` now has a `merge` mode that can be enabled via the `output_mode` new option. [2069](https://github.com/huginn/huginn/pull/2069) |
| Jul 27, 2017   | Add validations for `mode` values in EventFormattingAgent [2070](https://github.com/huginn/huginn/pull/2070) |
| Jul 25, 2017   | Improve documentation of Website Agent [2066](https://github.com/huginn/huginn/pull/2066) |
| Jul 21, 2017   | Upgrade mysql2 gem to 0.4.8 [2065](https://github.com/huginn/huginn/pull/2065) |
| Jul 20, 2017   | Agent editor has a selectable `contollers` field. [2063](https://github.com/huginn/huginn/pull/2063) |
| Jul 20, 2017   | Receivers are now inherited when cloning an agent. [2063](https://github.com/huginn/huginn/pull/2063)|
| Jul 19, 2017   | Replace references of `cantino/huginn` with `huginn/huginn` [2062](https://github.com/huginn/huginn/pull/2062) |
| Jul 18, 2017   | `DigestAgent` gets a new option `retained_events`. [2041](https://github.com/huginn/huginn/pull/2041) |
| Jul 10, 2017   | `CommanderAgent` can now refer to `target` to determine what to do for each target agent. [2053](https://github.com/huginn/huginn/pull/2053)   |
| Jul 10, 2017   | Update Google API Client. May break backwards compatibility for GoogleCalendarPublishAgent. [2047](https://github.com/huginn/huginn/pull/2047)   |
| Jul 09, 2017   | Add runit-information for Debian Stretch [2048](https://github.com/huginn/huginn/pull/2048) |
| Jul 01, 2017   | Improve Capistrano configuration [2045](https://github.com/huginn/huginn/pull/2045) |
| Jun 06, 2017   | Addressed the problem with MySQL resetting auto_increment after events get emptied and the server reboots. [1974](https://github.com/huginn/huginn/pull/1974), [2014](https://github.com/huginn/huginn/pull/2014) |
| Jun 01, 2017   | Upgrade letter_opener_web version to 1.3.1 to support Rails 5. [2026](https://github.com/huginn/huginn/pull/2026) |
| May 31, 2017   | Downgrade ruby in Gemfile.lock to Heroku supported version [2024](https://github.com/huginn/huginn/pull/2024) |
| May 31, 2017   | Build and publish huginn/huginn-test [2016](https://github.com/huginn/huginn/pull/2016) |
| May 30, 2017   | Support Ruby 2.4. [1876](https://github.com/huginn/huginn/pull/1876) |
| May 25, 2017   | PeakDetectorAgent now has a configurable `search_url`. [2013](https://github.com/huginn/huginn/pull/2013) |
| May 24, 2017   | Add test docker image [2002](https://github.com/huginn/huginn/pull/2002) |
| May 19, 2017   | Improve docker environment variable documentation [2007](https://github.com/huginn/huginn/pull/2007) |
| May 19, 2017   | Upgrade Rails to 5.1. [1912](https://github.com/huginn/huginn/pull/1912) |
| May 18, 2017   | `ShellCommandAgent` gets a new option `unbundle`. [1990](https://github.com/huginn/huginn/pull/1990) |
| May 17, 2017   | Change docker image namespace [2004](https://github.com/huginn/huginn/pull/2004) |
| May 11, 2017   | Switch graphviz heroku buildpack to a fork to support new heroku stack [1998](https://github.com/huginn/huginn/pull/1998) |
| May 11, 2017   | Update Nokogiri to 1.7.2 [2000](https://github.com/huginn/huginn/pull/2000) |
| May 11, 2017   | `PeakDetectorAgent` gets a new option `min_events`. [1924](https://github.com/huginn/huginn/pull/1924) |
| May 11, 2017   | Switch back to the much improved `jsonpath` gem after `jsonpathv2` gets merged to mainline. [1996](https://github.com/huginn/huginn/pull/1996), [1997](https://github.com/huginn/huginn/pull/1997), [2017](https://github.com/huginn/huginn/pull/2017) |
| May 01, 2017   | Revert "Protect the latest event from automatic deletion when using MySQL" [1993](https://github.com/huginn/huginn/pull/1993) |
| Apr 27, 2017   | Add custom response header support to DataOutputAgent, WebhookAgent and LiquidOutputAgent. [1977](https://github.com/huginn/huginn/pull/1977) |
| Apr 27, 2017   | Upgrade Liquid to 4.0. [1982](https://github.com/huginn/huginn/pull/1982) |
| Apr 26, 2017   | Add `GoogleTranslationAgent`. [1978](https://github.com/huginn/huginn/pull/1978) |
| Apr 23, 2017   | Rss agent dynamic cleanup [1733](https://github.com/huginn/huginn/pull/1733) |
| Apr 21, 2017   | Twilio receiver fix [1980](https://github.com/huginn/huginn/pull/1980) |
| Apr 19, 2017   | Add another method to ping yourself from huginn [1970](https://github.com/huginn/huginn/pull/1970) |
| Apr 19, 2017   | `DataOutputAgent` now serves RSS output as `application/rss+xml` by default. (existing agents are automatically configured to use `text/xml`) [1973](https://github.com/huginn/huginn/pull/1973) |
| Apr 12, 2017   | Set created_at of dry-runned event to the current time [1965](https://github.com/huginn/huginn/pull/1965) |
| Apr 10, 2017   | Cleanup openshift configuration since it is not supported [1954](https://github.com/huginn/huginn/pull/1954) |
| Apr 08, 2017   | Add `TumblrLikesAgent`. [1923](https://github.com/huginn/huginn/pull/1923) |
| Apr 05, 2017   | Fix #1799 by linking to Liquid docs [1953](https://github.com/huginn/huginn/pull/1953) |
| Mar 31, 2017   | `ChangeDetectorAgent` can now refer to `last_property`. [1950](https://github.com/huginn/huginn/pull/1950) |
| Mar 26, 2017   | Update Nokogiri to 1.7.1 [1947](https://github.com/huginn/huginn/pull/1947) |
| Mar 21, 2017   | action_mailer initializer usability fixes [1942](https://github.com/huginn/huginn/pull/1942) |
| Mar 18, 2017   | Do not allow to "become" a deactivated user [1938](https://github.com/huginn/huginn/pull/1938) |
| Mar 17, 2017   | docker: generate Rails secret at first run if not configured [1931](https://github.com/huginn/huginn/pull/1931) |
| Mar 17, 2017   | Fix multi-process image when not specifying  POSTGRES_PORT_5432_TCP_ADDR [1922](https://github.com/huginn/huginn/pull/1922) |
| Mar 16, 2017   | Fix View diagram : Too many agent to display (#1664) [1935](https://github.com/huginn/huginn/pull/1935) |
| Mar 12, 2017   | docker: DEBIAN_FRONTEND was missing "export" [1932](https://github.com/huginn/huginn/pull/1932) |
| Mar 12, 2017   | Update README.md with info on huginn_agent gem [1929](https://github.com/huginn/huginn/pull/1929) |
| Mar 07, 2017   | Remove some empty documentation files [1926](https://github.com/huginn/huginn/pull/1926) |
| Mar 07, 2017   | Enable include_sort_info in RssAgent [1925](https://github.com/huginn/huginn/pull/1925) |
| Feb 27, 2017   | Make feature specs more robust [1917](https://github.com/huginn/huginn/pull/1917) |
| Feb 27, 2017   | Allow path to accept stored credentials in shell_command_agent.rb [1911](https://github.com/huginn/huginn/pull/1911) |
| Feb 12, 2017   | Check for agent class file to determine if it's valid [1907](https://github.com/huginn/huginn/pull/1907) |
| Feb 05, 2017   | Explain time zone labels [1902](https://github.com/huginn/huginn/pull/1902) |
| Feb 03, 2017   | Fix devise confirmation form, unify unlock form [1897](https://github.com/huginn/huginn/pull/1897) |
| Feb 01, 2017   | Order TwitterStreamAgents in setup_workers [1890](https://github.com/huginn/huginn/pull/1890) |
| Feb 01, 2017   | `GoogleFlightsAgent` supports choice of carrier and alliance. [1878](https://github.com/huginn/huginn/pull/1878) |
| Jan 31, 2017   | Rename Delayed::Job failed scope to prevent warning [1889](https://github.com/huginn/huginn/pull/1889) |
| Jan 31, 2017   | Add titles to all pages [1884](https://github.com/huginn/huginn/pull/1884) |
| Jan 30, 2017   | Change "Abort" button to say "Cancel" [1885](https://github.com/huginn/huginn/pull/1885) |
| Jan 29, 2017   | `WebhookAgent` can redirect to any URL after successful submission. [1923](https://github.com/huginn/huginn/pull/1923) |
| Jan 28, 2017   | Let default table inherit the boostrap #table css style [1883](https://github.com/huginn/huginn/pull/1883) |
| Jan 28, 2017   | Allow Redirect Requests [1881](https://github.com/huginn/huginn/pull/1881) |
| Jan 20, 2017   | Fix scenario import when merges are required [1877](https://github.com/huginn/huginn/pull/1877) |
| Jan 08, 2017   | Fix #1863 validation issue with schedule names [1864](https://github.com/huginn/huginn/pull/1864) |
| Jan 08, 2017   | Fix #1853 by hardcoding protocol on image. [1854](https://github.com/huginn/huginn/pull/1854) |
| Jan 08, 2017   | Credential create should use ace too [1865](https://github.com/huginn/huginn/pull/1865) |
| Jan 08, 2017   | Cleanup [1866](https://github.com/huginn/huginn/pull/1866) |
| Jan 07, 2017   | Default selected value for scenario.icon select [1861](https://github.com/huginn/huginn/pull/1861) |
| Jan 06, 2017   | Agent's id of each incoming event is accessible from Liquid and JavaScriptAgent. [1860](https://github.com/huginn/huginn/pull/1860) |
| Jan 06, 2017   | "Every X" schedules now run on fixed times. [1844](https://github.com/huginn/huginn/pull/1844) |
| Jan 03, 2017   | Twitter agents support "extended" tweets that are longer than 140 characters. [1847](https://github.com/huginn/huginn/pull/1847) |
| Jan 03, 2017   | Make migrations compatible with SQLite [1842](https://github.com/huginn/huginn/pull/1842) |
| Jan 01, 2017   | A new `include_sort_info` Agent option is added to help sort out an Nth event of a series of events created in a run. [1772](https://github.com/huginn/huginn/pull/1772) |
| Dec 31, 2016   | Fix HttpStatusAgent [1776](https://github.com/huginn/huginn/pull/1776) |
| Dec 29, 2016   | Upgrade rails to 5.0.1 [1841](https://github.com/huginn/huginn/pull/1841) |
| Dec 27, 2016   | Don't use the insecure git:// protocol when fetching git gems [1763](https://github.com/huginn/huginn/pull/1763) |
| Nov 30, 2016   | `RssAgent` includes podcast tag values in events created from a podcast feed. [1782](https://github.com/huginn/huginn/pull/1782) |
| Nov 28, 2016   | Remove `BeeperAgent` after Beeper.io shuts down. [1808](https://github.com/huginn/huginn/pull/1808) |
| Nov 27, 2016   | `WebsiteAgent` can interpolate via the `template` option after extraction. [1743](https://github.com/huginn/huginn/pull/1743), [1816](https://github.com/huginn/huginn/pull/1816) |
| Nov 27, 2016   | Disable automatic URL normalization and absolutization on `url` [1771](https://github.com/huginn/huginn/pull/1771) |
| Nov 26, 2016   | Add class of service chooser for Google Flights Agent [1778](https://github.com/huginn/huginn/pull/1778) |
| Nov 23, 2016   | Fix a double-decoding problem in RssAgent [1813](https://github.com/huginn/huginn/pull/1813) |
| Nov 22, 2016   | Cache Agent type select options in Agent#new [1804](https://github.com/huginn/huginn/pull/1804) |
| Nov 20, 2016   | Increase default database pool size to 20 [1805](https://github.com/huginn/huginn/pull/1805) |
| Nov 20, 2016   | `WebsiteAgent` provides a new extractor option `repeat`. [1769](https://github.com/huginn/huginn/pull/1769) |
| Nov 19, 2016   | Fixed the online documentation for the Weather Agent class. [1803](https://github.com/huginn/huginn/pull/1803) |
| Nov 14, 2016   | Fix typos in docker documentation [1792](https://github.com/huginn/huginn/pull/1792) |
| Nov 13, 2016   | Nitrous.io is shutting down [1789](https://github.com/huginn/huginn/pull/1789) |
| Nov 13, 2016   | Prevent submit from disabling on invalid json [1790](https://github.com/huginn/huginn/pull/1790) |
| Nov 13, 2016   | Remove additional nitrous files [1791](https://github.com/huginn/huginn/pull/1791) |
| Nov 03, 2016   | Revert the special treatment for CDATA introduced in #1071 [1770](https://github.com/huginn/huginn/pull/1770) |
| Nov 02, 2016   | Fix `url` handling of WebsiteAgent  [1766](https://github.com/huginn/huginn/pull/1766) |
| Nov 01, 2016   | Fix Stubhub test failures [1764](https://github.com/huginn/huginn/pull/1764) |
| Oct 31, 2016   | Convert a bunch of HTTP links to HTTPS [1757](https://github.com/huginn/huginn/pull/1757) |
| Oct 27, 2016   | `WebsiteAgent` now has improved encoding detection for HTML/XML documents. [1751](https://github.com/huginn/huginn/pull/1751) |
| Oct 27, 2016   | Ignore empty author and link entries in RssAgent [1754](https://github.com/huginn/huginn/pull/1754) |
| Oct 23, 2016   | Use the XPath expression `string(.)` instead of `.//text()` [1744](https://github.com/huginn/huginn/pull/1744) |
| Oct 17, 2016   | Normalize URL in `to_uri` and `uri_expand` liquid filters.                                                   |
| Oct 15, 2016   | Fix delayed_job_active_record overriding defaults [1736](https://github.com/huginn/huginn/pull/1736) |
| Oct 14, 2016   | Add as_object Liquid filter [1716](https://github.com/huginn/huginn/pull/1716) |
| Oct 14, 2016   | Retire ar_mysql_column_charset [1729](https://github.com/huginn/huginn/pull/1729) |
| Oct 11, 2016   | Agent form: ace-editor highlighting and theme [1727](https://github.com/huginn/huginn/pull/1727) |
| Oct 11, 2016   | Manual event agent validate JSON field before form submit [1728](https://github.com/huginn/huginn/pull/1728) |
| Oct 09, 2016   | Update forecast_io gem and language [1722](https://github.com/huginn/huginn/pull/1722) |
| Oct 09, 2016   | Update documentation [1725](https://github.com/huginn/huginn/pull/1725) |
| Oct 06, 2016   | `RssAgent` is reimplemented migrating its underlying feed parser from FeedNormalizer to Feedjira. [1564](https://github.com/huginn/huginn/pull/1564)     |
| Oct 05, 2016   | Migrate to Rails 5. [1688](https://github.com/huginn/huginn/pull/1688)                                      |
| Oct 05, 2016   | Improve URL normalization in `WebsiteAgent`. [1719](https://github.com/huginn/huginn/pull/1719)             |
| Oct 05, 2016   | `PushoverAgent` now treats parameter options as templates rather than default values. [1720](https://github.com/huginn/huginn/pull/1720) |
| Sep 30, 2016   | Fix escape characters of events when dry running [1715](https://github.com/huginn/huginn/pull/1715) |
| Sep 28, 2016   | Allow style tags in sanitized HTML [1712](https://github.com/huginn/huginn/pull/1712) |
| Sep 23, 2016   | Clarify path for a simple body_text event. [1705](https://github.com/huginn/huginn/pull/1705) |
| Sep 21, 2016   | Rescue from AR:SubclassNotFound and allow to delete agents [1695](https://github.com/huginn/huginn/pull/1695) |
| Sep 21, 2016   | Replace jquery.serializeObject with new implementation [1698](https://github.com/huginn/huginn/pull/1698) |
| Sep 21, 2016   | Ignore the fixture API key in WeatherAgent [1694](https://github.com/huginn/huginn/pull/1694) |
| Sep 19, 2016   | Add multipart file upload to `PostAgent`. [1690](https://github.com/huginn/huginn/pull/1690)                |
| Sep 16, 2016   | docker-compose version 2 [1681](https://github.com/huginn/huginn/pull/1681) |
| Sep 15, 2016   | `service_id` is a valid part of the agent_params [1686](https://github.com/huginn/huginn/pull/1686) |
| Sep 15, 2016   | interpolated response [1682](https://github.com/huginn/huginn/pull/1682) |
| Sep 14, 2016   | bundle update net-ssh to 3.0.x (to avoid deprecation warn on Ruby 2.3) [1683](https://github.com/huginn/huginn/pull/1683) |
| Sep 14, 2016   | storage_engine removed since 5.7.5 replaced by default_storage_engine… [1684](https://github.com/huginn/huginn/pull/1684) |
| Sep 12, 2016   | Use strong_parameters and drop protected_attributes [1679](https://github.com/huginn/huginn/pull/1679) |
| Sep 11, 2016   | Updated JsonPathV2 version to latest. [1674](https://github.com/huginn/huginn/pull/1674) |
| Sep 10, 2016   | Remove unused contact model [1680](https://github.com/huginn/huginn/pull/1680) |
| Sep 09, 2016   | Option to set response code for webhook agent [1676](https://github.com/huginn/huginn/pull/1676) |
| Sep 09, 2016   | can_enqueue? propagation detection that does not depend on Rails [1672](https://github.com/huginn/huginn/pull/1672) |
| Sep 08, 2016   | Add cache_response option to completable form fields [1673](https://github.com/huginn/huginn/pull/1673) |
| Sep 08, 2016   | Allow `TwitterUserAgent` to retry failed actions. [1645](https://github.com/huginn/huginn/pull/1645)        |
| Sep 06, 2016   | Update libv8 to fix build issues on OS X [1671](https://github.com/huginn/huginn/pull/1671) |
| Sep 06, 2016   | minor tweaks [1669](https://github.com/huginn/huginn/pull/1669) |
| Sep 04, 2016   | Extract service option prviders for non-standard Omniauth payloads [1655](https://github.com/huginn/huginn/pull/1655) |
| Sep 03, 2016   | Fix SMTP config regression when not using authentication [1663](https://github.com/huginn/huginn/pull/1663) |
| Sep 02, 2016   | Admin "become" method [1659](https://github.com/huginn/huginn/pull/1659) |
| Aug 16, 2016   | `EmailDigestAgent` now relies on received events, rather in memory. [1624](https://github.com/huginn/huginn/pull/1624) |
| Aug 15, 2016   | Update rails to 4.2.7.1 [1630](https://github.com/huginn/huginn/pull/1630) |
| Aug 15, 2016   | Handle removed events when rendering logs [1634](https://github.com/huginn/huginn/pull/1634) |
| Aug 09, 2016   | Docker: fix usage of ENV variables that are not in .env.example [1620](https://github.com/huginn/huginn/pull/1620) |
| Aug 08, 2016   | `DataOutputAgent` now limits events after ordering. [1444](https://github.com/huginn/huginn/pull/1444)      |
| Aug 05, 2016   | Fix dependency check for Tumblr gem [1615](https://github.com/huginn/huginn/pull/1615) |
| Aug 05, 2016   | Add `api_key` option to `UserLocationAgent`. [1613](https://github.com/huginn/huginn/pull/1613)             |
| Jul 27, 2016   | DataOutputAgent cannot create events [1608](https://github.com/huginn/huginn/pull/1608) |
| Jul 26, 2016   | Monkey patch faraday to fix encoding issue in URLs [1607](https://github.com/huginn/huginn/pull/1607) |
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
