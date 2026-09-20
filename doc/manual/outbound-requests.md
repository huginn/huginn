# Restricting outbound requests

Agents make HTTP requests to whatever URL their owner configures: WebsiteAgent, PostAgent, RssAgent, HttpStatusAgent, JavaScriptAgent's `Agent.fetch`, the Scenario import form and many more.  On a single-user instance that is the point.  On an instance where people you do not fully trust can sign up, it lets any user make the Huginn server connect to addresses only the server can reach: services on the loopback interface, the internal network, or a cloud provider's metadata endpoint at `169.254.169.254`, which can hand out credentials.

Huginn does not try to decide inside the application which addresses are safe.  Instead it can route every outbound HTTP(S) request through an egress proxy that resolves the hostname, checks the resulting address, and refuses anything that is not publicly routable.  The proxy makes the decision at the moment it connects, so DNS answers that change between validation and connection, redirects to internal addresses, and hostnames with a mix of public and private records cannot get around it.

## Enabling the proxy in Docker

The official Docker images bundle [Smokescreen](https://github.com/stripe/smokescreen), Stripe's egress proxy.  Set `ENABLE_SMOKESCREEN=true` on the container:

    docker run -e ENABLE_SMOKESCREEN=true ... ghcr.io/huginn/huginn

With Docker Compose, add it to the `environment` of the `web` and `threaded` services (see the commented examples in the compose files).  Smokescreen then starts inside the container, listening on `127.0.0.1:4750`, and `OUTBOUND_PROXY` is set to point at it unless you set it yourself.

Smokescreen refuses, by default, loopback, link-local (including `169.254.169.254`), private (RFC 1918 and `fc00::/7`), carrier-grade NAT (`100.64.0.0/10`), multicast and unspecified addresses, and IPv6 addresses that embed an IPv4 address.  A refused request fails with a proxy error that shows up in the Agent's log.

If Agents legitimately need to reach a service on your internal network, allow it explicitly:

    SMOKESCREEN_OPTS=--allow-address=intranet.example.com:443
    SMOKESCREEN_OPTS=--allow-range=10.1.2.0/24

Never allow the metadata address range.

## Using another proxy

Any HTTP proxy that supports `CONNECT` and validates the resolved address works.  Run it wherever suits your deployment and set:

    OUTBOUND_PROXY=http://proxy.internal:3128

When `OUTBOUND_PROXY` is set, Huginn routes every HTTP client it builds through it and refuses the per-Agent `proxy` option, so a user cannot pick a different proxy to get around it.  A malformed value stops Huginn from starting.  Setting `http_proxy` and `https_proxy` in the environment as well catches third-party code that does not go through Huginn's clients; do not set `no_proxy` for internal hosts, since that bypasses the proxy.

## Using a proxy only for selected Agents

Even trusted users may process events containing URLs from external sources.  An Agent that uses such a URL can unintentionally access an internal service or a metadata endpoint.  Opt-in proxy routing lets users protect those Agents with Smokescreen, or another proxy that rejects internal destinations, while retaining direct access for other Agents.

On an instance where all users are trusted, you can run Smokescreen without routing requests through it by default.  In the official Docker images, set `START_SMOKESCREEN=true` and leave `ENABLE_SMOKESCREEN` and `OUTBOUND_PROXY` unset.  This starts the bundled proxy and defaults `AGENT_PROXY` to `http://127.0.0.1:4750` unless you set it yourself.  With Docker Compose, set it on both the `web` and `threaded` services.

Outside Docker, start your proxy separately and set `AGENT_PROXY` to its URL.  Setting `AGENT_PROXY` alone does not route any requests through it.  A malformed URL stops Huginn from starting.

To opt in, add this Agent option:

```json
{
  "use_agent_proxy": true
}
```

This is supported by Agents using the shared web request options (including WebsiteAgent, PostAgent, RssAgent, HttpStatusAgent and the OpenAI Agents), and by JavaScriptAgent's `Agent.fetch` and `Agent.fetchAll`.  It applies to the Agent's requests, not to individual `fetch` call options.  When neither `OUTBOUND_PROXY` nor `AGENT_PROXY` is set, opting in fails rather than connecting directly.  Proxy connection failures also fail the request without a direct fallback.

Omitting `use_agent_proxy`, or setting it to `false`, preserves normal request behavior.  Existing environment proxy settings such as `http_proxy` may still apply; leave those unset if normal requests should connect directly.  Scenario imports do not opt in to `AGENT_PROXY`.

The existing `proxy` Agent option can still specify a URL directly, but cannot be combined with `use_agent_proxy=true`.

`OUTBOUND_PROXY` always takes precedence, even when `use_agent_proxy=false`, and continues to forbid the `proxy` Agent option.  `ENABLE_SMOKESCREEN=true` retains its existing behavior: it starts Smokescreen and defaults `OUTBOUND_PROXY` to it.  Neither `START_SMOKESCREEN=false` nor any Agent option can disable that enforcement.  Both Docker startup settings also default `AGENT_PROXY` to the bundled proxy, preserving an explicitly configured value.

| Docker configuration | Start Smokescreen | Default request routing |
| --- | --- | --- |
| All proxy settings unset | No | Normal connection |
| `ENABLE_SMOKESCREEN=true` | Yes | Forced through Smokescreen |
| `START_SMOKESCREEN=true` | Yes | Normal connection; Agents can opt in |
| `OUTBOUND_PROXY=URL` | No | Forced through the specified proxy |
| Either startup setting plus `OUTBOUND_PROXY=URL` | Yes | Forced through the specified proxy |

## What this does not cover

- Agents that speak protocols other than HTTP: FtpsiteAgent, ImapFolderAgent, MqttAgent and JabberAgent connect directly to the host they are configured with.  Restrict them with network rules or by not granting untrusted users access to them.
- Connections that Huginn itself needs, such as its database, which do not go through the proxy.
- Anything a firewall would catch that the proxy does not.  Treat the proxy as one layer: on a cloud host, also require IMDSv2 or block the metadata endpoint at the network level, and restrict the container's egress where you can.
