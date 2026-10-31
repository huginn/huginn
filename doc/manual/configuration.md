# Optional configuration

These settings are not needed for a basic installation.  Most of them are environment variables; see `.env.example` for the full list.

## Restrict outbound requests on shared instances

If people you do not fully trust can create Agents on your instance, route outbound requests through an egress proxy so that Agents cannot reach internal services.  See [outbound-requests.md](outbound-requests.md).

## Enable the WeatherAgent

The WeatherAgent needs a [Weather Data API key from Pirate Weather](https://pirate-weather.apiable.io/products/weather-data).  Sign up for one and then change the value of `api_key: your-key` in your seeded WeatherAgent.

## Run without SSL

Huginn assumes that your deployment runs over SSL, which is a very good idea.  If you must turn this off, set `FORCE_SSL=false` in your environment to stop redirecting to HTTPS.  "Remember me" cookies are still marked `secure` in production, so they will not be sent over plain HTTP unless you also edit `config/initializers/devise.rb` and change the `rememberable_options` for the production environment.  Only do this on a network you trust.

## LDAP login

Huginn can let users sign in against an LDAP directory (for example OpenLDAP or Active Directory) in addition to local accounts.  It is disabled unless `LDAP_HOST` is set, and it does not change anything for installations that leave it unset.

Set at least `LDAP_HOST` and `LDAP_BASE`; see the `LDAP login (optional)` block in `.env.example` for every variable.  Notes on the defaults:

- **Encryption is on by default.**  `LDAP_METHOD` defaults to `tls` (StartTLS); use `ssl` for LDAPS.  `plain` is unencrypted and has to be selected explicitly.
- **Certificates are verified by default.**  For a self-signed server, point `LDAP_CA_FILE` at its CA rather than turning verification off.
- **Users are matched by username only.**  An LDAP email address is never used to adopt an existing local account.  New local accounts are created from LDAP only when `LDAP_AUTO_CREATE=true`.  Be aware of what username matching implies: once LDAP is enabled, Huginn trusts the directory for **every** local account whose username also exists in the directory — including privileged ones such as `admin`.  Anyone who can authenticate as that name in the directory can sign into the matching Huginn account.  Restrict who may log in with `LDAP_FILTER` (for example to members of a dedicated group), and make sure directory usernames do not unintentionally overlap with sensitive local accounts.
- **Restricting who may log in.**  Use `LDAP_FILTER` with `%{username}` (for example to require membership of a group); the value is placed into the directory filter with escaping.
- A "Log in with LDAP" form appears on the sign-in page only while the feature is enabled.

Signing in with LDAP is separate from connecting an external *service* to an Agent on the Services page; the two do not share credentials or accounts.
