# Contributing to ai_bridge

Thanks for helping improve `souldo-ai_bridge`, a Puppet module that deploys an OpenAI-compatible LiteLLM bridge for Puppet Enterprise AI model routing. This project is licensed under the Apache License 2.0, and contributions are accepted under the same license.

## Development setup

This repository has no dedicated development guide yet. Start with these existing docs:

- [README.md](README.md) for what the module does and how to install it.
- [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md) for how the pieces fit together.
- [docs/CONFIGURATION.md](docs/CONFIGURATION.md) for the Hiera parameters the module accepts.
- [docs/USER_GUIDE.md](docs/USER_GUIDE.md) and [docs/ELI10.md](docs/ELI10.md) for usage walk-throughs.

The repository has four testable parts, each with its own toolchain:

| Part | Location | Toolchain |
|------|----------|-----------|
| Puppet module (classes, types, plans) | `manifests/`, `types/`, `plans/`, `spec/` | Ruby 3.2, Bundler, Puppet 7 or 8 |
| Bolt deployment plan | `plans/`, `tasks/`, `tests/bolt_deploy_spec.rb` | Ruby, Bolt 4.0.0 |
| Python helpers and callbacks | `files/`, `tests/test_*.py` | Python 3.12 (standard library `unittest`) |
| Request capture tool | `tools/pe-capture/` | Go (version pinned in `tools/pe-capture/go.mod`) |

Install the Ruby dependencies from the repository root:

```bash
bundle install
```

The `Gemfile` reads two environment variables:

- `PUPPET_GEM_VERSION` selects the Puppet version (defaults to `~> 8.0`; CI also tests `~> 7.0`).
- `BOLT_TESTS=true` adds the pinned `bolt` gem, which the Bolt plan tests need.

## Running the checks

CI runs the commands below, so run them locally before opening a pull request. The workflow is defined in `.github/workflows/ci.yml`; a mirror of the non-Docker checks exists in `.gitlab-ci.yml`.

Puppet module checks:

```bash
bundle exec puppet parser validate manifests/*.pp types/*.pp
bundle exec puppet-lint --relative --fail-on-warnings manifests types plans
bundle exec metadata-json-lint metadata.json
bundle exec rake spec_prep
bundle exec rspec spec/classes/init_spec.rb
```

Bolt plan tests (requires the Bolt gem):

```bash
BOLT_TESTS=true PUPPET_GEM_VERSION='~> 8.0' bundle install
BOLT_TESTS=true bundle exec rake spec_prep
BOLT_TESTS=true bundle exec rspec tests/bolt_deploy_spec.rb
```

Python helper tests:

```bash
python3 -B -m unittest discover -s tests -p test_pe_usage.py
python3 -B -m unittest discover -s tests -p test_personality.py
python3 -B -m unittest discover -s tests -p test_docker_runtime.py
python3 -B -m unittest discover -s tests -p test_bolt_parameters.py
```

Go checks for the capture tool:

```bash
cd tools/pe-capture
test -z "$(gofmt -l .)"
go vet ./...
go test -race -cover ./...
```

Callback runtime tests (`tests/test_*_runtime.py`) exercise real LiteLLM callbacks, so CI runs them inside the pinned LiteLLM container image rather than on the runner. If you change the callback code under `files/`, run them the same way CI does (see the `callback-runtime` job in `.github/workflows/ci.yml` for the exact image digest):

```bash
docker run --rm --entrypoint python \
  -v "$PWD:/workspace:ro" \
  ghcr.io/berriai/litellm@sha256:<digest-from-ci.yml> \
  -B -m unittest discover -s /workspace/tests -p '*runtime.py'
```

The CI `package` job also builds a Forge candidate tarball with `puppet-modulebuilder` 2.1.0. The builder is an allowlist (it ships only `manifests/`, `templates/`, `types/`, `files/`, `data/`, `plans/`, `tasks/`, `examples/`, `docs/`, `hiera.yaml`, `metadata.json`, `README*`, `CHANGELOG*`, `LICENSE` and `REFERENCE.md`) and does not read `.pdkignore` or `.pmtignore`; anything that must not ship belongs outside those paths.

## Coding standards

- **Puppet:** `puppet-lint` runs with `--fail-on-warnings` over `manifests`, `types`, and `plans`, so any warning fails CI. `puppet parser validate` must also pass.
- **Metadata:** `metadata.json` must pass `metadata-json-lint`. Do not widen the `operatingsystem_support` claims without tests that back them.
- **Ruby:** files start with `# frozen_string_literal: true`, matching the existing `Rakefile`, `Gemfile`, and specs.
- **Go:** code must be `gofmt`-clean and pass `go vet`; tests run with the race detector.
- **Secrets:** never commit real API keys, certificates, or captured traffic. `.gitignore` already excludes `.env`, `*.jsonl` capture logs, and `litellm/tls/*`. Captured logs can contain prompts, so redact before sharing. See [docs/SECURITY.md](docs/SECURITY.md).

## Tests and documentation

- Add or update a spec in `spec/classes/` for any change to module behavior, a Python test in `tests/` for helper or callback changes, and a Go test in `tools/pe-capture/` for capture tool changes.
- Some behavior needs a real PE console or real provider keys and cannot be checked by automation. Record those checks in [docs/UAT_HUMAN_TESTING.md](docs/UAT_HUMAN_TESTING.md).
- Update the relevant document in `docs/` when you change a parameter, default, or deployment step, and add a user-visible entry to `CHANGELOG.md`.
- Do not assume contributors or users run an internal certificate authority; examples and docs should work with publicly trusted or explicitly supplied certificates.

## Pull request guidelines

No pull request template or branch naming convention is defined in this repository. Please follow these practices:

- Branch from `main` and keep each pull request focused on one change.
- Make sure the `puppet`, `bolt`, `helpers`, `package`, and `callback-runtime` CI jobs pass. CI runs on every push and pull request.
- Describe what changed and why, and note any manual (UAT) verification you performed.
- Do not include secrets, captured traffic, or generated artifacts such as `pkg/` or `Gemfile.lock` (both are git-ignored).
- Keep commit messages short and descriptive in the imperative mood, matching the existing history (for example, "Handle real asynchronous chat dispatch and test callback runtime in CI").

## Reporting issues

Open an issue at <https://github.com/matthewrstone/puppet-ai_bridge/issues>. No issue templates are configured, so please include:

- What you expected to happen and what actually happened.
- Steps to reproduce, including the relevant Hiera values (with secrets removed).
- Your environment: Puppet or Bolt version, OS release, Docker version, LiteLLM image in use, and PE version if relevant.
- Relevant logs. See [docs/TROUBLESHOOTING.md](docs/TROUBLESHOOTING.md) for what to collect.

For anything that may be a security vulnerability, avoid posting exploit details or secrets in a public issue. See [docs/SECURITY.md](docs/SECURITY.md) for the project's security notes, and contact the maintainer listed in `metadata.json` instead.

## License

By contributing, you agree that your contributions are licensed under the [Apache License 2.0](LICENSE).
