# Container download statistics

The **Container downloads** workflow collects public cumulative counters daily at 02:23 UTC.  It tracks these five images:

- `ghcr.io/huginn/huginn`
- `ghcr.io/huginn/huginn-single-process`
- `ghcr.io/huginn/huginn-test`
- `docker.io/huginn/huginn`
- `docker.io/huginn/huginn-single-process`

## Collection sources

The [GitHub Packages REST API](https://docs.github.com/en/rest/packages/packages) does not expose download totals.  The collector reads the public package web pages instead.  It locates the **Total downloads** label and reads the exact integer from the adjacent heading's `title` attribute.  It rejects rounded display values such as `1.23M`, missing labels, and ambiguous results.  It does not sum individual version counts or pull images.

[eliasbenb/ghcr-badge](https://github.com/eliasbenb/ghcr-badge) and [voxpupuli/container_statistics](https://github.com/voxpupuli/container_statistics) demonstrate this source.  We use GitHub directly, with our own HTML parsing and validation, rather than depending on their hosted services or copying their implementation.

For Docker Hub, the collector reads `pull_count` from the official [Get repository in a namespace API](https://docs.docker.com/reference/api/hub/latest/operations/GetRepository/), at `https://hub.docker.com/v2/namespaces/huginn/repositories/IMAGE`.  It verifies the repository identity and requires a nonnegative integer.

Both sources are public and need no registry credentials.  The tasks use Ruby, its standard libraries, and the existing Nokogiri dependency.  Actions uses the project's normal Gemfile and Gemfile.lock with Bundler caching.  The Rake tasks load the application configuration but do not depend on `:environment`, initialize the application, or require a database.  The unit tests also run without a database.

## History and badge

The workflow creates the [`container-stats` branch](https://github.com/huginn/huginn/tree/container-stats) on its first successful scheduled or manual collection.  That branch contains:

- `records/*.json`: immutable snapshots, one per successful execution, including UTC collection time, exact counters, and source URLs.  Multiple manual runs on one day remain separate records.
- `latest.json`: the most recent complete snapshot.
- `summary.json`: current counts, their combined total, and per-image differences for the last 1, 7, and 30 days.
- `badge.svg`: a static badge showing the combined current total for all five images.  It is served directly from GitHub, without a badge service.

The README badge links to this guide.  Its image is unavailable until the first collection creates the data branch.  The badge's SVG title includes the collection timestamp; check `latest.json` or the workflow status for freshness.  A failed collection leaves the last successful badge and records intact.

GitHub normally rewrites external Markdown images through its [Camo image proxy](https://docs.github.com/en/authentication/keeping-your-account-and-data-secure/about-anonymized-urls).  However, its Markdown renderer currently leaves this badge's `https://raw.githubusercontent.com/.../container-stats/badge.svg` URL unchanged, as verified with the GitHub Markdown API.  The raw host still uses CDN and browser caching: its observed `Cache-Control` is `max-age=300`.  Badge updates can therefore lag a successful collection; they are not a real-time display.  This design does not rely on changing README URLs daily or purging Camo.  If GitHub changes its rendering or cache policy, recheck the rendered image URL and response headers before changing hosts or adding cache invalidation.

Each period in `summary.json` uses the most recent snapshot at or before the requested boundary and the latest snapshot.  It includes the actual `from`, `to`, `elapsed_seconds`, and `missing_days`.  If an observation is missing, the difference covers the longer observed interval; it is not an estimate of downloads on the missing day.  Without a sufficiently old baseline, the period is `null`.  A month means a rolling 30-day interval, not a calendar month.

If any counter decreases between observations in a period, `counter_decreased` is `true` and `downloads` is `null` for that image and period.  History keeps the raw values for investigation.  Later periods wholly after that decrease can report differences again.  A reset followed by enough downloads to exceed the previous observation cannot be detected from daily snapshots alone.

## Running and maintaining the workflow

After merging the workflow into `master`, use **Actions → Container downloads → Run workflow**, selecting `master`, to create the first snapshot immediately.  Subsequent runs are scheduled daily; GitHub may delay or skip scheduled runs and can disable schedules after prolonged repository inactivity.  Manual runs from other branches and forks do not publish statistics.

No PAT, registry secret, Pages site, database, or external service is needed.  The collection job grants `GITHUB_TOKEN` only `contents: write` to create and update the data branch.  The test job has only `contents: read`.  If a repository or organization ruleset restricts branch creation or pushes, allow the workflow to create and update `container-stats`; keep protections on `master` intact.

Collection runs share one concurrency group and never cancel a running collection.  The job reads the current data branch, appends a record, and performs a normal push.  If another writer changes the branch, the push fails instead of overwriting that writer's history.  Rerun the workflow after investigating a rejected push.  Do not force-push the data branch.

HTTP requests have connection/read timeouts and up to three attempts for transient network errors, HTTP 408/429, and selected 5xx responses.  Numeric `Retry-After` is honored up to 60 seconds.  A missing or malformed counter fails the run with the image name; nothing is published unless all five counters are available.  An explicit zero is valid; an unavailable value is never converted to zero.  Schema or page changes require updating the collector and its tests.

After the normal [local development setup](../README.md#local-development), use the existing bundle to verify or collect without modifying the remote branch:

```sh
bundle exec rspec spec/lib/container_downloads_spec.rb
mkdir -p .tmp
bundle exec rake 'stats:containers:collect[.tmp/container-downloads.json]'
bundle exec rake 'stats:containers:record[.tmp/container-downloads.json,.tmp/container-stats]'
```

For existing history, use a local checkout of `container-stats` as the output directory.  The recording task rejects duplicate or older timestamps.  Review `summary.json` to compare image and period counts.

## Counter limitations

These are registry-reported downloads/pulls, not unique users, installations, or active deployments.  Automated builds, tests, repeated pulls, and registry-specific counting rules contribute.  GHCR and Docker Hub need not count equivalent operations in the same way; their sum is a combined registry counter, not a deduplicated audience measure.  The test image is included in that total.

Registry counters can be delayed, corrected, reset, or affected by package/version deletion.  GHCR's HTML structure is not an API contract.  Daily history starts with the first successful collection; it cannot reconstruct earlier daily usage.  The snapshots preserve observations even when the upstream counters later change.
