# Testing — ai_bridge

This module is tested in four layers: Puppet catalogue tests (rspec-puppet), a Bolt plan test, Python unit and callback-runtime tests, and Go tests for the `pe-capture` tool. A final layer of human tests covers what automation cannot: a real PE console, real provider keys, and certificate trust. Those are in [UAT_HUMAN_TESTING.md](UAT_HUMAN_TESTING.md).

## Test framework and setup

| Layer | Framework | Location | What it covers |
|-------|-----------|----------|----------------|
| Static checks | `puppet parser validate`, `puppet-lint`, `metadata-json-lint` | `manifests/`, `types/`, `plans/`, `metadata.json` | Syntax, style, and Forge metadata |
| Catalogue tests | rspec-puppet via `puppetlabs_spec_helper` | `spec/classes/init_spec.rb` | Compiled catalogue for the `ai_bridge` class |
| Bolt plan test | RSpec with `bolt_spec/plans` | `tests/bolt_deploy_spec.rb` | The `ai_bridge::deploy` plan |
| Python unit tests | `unittest` (standard library) | `tests/test_*.py` | Helper modules in `files/`, the Docker runtime task, and the Bolt parameter script |
| Callback runtime tests | `unittest` inside the pinned LiteLLM image | `tests/test_pe_compat_runtime.py`, `tests/test_personality_runtime.py` | The callbacks against LiteLLM's real classes |
| Go tests | `go test` | `tools/pe-capture/proxy_test.go` | The `pe-capture` request-capture proxy |
| Human UAT | Written procedure | `docs/UAT_HUMAN_TESTING.md` | PE console, provider keys, certificate trust |

### Prerequisites

- Ruby 3.2 (CI uses 3.2) and Bundler for the Puppet and Bolt tests.
- Python 3 (CI uses 3.12) for the helper tests. No third-party packages are needed for the unit tests.
- Go 1.24 (see `tools/pe-capture/go.mod`) for the `pe-capture` tests.
- Docker, only for the callback runtime tests.

### Setup

```bash
bundle install
bundle exec rake spec_prep
```

`rake spec_prep` reads `.fixtures.yml` and symlinks this repository into `spec/fixtures/modules/ai_bridge`, so the tests load the module from your working tree. `spec/spec_helper.rb` points rspec-puppet at that module path and at `spec/fixtures/hiera.yaml`, and turns on `strict_variables`.

The Gemfile selects the Puppet version with `PUPPET_GEM_VERSION` (default `~> 8.0`) and only installs Bolt (`= 4.0.0`) when `BOLT_TESTS=true`.

## Running tests

### Static checks

```bash
bundle exec puppet parser validate manifests/*.pp types/*.pp
bundle exec puppet-lint --relative --fail-on-warnings manifests types plans
bundle exec metadata-json-lint metadata.json
```

### Catalogue tests (rspec-puppet)

```bash
bundle exec rake spec_prep
bundle exec rspec spec/classes/init_spec.rb
```

Run one scenario by name or line number:

```bash
bundle exec rspec spec/classes/init_spec.rb -e 'docker runtime'
bundle exec rspec spec/classes/init_spec.rb:222
```

To check against the older supported Puppet release, which CI also does:

```bash
PUPPET_GEM_VERSION='~> 7.0' bundle update puppet
PUPPET_GEM_VERSION='~> 7.0' bundle exec rspec spec/classes/init_spec.rb
```

### Bolt plan test

```bash
BOLT_TESTS=true bundle install
BOLT_TESTS=true bundle exec rake spec_prep
BOLT_TESTS=true bundle exec rspec tests/bolt_deploy_spec.rb
```

The test stubs the `ai_bridge::docker_runtime` task and `apply`, so it does not touch any real host.

### Python unit tests

Run from the repository root. These are the same four commands CI runs:

```bash
python3 -B -m unittest discover -s tests -p test_pe_usage.py
python3 -B -m unittest discover -s tests -p test_personality.py
python3 -B -m unittest discover -s tests -p test_docker_runtime.py
python3 -B -m unittest discover -s tests -p test_bolt_parameters.py
```

