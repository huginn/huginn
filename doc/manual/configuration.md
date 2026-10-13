# Optional configuration

These settings are not needed for a basic installation.  Most of them are environment variables; see `.env.example` for the full list.

## Restrict outbound requests on shared instances

If people you do not fully trust can create Agents on your instance, route outbound requests through an egress proxy so that Agents cannot reach internal services.  See [outbound-requests.md](outbound-requests.md).

## Enable the WeatherAgent

The WeatherAgent needs a [Weather Data API key from Pirate Weather](https://pirate-weather.apiable.io/products/weather-data).  Sign up for one and then change the value of `api_key: your-key` in your seeded WeatherAgent.

## Run without SSL

Huginn assumes that your deployment runs over SSL, which is a very good idea.  If you must turn this off, set `FORCE_SSL=false` in your environment to stop redirecting to HTTPS.  "Remember me" cookies are still marked `secure` in production, so they will not be sent over plain HTTP unless you also edit `config/initializers/devise.rb` and change the `rememberable_options` for the production environment.  Only do this on a network you trust.

## Private development

To keep your own Agents or changes in a private fork while tracking upstream, see the [private development instructions](https://github.com/huginn/huginn/wiki/Private-development-instructions) on the wiki.
