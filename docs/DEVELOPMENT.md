<!-- generated-by: gsd-doc-writer -->
# Development

This guide is for people changing the `souldo-ai_bridge` Puppet module itself. If you only want to deploy it, start with the [User guide](USER_GUIDE.md) or [Bolt deployment](BOLT_DEPLOYMENT.md). For how the pieces fit together, see [ARCHITECTURE.md](ARCHITECTURE.md); for module settings, see [CONFIGURATION.md](CONFIGURATION.md).

## Local setup

The module has four kinds of code, each with its own toolchain:

| Area | Location | Toolchain |
|------|----------|-----------|
| Puppet classes, types, Bolt plan | `manifests/`, `types/`, `plans/`, `templates/` | Ruby (CI uses 3.2), Bundler, Puppet 7 or 8 |
| Bolt task | `tasks/docker_runtime.py`, `tasks/docker_runtime.json` | Python 3 |
| LiteLLM callbacks | `files/pe_compat.py`, `files/pe_usage.py`, `files/personality.py`, `files/personality_callback.py` | Python 3 (CI uses 3.12) |
| Capture utility | `tools/pe-capture/` | Go (`go.mod` declares 1.24) |

1. Fork and clone the repository:
   ```bash
   git clone https://github.com/matthewrstone/puppet-ai_bridge.git
   cd puppet-ai_bridge
   ```
2. Install the Ruby dependencies from the `Gemfile` (Puppet, `puppet-lint`, `puppetlabs_spec_helper`, `rspec-puppet`, `metadata-json-lint`):
   ```bash
   bundle install
   ```
   Select a Puppet series with `PUPPET_GEM_VERSION` (default `~> 8.0`), for example `PUPPET_GEM_VERSION='~> 7.0' bundle install`. The module declares Puppet `>= 7.0.0 < 9.0.0`, and CI tests 7 and 8.
3. Link the module into the spec fixtures. `.fixtures.yml` symlinks the checkout as `ai_bridge`:
   ```bash
   bundle exec rake spec_prep
   ```
   This creates `spec/fixtures/modules/`, which is git-ignored.
4. Optional, only for the Bolt plan specs: Bolt is added to the bundle when `BOLT_TESTS=true` (pinned to `bolt = 4.0.0`):
   ```bash
   BOLT_TESTS=true PUPPET_GEM_VERSION='~> 8.0' bundle install
   ```

The Python helpers and the Go utility need no install step beyond a Python 3 and a Go toolchain.

### Trying the module without a PE install

You do not need a Puppet Enterprise server or any certificate authority to work on the module. Unit specs compile the catalog in memory with fake facts and fake keys.

To run the container itself on a lab machine, `litellm/docker-compose.yml` starts the same LiteLLM image without Puppet:

```bash
cd litellm
cp .env.example .env     # edit LITELLM_MASTER_KEY and provider keys
# edit config.yaml for the backend you want
# place server.crt and server.key in litellm/tls/ (git-ignored)
docker compose up -d     # or: podman compose up -d
```