Run a single file directly:

```bash
python3 -B tests/test_personality.py
```

### Callback runtime tests (Docker)

`test_pe_compat_runtime.py` and `test_personality_runtime.py` import `litellm`, so they only run inside the LiteLLM image. CI pins the image by digest; this is the CI command:

```bash
docker run --rm --entrypoint python \
  -v "$PWD:/workspace:ro" \
  ghcr.io/berriai/litellm@sha256:37e2dafb088a7723beb998590682957386dfc83ffea1848486f8e0e5cfac0b06 \
  -B -m unittest discover -s /workspace/tests -p '*runtime.py'
```

Outside that image these two files fail on `import litellm`. That is expected, and it is why the CI Python step lists the non-runtime files by name rather than discovering everything.

### Go tests (pe-capture)

```bash
cd tools/pe-capture
test -z "$(gofmt -l .)"
go vet ./...
go test -race -cover ./...
```

### Everything at once

There is no single wrapper script. To approximate CI locally, run the sections above in order.

## What the tests assert

- **`spec/classes/init_spec.rb`** compiles the class with Rocky 9 facts and checks the generated catalogue: backends (`anthropic`, `openai`, `ollama`, `openai_compatible`), extra model aliases, secrets staying out of `config.yaml`, file modes (`0600` for the env file and TLS key), the systemd unit contents, podman vs Docker runtime, the PE usage-compatibility callback, the optional personality prompt, `manage_tls => false`, `ensure => absent`, and the validation errors for bad input (missing key, missing base URL, missing cert, unknown backend, non-`Sensitive` master key).
- **`tests/bolt_deploy_spec.rb`** checks that the plan runs the runtime task with `install_docker` false by default, passes explicit install consent through, rejects a missing `config.master_key` before any task runs, and stops before apply if the runtime check fails.
- **`tests/test_pe_usage.py`** checks `files/pe_usage.py`: zero-filled `cached_tokens` and `reasoning_tokens` defaults, preservation of real counts, no input mutation, and rejection of malformed shapes.
- **`tests/test_personality.py`** checks `files/personality.py`: the style is appended to the existing system message without altering the PE instructions, tools, or other messages, and repeated application is idempotent.
- **`tests/test_docker_runtime.py`** checks `tasks/docker_runtime.py` with mocked subprocesses: an existing Docker is only checked, installation needs explicit consent, only Ubuntu and Debian are supported, and a broken existing daemon is not reconfigured.
- **`tests/test_bolt_parameters.py`** checks `examples/bolt/create_params.py`: both parameter files are written with mode `0600` and secrets are never printed.
- **`tests/test_*_runtime.py`** run the real callbacks against LiteLLM's `ModelResponse`, `ModelResponseStream`, and `CustomLogger` classes, including streaming and the interaction between the personality and usage callbacks.
- **`tools/pe-capture/proxy_test.go`** checks the capture proxy: `/v1/models`, canned and streamed chat completions, redaction of the `Authorization` header in the log, forwarding with model rewrite, bearer-key enforcement, `/healthz`, and a JSON 404 for unknown paths.

## Writing new tests

