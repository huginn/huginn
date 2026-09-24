# Upgrading Huginn

This guide covers changes that may require configuration or data migration when upgrading an existing installation.  Dates refer to introduction on `master`, not necessarily a tagged release.  See [CHANGES.md](CHANGES.md) for the full change history and the [manual update guide](doc/manual/update.md) for the deployment procedure.

Before a database upgrade or column conversion, back up the database and plan a maintenance window with Huginn's web, scheduler, and worker processes stopped.  Keep the previous application version and a restorable database backup together.

## Gradual migration to RFC 9535 JSONPath

Introduced on `master` on 2026-09-21; included in v2026.09.22.

JSONPath was standardized in 2024 in [RFC 9535](https://www.rfc-editor.org/rfc/rfc9535.html).  Huginn now uses this standardized syntax and evaluation behavior by default.  Expressions require an explicit `$` root: for example, write `$.name` instead of `name`.  Legacy expressions may also differ in filter type conversion, existence tests, array selection, and method calls; adding `$` alone does not establish compatibility.

The normal `db:migrate` step converts simple expressions whose compatibility can be established conservatively.  When an Agent has an uncertain expression, the migration preserves its expressions and adds this option:

```json
{
  "use_legacy_jsonpath": true
}
```

This flag selects legacy validation and execution for that Agent.  Agents that migrate automatically do not receive the flag.  Explicit evaluator choices already saved on Agents are preserved.

Migration output lists URLs of Agents that retain legacy evaluation, grouped by user ID, without including expressions or event data.  Administrators can send each user their own list for review.  Set `DOMAIN` correctly so these links point to the instance.

For each listed Agent, rewrite its expressions for RFC 9535, remove `use_legacy_jsonpath` (or set it to `false`), and validate and test with representative input.  Check result values as well as syntax, particularly where legacy filters compare strings with numbers.  A WebsiteAgent using `on_change` may produce no events when its fetched results match existing events; an empty Dry Run result alone does not show that extraction failed.

To repeat the migration for Agents without an explicit evaluator choice:

```sh
RAILS_ENV=production bundle exec rake agents:migrate_jsonpaths
```

Legacy mode is a compatibility option, not an escape from the security restrictions.  Legacy method calls are limited to an allowlist, including calls in filters and computed indexes.  An expression using a disallowed method must be rewritten even if its Agent retains the legacy flag.

## Introducing delayed_job_master and avoiding stuck advisory locks

Introduced on `master` on 2026-09-14, alongside bounded Agent execution-lock waits and network timeouts.  Worker watchdog supervision followed on 2026-09-21.  Per-Agent execution serialization was introduced on 2026-08-25.

The default threaded runner remains available.  To isolate background jobs in separate, single-threaded worker processes, replace the threaded job process with separate scheduler and master processes, following [Procfile](Procfile):

```procfile
web: bundle exec puma -C config/puma.rb
jobs: bundle exec rails runner bin/agent_runner.rb
dj: env DELAYED_JOB_WORKERS=2 bundle exec bin/delayed_job_master -c config/delayed_job_master.rb
```

Apply this through your process manager and restart the deployment.  Stop the old `bin/threaded.rb` process when switching; the `jobs` process above retains scheduling, while `dj` handles queued jobs.  For Docker deployments, changing a source checkout's Procfile alone does not change the container's configured processes; configure the scheduler and master commands in your container orchestration.  Use Huginn's `bin/delayed_job_master` wrapper so the watchdog is loaded.

An Agent's advisory lock serializes its execution.  A stalled worker can hold that lock and block later runs.  Lock waits now time out, while the master watchdog monitors the full reservation, execution, and cleanup cycle independently of database responsiveness.  It first asks a timed-out worker to unwind, then forcibly terminates it after a grace period.  Closing the worker's database connection releases its session-held advisory locks; abandoned jobs follow the normal failure and retry policy.

Review these settings in [.env.example](.env.example) before switching:

| Setting | Default | Meaning |
| --- | --- | --- |
| `DELAYED_JOB_WORKERS` | `1` | Maximum worker processes; the example above uses two. |
| `DELAYED_JOB_MAX_MEMORY` | `512` | Worker recycling threshold in MB, checked after a job. |
| `DELAYED_JOB_MAX_RUNTIME` | `2` | Job runtime limit in minutes; master workers also apply it to the complete worker cycle. |
| `DELAYED_JOB_SHUTDOWN_GRACE` | `10` | Seconds to unwind before forced termination. |
| `AGENT_EXECUTION_LOCK_TIMEOUT` | `30` | Maximum Agent lock wait in seconds; zero means no wait. |
| `OUTBOUND_NETWORK_OPEN_TIMEOUT` | `10` | Outbound connection timeout in seconds. |
| `OUTBOUND_NETWORK_TIMEOUT` | `60` | Outbound request I/O timeout in seconds. |

Keep the lock wait well below the job runtime limit, noting their different units.  Increase the job limit for long shell commands, DelayAgent emit intervals, or batches whose total processing time exceeds two minutes.  Network timeouts are capped below the job runtime limit.  The master watchdog requires the master process setup; retaining the threaded runner does not enable process-level supervision.

After switching, check job failures and Agent logs for timeouts.  An administrator's "Run now" action resets failed-job state, but retry only after addressing the cause of the failure.

## Choosing outbound proxy routing

Forced routing and bundled Smokescreen were introduced on `master` on 2026-09-08.  Per-Agent opt-in routing followed on 2026-09-20.

Choose the mode appropriate to the instance:

| Mode | Official Docker images | Separately managed proxy | Agent configuration |
| --- | --- | --- | --- |
| Forced | `ENABLE_SMOKESCREEN=true` | Set `OUTBOUND_PROXY` to the proxy URL. | Applies regardless of `use_agent_proxy`; per-Agent `proxy` URLs are rejected. |
| Per-Agent | `START_SMOKESCREEN=true`; leave `ENABLE_SMOKESCREEN` and `OUTBOUND_PROXY` unset. | Set `AGENT_PROXY` to the proxy URL; leave `OUTBOUND_PROXY` unset. | Add `"use_agent_proxy": true` to supported Agents. |
| Unchanged routing | Leave both startup settings and both proxy URLs unset. | No new proxy configuration. | Omit `use_agent_proxy` or set it to `false`. |

The Docker startup settings start the bundled Smokescreen proxy on `http://127.0.0.1:4750`.  Forced mode defaults `OUTBOUND_PROXY` to that address; either startup setting defaults `AGENT_PROXY` to it.  Explicitly configured proxy URLs are preserved.  Apply the settings to all containers that make requests, including web and worker containers.

Forced routing is intended for instances where untrusted users can create Agents.  Per-Agent routing lets trusted users protect Agents that consume URLs from external events while retaining access to internal services elsewhere.  Setting `AGENT_PROXY` alone does not opt any Agent in.  `OUTBOUND_PROXY` always takes precedence, including when an Agent sets `use_agent_proxy` to `false`.

Existing `http_proxy` and related environment settings may still affect unchanged routing.  An opted-in Agent fails if no proxy is configured or the proxy is unavailable; it does not fall back to a direct connection.  Scenario imports use forced routing when configured, but do not opt in to `AGENT_PROXY`.

Smokescreen rejects internal destinations by default.  Review Agents that legitimately access internal services before enforcing it, and configure narrow exceptions as needed.  This routing does not cover non-HTTP protocols such as FTP, IMAP, or MQTT.  See [Restricting outbound requests](doc/manual/outbound-requests.md) for supported Agents, proxy exceptions, and coverage limits.

## Moving official images to MySQL 8

The amd64 multi-process image moved its bundled database to MySQL 8.0 on `master` on 2026-04-10.  Docker Compose database definitions moved to MySQL 8.0 on 2026-05-16.

The updated multi-process image and MySQL Compose definitions use MySQL 8.4 LTS.  The bundled server supports both amd64 and arm64.

This affects installations using the image's bundled database or the supplied MySQL Compose configuration.  Updating a Huginn application image does not upgrade a separately managed database server.  PostgreSQL installations do not need this migration.

### From MySQL 8.0 to 8.4

Back up the volume, retain the previous image, and run the [MySQL Upgrade Checker](https://dev.mysql.com/doc/mysql-shell/8.4/en/mysql-shell-utilities-upgrade.html) against the running 8.0 server before changing images.  MySQL 8.4 disables `mysql_native_password` by default.  Convert accounts used by Huginn or administrators to `caching_sha2_password` while 8.0 is still available.  The bundled database startup handles the local root account automatically; additional accounts need to be converted separately.

Stop Huginn's web, scheduler, and worker processes, set `innodb_fast_shutdown = 0`, and shut MySQL down cleanly.  Start MySQL 8.4 against the existing volume and allow the upgrade to complete before resuming Huginn.  Follow the commands for your deployment in the [single-process](docker/single-process/README.md#usage) or [multi-process](docker/multi-process/README.md#usage) Docker guide, or the [built-in database upgrade procedure](docker/multi-process/README.md#upgrading-the-built-in-database).

Keep the pre-upgrade backup until the new database and Huginn have been verified.  To roll back, restore that backup with the old database version rather than starting the old server against the upgraded volume.

### From MySQL 5.7

MySQL 5.7 cannot be upgraded directly to 8.4.  Back up the volume, stop Huginn's writers, set `innodb_fast_shutdown = 0` on the running 5.7 server, and shut it down cleanly.  Upgrade to MySQL 8.0 first.  For Compose, temporarily set both `mysql` and `mysqldata` images to `mysql:8.0` and let the server complete that upgrade.  Then follow the 8.0-to-8.4 procedure above, changing both images to `mysql:8.4`.

The new multi-process image refuses detected MySQL 5.7 data before starting the bundled server.  Use the previous Huginn image containing MySQL 8.0 for the intermediate upgrade.  That image's recovery helper downloads and verifies a MySQL 5.7 rescue binary and performs a clean shutdown before starting 8.0.  This recovery step requires amd64 and access to the download server; it is not available on arm64 and is not a general migration path for MariaDB or arbitrary older versions.

## Opting in to native JSON columns

Introduced on `master` on 2026-04-13.  MySQL sort-buffer guidance and the bundled server setting were added on 2026-07-29.

This migration is optional and independent of the JSONPath evaluator change.  Leaving `NATIVE_JSON_COLUMNS` unset retains serialized text columns.  Opting in converts Agent options and memory, Event payloads, and Service options to MySQL `JSON` or PostgreSQL `JSONB`.

Before conversion, back up the database, stop Huginn processes, and allow time for table alterations, especially for a large Events table.  For MySQL, configure `sort_buffer_size` to at least `4M` to avoid "Out of sort memory" errors when sorting rows containing JSON columns:

```ini
[mysqld]
sort_buffer_size = 4M
```

The bundled MySQL server already includes this setting.  For an external server, apply it through that server's configuration; see the [installation guide](doc/manual/installation.md).

Run migrations with the opt-in variable present:

```sh
RAILS_ENV=production NATIVE_JSON_COLUMNS=true bundle exec rake db:migrate
```

For Docker-managed migrations, pass `NATIVE_JSON_COLUMNS=true` to the container running the migrations.  The optional migration path is enabled by any nonempty value, so leave the variable unset to opt out; do not use `NATIVE_JSON_COLUMNS=false`.

The flag controls migration discovery, not runtime serialization.  You can enable it later even if ordinary migrations are already up to date, and remove it after conversion completes.  Removing it does not convert columns back to text.  Restart Huginn processes after conversion so they reload the column types.  If conversion fails, inspect the migration error and database state before resuming; do not assume all column changes were rolled back.