For TLS in that setup, use a certificate issued by the Puppet CA (see the README's TLS section), or run on a private lab network and drop the `--ssl_*` arguments from the compose `command` so the bridge speaks plain HTTP (the module equivalent is `manage_tls: false`). Do not expose a plain-HTTP bridge beyond a private network.

`tools/pe-capture` is a small standalone Go server that imitates the OpenAI endpoints PE calls and logs every request as JSONL. It is a debugging aid, not part of the shipped module.

```bash
cd tools/pe-capture
go build ./...
go run . -listen :4000 -log -    # plain HTTP, prints captured requests to stdout
```

Run `go run . -h` for the full flag list (`-upstream`, `-rewrite-model`, `-require-key`, `-cert`, `-key`).

## Build commands

There is no `package.json`; the module is driven by Rake tasks from `puppetlabs_spec_helper` (the `Rakefile` only requires `puppetlabs_spec_helper/rake_tasks`) plus direct tool invocations. These are the commands CI runs.

| Command | Description |
|---------|-------------|
| `bundle exec puppet parser validate manifests/*.pp types/*.pp` | Syntax-check all manifests and type aliases |
| `bundle exec puppet-lint --relative --fail-on-warnings manifests types plans` | Style lint; warnings fail the build |
| `bundle exec metadata-json-lint metadata.json` | Validate module metadata |
| `bundle exec rake spec_prep` | Create `spec/fixtures/modules/ai_bridge` symlink |
| `bundle exec rake spec_clean` | Remove fixtures created by `spec_prep` |
| `bundle exec rspec spec/classes/init_spec.rb` | rspec-puppet catalog tests for the `ai_bridge` class |
| `BOLT_TESTS=true bundle exec rspec tests/bolt_deploy_spec.rb` | Bolt plan tests for `ai_bridge::deploy` |
| `python3 -B -m unittest discover -s tests -p test_pe_usage.py` | PE usage-normalization helper tests |
| `python3 -B -m unittest discover -s tests -p test_personality.py` | Personality helper tests |
| `python3 -B -m unittest discover -s tests -p test_docker_runtime.py` | Bolt runtime task tests |
| `python3 -B -m unittest discover -s tests -p test_bolt_parameters.py` | Bolt parameter helper tests |
| `cd tools/pe-capture && go vet ./... && go test -race -cover ./...` | Go checks for the capture utility |

Packaging is done with the reference module builder, as in the CI `package` job:

```bash
gem install puppet-modulebuilder --version 2.1.0 --no-document
ruby -r fileutils -r puppet/modulebuilder -e 'Puppet::Modulebuilder::Builder.new(Dir.pwd, File.join(Dir.pwd, "pkg"), nil).build'
```

The tarball lands in `pkg/` (git-ignored). The builder (`puppet-modulebuilder`, used by both `pdk build` and CI) uses an **allowlist**: it ships only `manifests/`, `templates/`, `types/`, `files/`, `data/`, `plans/`, `tasks/`, `examples/`, `docs/`, `hiera.yaml`, `metadata.json`, `README*`, `CHANGELOG*`, `LICENSE` and `REFERENCE.md`, and it does **not** read `.pdkignore` or `.pmtignore`. Development material (`spec/`, `tests/`, `tools/`, `litellm/`, `.planning/`, `assets/`) stays out because it is outside the allowlist; to keep something out of the package, put it outside those paths (that is why the README graphic lives in `assets/`, not `docs/`). Packaging notes and release gates are in [FORGE_READINESS.md](FORGE_READINESS.md). The module deliberately keeps its small hand-maintained `Gemfile` and specs rather than being converted with `pdk convert`.

## Code style

- **Puppet**: `puppet-lint` with `--relative --fail-on-warnings`, run over `manifests`, `types`, and `plans`. Fix warnings; do not suppress them. Compile-time validation in the class uses `fail()` with clear messages, and new parameters should use the local type aliases in `types/` (`Ai_bridge::Backend`, `Ai_bridge::Port`, `Ai_bridge::Url`, `Ai_bridge::Absolutepath`) rather than adding a `puppetlabs-stdlib` dependency. The module has no Puppet module dependencies.
- **Ruby specs**: files start with `# frozen_string_literal: true`.
- **Python**: standard library only in the helper scripts and the Bolt task, so they run on a bare target host. Tests use `unittest`.
- **Go**: `gofmt` clean (CI fails on `gofmt -l .` output) and `go vet` clean.
- **Metadata**: `metadata-json-lint` must pass.

No `.editorconfig`, ESLint, Prettier, or Biome configuration exists in this repository.

## Testing

Run the fast checks before every push:

```bash
bundle exec puppet parser validate manifests/*.pp types/*.pp
bundle exec puppet-lint --relative --fail-on-warnings manifests types plans
bundle exec metadata-json-lint metadata.json
bundle exec rake spec_prep
bundle exec rspec spec/classes/init_spec.rb
```

Two suites need extra setup:

- `tests/test_pe_compat_runtime.py` and `tests/test_personality_runtime.py` import LiteLLM's real response classes. Run them inside the reviewed LiteLLM image, as the `callback-runtime` CI job does (see `.github/workflows/ci.yml` for the pinned image digest):
  ```bash
  docker run --rm --entrypoint python \
    -v "$PWD:/workspace:ro" \
    ghcr.io/berriai/litellm@sha256:<digest-from-ci.yml> \
    -B -m unittest discover -s /workspace/tests -p '*runtime.py'
  ```
- `tests/bolt_deploy_spec.rb` needs `BOLT_TESTS=true` when you run `bundle install`, so Bolt is in the bundle.

Tests that cannot be automated (a real PE console, real provider keys) are in [UAT_HUMAN_TESTING.md](UAT_HUMAN_TESTING.md).

## Branch conventions

No branch naming rule is documented in the repository. The default branch is `main`, and the repository has only that branch. Use short, descriptive topic branches such as `feat/<topic>` or `fix/<topic>` and open pull requests against `main`.

## PR process

There is no `.github/PULL_REQUEST_TEMPLATE.md`; see also [CONTRIBUTING.md](../CONTRIBUTING.md). In practice:

- CI (`.github/workflows/ci.yml`, workflow "Module CI") runs on every push, pull request, and manual dispatch. All five jobs should be green: `puppet` (Puppet 7 and 8 matrix), `bolt`, `helpers` (Python and Go), `package`, and `callback-runtime`.
- Add or update specs for any behavior change: `spec/classes/init_spec.rb` for class and template output, `tests/` for Python helpers and the Bolt plan and task.
- Update the docs in `docs/` and the README when a parameter, default, or behavior changes, and add an entry to `CHANGELOG.md` for user-visible changes.
- Never commit real keys, certificates, or private keys. Use obvious placeholders in examples. `.env`, `litellm/tls/*`, and `*.jsonl` captures are git-ignored; see [SECURITY.md](SECURITY.md).
- Report bugs and request features at <https://github.com/matthewrstone/puppet-ai_bridge/issues>.

The legacy `.gitlab-ci.yml` runs an equivalent subset (Go checks, lint, rspec-puppet, YAML validation, Python unit tests) for GitLab mirrors.

## Repository layout

| Path | What |
|------|------|
| `manifests/`, `templates/`, `types/`, `files/` | Puppet module `souldo-ai_bridge` and its LiteLLM callbacks |
| `plans/`, `tasks/`, `examples/bolt/` | Bolt deployment plan, runtime task and sample project |
| `tools/pe-capture/` | Go tool that records exactly what PE sends (and can act as a minimal bridge itself) |
| `litellm/` | Standalone `docker-compose.yml` and reference `config.yaml` for testing without Puppet |
| `examples/` | Hiera examples for Claude, OpenAI and Ollama |

`tools/`, `litellm/`, `spec/` and `tests/` are not included in the Forge package.

## Capturing what PE really sends

Before trusting any config, run `pe-capture` for one console save and read `capture.jsonl`:

```bash
cd tools/pe-capture && go build .
./pe-capture -listen :4000 -cert server.crt -key server.key -log capture.jsonl
# point PE at https://<host>:4000/v1 with any API key, click Update API settings
jq . capture.jsonl
```

It answers `/v1/models` and `/v1/chat/completions` convincingly enough for the console's validation to pass, and logs headers (credentials redacted) and bodies. Add `-upstream https://api.openai.com -upstream-key $OPENAI_API_KEY -rewrite-model o4-mini=gpt-5-mini` and it acts as a zero-dependency bridge for the OpenAI-to-OpenAI case.

## Quick test commands

```bash
cd tools/pe-capture && go test -race -cover ./...                  # Go
bundle exec rspec spec/classes                                      # catalog tests (separate process from Bolt specs)
python3 -B -m unittest discover -s tests -p test_pe_usage.py        # pure Python (also test_personality.py, test_tool_call_compat.py)
bundle exec puppet strings generate --format markdown --out REFERENCE.md   # regenerate the parameter reference
```

Runtime callback tests (`tests/*runtime.py`) need the pinned LiteLLM image; see [Forge readiness](FORGE_READINESS.md).

The module is PDK-converted (PDK 4.0.1). Project-specific settings live in `.sync.yml` and `.rubocop_todo.yml`, so edit those and run `pdk convert --force` (or `pdk update`) instead of editing the generated `.gitignore`, `.pdkignore`, `Gemfile` or `.rubocop.yml` by hand.

```bash
pdk validate          # puppet-lint, metadata, syntax, YAML, RuboCop
pdk test unit         # catalog specs
pdk build --force     # builds pkg/souldo-ai_bridge-<version>.tar.gz
```

PDK 4's `Gemfile` pulls Puppet from the credentialed `rubygems-puppetcore.puppet.com` source. Either export a puppetcore token (`BUNDLE_RUBYGEMS___PUPPETCORE__PUPPET__COM=forge-key:<token>`) or use public RubyGems with `BUNDLE_GEMSOURCE__PUBLIC=true`; CI uses the latter, and `PUPPET_GEM_VERSION` still selects the Puppet 7/8 matrix. PDK itself ignores a global `gemsource.public` bundler setting, so the token is the only way to run `pdk validate` locally. On a Mac whose Command Line Tools SDK is newer than its linker, native gems fail to build; export `SDKROOT` pointing at Xcode's own SDK for that command. Bolt specs need `BOLT_TESTS=true BOLT_GEM_VERSION='= 4.0.0'`.