- **Puppet scenarios:** add a `context` to `spec/classes/init_spec.rb`. Reuse the `facts` and `base_params` helpers. Secret parameters (`master_key`, `upstream_api_key`, `tls_key`) must be wrapped with `sensitive(...)`. To assert on rendered files, read `catalogue.resource('file', '<path>')[:content]`. For error paths, use `is_expected.to compile.and_raise_error(/regex/)`.
- **Bolt plan scenarios:** add an `it` block to `tests/bolt_deploy_spec.rb`. Declare tasks with `expect_task(...)` and call `allow_apply_prep` and `allow_apply` so nothing runs on a real target.
- **Python helpers:** name the file `tests/test_<thing>.py`, add `sys.path.insert(0, <repo>/files)` as the existing tests do, and use `unittest`. Add a matching `python3 -B -m unittest discover -s tests -p test_<thing>.py` line to the `helpers` job in `.github/workflows/ci.yml` and to the `python-unit` job in `.gitlab-ci.yml`, because CI does not auto-discover them.
- **Tests that need LiteLLM classes:** end the filename in `runtime.py` (for example `test_<thing>_runtime.py`). The CI pattern `*runtime.py` runs them in the pinned image automatically. Do not name a LiteLLM-dependent test `test_*.py` without the `runtime` suffix, or the plain Python job will not be able to import it.
- **Go:** add `Test...` functions to `tools/pe-capture/proxy_test.go`, formatted with `gofmt`.
- Shared fixture: `tests/fixtures/personality_backend.py`. Hiera test data lives in `spec/fixtures/data/common.yaml` with `spec/fixtures/hiera.yaml`.

## Coverage requirements

| Type | Threshold |
|------|-----------|
| Puppet (rspec-puppet) | No coverage threshold configured |
| Python | No coverage threshold configured |
| Go | `-cover` is reported in CI, but no minimum is enforced |

## CI integration

GitHub Actions: `.github/workflows/ci.yml` (workflow name `Module CI`), triggered on every push, every pull request, and manually (`workflow_dispatch`).

| Job | What it runs |
|-----|--------------|
| `puppet` | Matrix of Puppet `~> 7.0` and `~> 8.0` on Ruby 3.2: parser validate, `puppet-lint --fail-on-warnings`, `metadata-json-lint`, `rake spec_prep`, `rspec spec/classes/init_spec.rb` |
| `bolt` | `BOLT_TESTS=true`, Puppet `~> 8.0`: `rspec tests/bolt_deploy_spec.rb` |
| `helpers` | The four Python `unittest` commands on Python 3.12, then `gofmt`, `go vet`, and `go test -race -cover` for `tools/pe-capture` |
| `package` | Builds the module tarball with `puppet-modulebuilder` 2.1.0 and uploads it as the `forge-candidate` artifact |
| `callback-runtime` | Runs `tests/*runtime.py` inside the pinned LiteLLM image |

`.gitlab-ci.yml` runs a subset in a single `test` stage: `go-test`, `puppet-lint`, `rspec-puppet`, `yaml-validate` (parses the YAML in `litellm/`, `examples/`, and `data/common.yaml`), and `python-unit`. It notes that the real callback tests run separately in the pinned LiteLLM image, and does not run them itself.

## What automation does not cover

The automated suite verifies what the module generates, not how a live PE and a live provider behave. These need a person:

- **Certificate trust.** PE's AI Agent connects to the bridge over HTTPS, and the PE console's JVM must trust the bridge's certificate. The recommended path is a certificate issued by the Puppet CA, which every PE component already trusts. The tests only check that the certificate and key are written with the right modes. Whether the PE primary actually validates the certificate (for example `curl` from the primary without `-k`, and a successful save in the console) is verified in UAT Test 2. A failure shows up as `PKIX path building failed` in the console; see [TROUBLESHOOTING.md](TROUBLESHOOTING.md).
- **What PE actually sends.** UAT Test 1 uses `pe-capture` to record the real request shape.
- **Real provider calls.** Claude, OpenAI, and Ollama round trips, backend switching by Hiera alone, failure modes, and removal.
- **Idempotency on a real node.** A second `puppet agent -t` with zero changes.

Follow [UAT_HUMAN_TESTING.md](UAT_HUMAN_TESTING.md) for these. It has setup, steps, expected results, and a sign-off table.

## Related docs

- [BOLT_DEPLOYMENT.md](BOLT_DEPLOYMENT.md) for the deploy plan these tests stub
- [CONFIGURATION.md](CONFIGURATION.md) for the parameters exercised in the catalogue tests
- [ARCHITECTURE.md](ARCHITECTURE.md) for how the components fit together
- [TROUBLESHOOTING.md](TROUBLESHOOTING.md) for failures seen at runtime
