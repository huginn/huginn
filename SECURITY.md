# Security Policy

## Supported versions

Huginn is released from `master` with date-based version tags.  Security fixes go into `master` and the next release, and are published as the official Docker images (`ghcr.io/huginn/huginn` and `ghcr.io/huginn/huginn-single-process`).  Older releases do not receive backported fixes, so please stay on the latest release.

## Reporting a vulnerability

Please report vulnerabilities privately through [GitHub's private vulnerability reporting](https://github.com/huginn/huginn/security/advisories/new).  Do not open a public issue, discussion, or pull request for an unfixed vulnerability.

Include the affected version or commit, the configuration needed to reproduce the problem, and its impact.  Huginn is maintained by one person in spare time, so a response may take a while.  Fixed vulnerabilities are announced as [security advisories](https://github.com/huginn/huginn/security/advisories) and noted in [CHANGES.md](CHANGES.md), with credit to the reporters.

## Trust model

Huginn is built for people who want to automate things on their own server and keep their own data, rather than rely on a commercial service.  It puts what users can do ahead of locking things down by default.  Agents can contact any host their owner configures, including hosts on private networks, and when `ENABLE_INSECURE_AGENTS` is set they can run shell commands and read local files.

Huginn's security boundaries follow from that:

- Visitors who are not logged in must not be able to read data, run Agents, or otherwise affect the instance, except through endpoints a user deliberately publishes, such as webhooks and output feeds.
- Logged-in users are trusted to configure Agents that act on their behalf.  They must still not be able to read or use other users' Agents, Events, Credentials, or Services.
- Admins manage all users and can switch to any of them.

Opening an instance to users you do not fully trust takes additional configuration.  At least, restrict outbound requests as described in [doc/manual/outbound-requests.md](doc/manual/outbound-requests.md) and leave `ENABLE_INSECURE_AGENTS` unset.

Reports are welcome when a visitor can affect the instance, when a user can cross into another user's data, or when a restriction the operator has enabled can be bypassed.  Behavior intended for trusted users is not a vulnerability by itself, for example an Agent reaching an internal address when no outbound restriction is configured.
