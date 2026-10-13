# Contributing to Huginn

Thank you for helping with Huginn.  Bug fixes, new Agents, UI improvements, documentation, and tutorials are all welcome.

## Asking questions and suggesting ideas

- Ask usage questions and discuss ideas in [GitHub Discussions](https://github.com/huginn/huginn/discussions).
- Suggest new Agents in the [suggest an Agent thread](https://github.com/huginn/huginn/issues/353).
- Report bugs as [issues](https://github.com/huginn/huginn/issues/new/choose).  Include the Huginn version or commit, how you run it (Docker image, manual installation, or another platform), and the steps to reproduce the problem.
- Report security vulnerabilities privately, as described in [SECURITY.md](SECURITY.md).

## Setting up a development environment

Follow [Local development](README.md#local-development) in the README.  To run the specs without installing Chrome and databases locally, use the Docker-based test environment in [docker/test/README.md](docker/test/README.md).

## Sending pull requests

- Keep each pull request to one topic, and base it on the latest `master`.
- Add or update specs for the behavior you change, and run them with `bundle exec rspec`.  CI runs the full suite against MySQL and PostgreSQL.
- Describe user-visible changes in the pull request, including any configuration or data migration that existing installations need.  The maintainer records them in [CHANGES.md](CHANGES.md) and [UPGRADING.md](UPGRADING.md).
- If you change pages shown in the README screenshots, regenerate them with `bin/screenshots`.
- Update the documentation under `doc/` when you change installation or configuration steps.

## Writing new Agents

General-purpose Agents are welcome in the core repository.  Agents for a specific service or a narrow use case are better published as gems; see [huginn_agent](https://github.com/huginn/huginn_agent) and [Creating a new Agent](https://github.com/huginn/huginn/wiki/Creating-a-new-agent).  Users install such gems with the `ADDITIONAL_GEMS` environment variable.

## License

By contributing, you agree that your contributions are licensed under the [MIT License](LICENSE).
