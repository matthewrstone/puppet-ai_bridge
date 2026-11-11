<!-- generated-by: gsd-doc-writer -->
# puppet-ai_bridge

**Your infrastructure. Your choice of AI.**

`souldo-ai_bridge` is a Puppet module that deploys an OpenAI-compatible bridge (LiteLLM in a container) so Puppet Enterprise Infra Assist (the PE AI Agent) can be answered by the cloud or local model that fits your business: Claude, OpenAI, Ollama, or any OpenAI-compatible server.

![User asks PE Infra Assist, which connects through LiteLLM powered by ai_bridge to a choice of Claude, OpenAI, Gemini, Ollama, Grok, Amazon Bedrock and other providers.](docs/images/pe-llm-choice.png)

[Download the slide-ready graphic](docs/images/pe-llm-choice.png) ·
[Graphic notes](docs/images/README.md)

![License](https://img.shields.io/badge/license-Apache--2.0-blue)
![Version](https://img.shields.io/badge/module-0.1.3-informational)

## Installation

Add the module to your Puppetfile or install it from a checkout of
[this repository](https://github.com/matthewrstone/puppet-ai_bridge):

```bash
git clone https://github.com/matthewrstone/puppet-ai_bridge.git
```

The module has no Puppet module dependencies. This experimental community release declares Ubuntu 24.04 and Puppet `>= 7.0.0 < 9.0.0`. Catalog tests cover Puppet 7/8; live deployment evidence covers Ubuntu 24.04 with Docker. Puppet 9 has been exercised in a lab only. Other operating systems and the default Podman path need deployment validation; use Docker with `manage_package: false` and an existing runtime for the tested path. This module is not a Puppet Supported product.

Install from the Forge with `puppet module install souldo-ai_bridge`, or add `mod 'souldo-ai_bridge', '0.1.3'` to your Puppetfile once the release is published. The class remains `ai_bridge`.

PE 2026 acceptance testing remains incomplete. Field testing identified nested requests for `gpt-5.4` as well as `gpt-5.4-mini`; use the aliases and Ollama thinking setting below. Short completion probes passed with thinking disabled, but this is not a guarantee of complete PE tool-call and streaming compatibility. [Release validation](docs/FORGE_READINESS.md) records the evidence and remaining limits.

LiteLLM is downloaded separately as an upstream container. The module's Apache-2.0 license does not relicense LiteLLM, its enterprise components, or backend models. See [third-party notices](docs/THIRD_PARTY_NOTICES.md).

Prefer an agentless push? [Deploy with Bolt](docs/BOLT_DEPLOYMENT.md), with Docker already installed or installed by the plan.

## Quick start

1. Generate a master key. This becomes PE's "API key":
   ```bash
   openssl rand -hex 32
   ```
2. Get a TLS certificate for the bridge host (see [TLS certificates](#tls-certificates)).
3. Set Hiera data, encrypting secrets with eyaml:
   ```yaml
   ai_bridge::backend: anthropic
   ai_bridge::upstream_model: claude-sonnet-4-5
   ai_bridge::upstream_api_key: ENC[PKCS7,...]
   ai_bridge::master_key: ENC[PKCS7,...]
   ai_bridge::tls_cert: |
     -----BEGIN CERTIFICATE-----
     ...
   ai_bridge::tls_key: ENC[PKCS7,...]
   ```
4. Classify the bridge host with `include ai_bridge` and run Puppet.
5. In the PE console, open **Puppet AI Agent settings**:
   - AI service: **Open AI**
   - URL: `https://<bridge-fqdn>:4000/v1`
   - API key: the master key from step 1
   - Click **Update API settings**. No red banner means success.

Switch backends by changing three Hiera keys. See `examples/` for Claude (`claude.yaml`), OpenAI (`openai.yaml`), Ollama (`ollama.yaml`) and Bolt (`examples/bolt/`). The full walk-through is in the [User guide](docs/USER_GUIDE.md).

## TLS certificates

PE's console must trust the certificate the bridge presents. The module does not issue certificates; it takes `tls_cert` (PEM certificate or chain, `String`) and `tls_key` (PEM private key, `Sensitive[String]`) as inputs and writes them to `<install_dir>/tls/server.crt` and `server.key`. Choose one of these:

**1. The Puppet CA (recommended).** Every PE installation has one, and PE's own services already trust it. On the primary, issue a certificate for the bridge host's name, adding any extra DNS names you will use in the PE console URL:

```bash
puppetserver ca generate --certname ai-bridge.example.com \
  --subject-alt-names ai-bridge.example.com,ai-bridge
```

Copy the resulting certificate and private key (plus the Puppet CA certificate if you want to include the chain) into your Hiera data as `ai_bridge::tls_cert` and `ai_bridge::tls_key`. The hostname in the PE URL must match the certificate name or a subject alternative name.
<!-- VERIFY: exactly which JVM/truststore the PE console uses to validate the bridge certificate, and whether it trusts the Puppet CA by default, is PE internals and cannot be confirmed from this repository -->
<!-- VERIFY: the on-disk location where `puppetserver ca generate` leaves the certificate and key on the primary (docs/USER_GUIDE.md says /etc/puppetlabs/puppet/ssl/certs/ and private_keys/) is not confirmed by this repository's code -->

**2. A publicly trusted certificate** such as one from ACME/Let's Encrypt. This needs a public DNS name for the bridge host. Feed the issued chain and key to the module the same way.

**3. An external TLS-terminating proxy.** Set `manage_tls: false` so the bridge listens on plain HTTP, and put a proxy you already run in front of it. Use the proxy's HTTPS URL in PE. Keep the bridge's plain-HTTP port on a private network only.

If you happen to operate an internal CA, a certificate from it works too, provided PE trusts that CA.

Verify trust from the primary with `curl` (without `-k`) before saving in the console. If PE reports `PKIX path building failed`, see [Troubleshooting](docs/TROUBLESHOOTING.md).

## Backends

| `backend` | `upstream_model` example | Needs | Notes |
|-----------|--------------------------|-------|-------|
| `anthropic` | `claude-sonnet-4-5` | `upstream_api_key` | LiteLLM translates tool calls, system prompts, streaming |
| `openai` | `gpt-5-mini` | `upstream_api_key` | Pure rename; lowest format risk |
| `ollama` | `qwen3:32b` | `upstream_base_url` (`http://host:11434`) | Uses `ollama_chat/` so tool calling works. Pick a tool-capable model |
| `openai_compatible` | `Qwen/Qwen3-32B` | `upstream_base_url` (`http://host:8000/v1`), optional key | vLLM, LM Studio, llama.cpp, TGI, PAG |

## Parameters

| Parameter | Type | Default | Purpose |
|-----------|------|---------|---------|
| `master_key` | `Sensitive[String[1]]` | none (required) | Bearer token PE presents. Paste into PE's API key field |
| `backend` | `Ai_bridge::Backend` | `anthropic` | Provider |
| `upstream_model` | `String[1]` | `claude-sonnet-4-5` | Provider-side model name |
| `upstream_api_key` | `Optional[Sensitive[String[1]]]` | `undef` | Provider key (required for anthropic/openai) |
| `upstream_base_url` | `Optional[Ai_bridge::Url]` | `undef` | Provider URL (required for ollama/openai_compatible) |
| `exposed_model` | `String[1]` | `o4-mini` | Name PE asks for |
| `extra_aliases` | `Hash[String[1],String[1]]` | `{}` | More `{name => 'provider/model'}` entries |
| `ollama_think` | `Optional[Boolean]` | `undef` | Override thinking on Ollama models and aliases; unset keeps upstream defaults |
| `listen_port` | `Ai_bridge::Port` | `4000` | Listener port |
| `manage_tls` | `Boolean` | `true` | Terminate TLS in the bridge |
| `tls_cert` / `tls_key` | `Optional[String[1]]` / `Optional[Sensitive[String[1]]]` | `undef` | PEM contents (required when `manage_tls`) |
| `container_runtime` | `podman`/`docker` | `podman` | Podman runs rootless as the service user |
| `image` | `String[1]` | `ghcr.io/berriai/litellm:main-stable` | Pin a digest in prod |
| `install_dir` | `Ai_bridge::Absolutepath` | `/opt/ai_bridge` | Config/env/TLS location |
| `user` | `String[1]` | `ai_bridge` | System user that owns files (and runs the container with Podman) |
| `drop_params` | `Boolean` | `true` | Strip params the provider rejects (`reasoning_effort` etc.) |
| `request_timeout` | `Integer[1]` | `300` | Seconds; raise for slow local models |
| `debug` | `Boolean` | `false` | `LITELLM_LOG=DEBUG`. Logs prompts, troubleshooting only |
| `normalize_usage` | `Boolean` | `false` | Add zero defaults for missing token-usage detail fields (see below) |
| `personality_prompt` | `Optional[String[1]]` | `undef` | Response style text appended to chat system instructions |
| `manage_package` | `Boolean` | `true` | Install the container runtime package |
| `service_ensure` | `running`/`stopped` | `running` | Service state when `ensure` is `present` |
| `ensure` | `present`/`absent` | `present` | `absent` removes everything |

Validation fails at compile time if `upstream_api_key` is missing for anthropic/openai, `upstream_base_url` is missing for ollama/openai_compatible, or `tls_cert`/`tls_key` are missing while `manage_tls` is true.

## Response style through Hiera

```yaml
ai_bridge::personality_prompt: 'Talk like a pirate'
```

This is a model instruction, not an access-control mechanism. See [personality settings](docs/USER_GUIDE.md#response-style-through-hiera).

## PE 2026 compatibility

PE versions can request different model names. In the PE 2026 lab, requests used `gpt-5.4-mini` for chat and `gpt-5.4` inside the PuppetDB query tool. Configure both aliases while retaining the default `o4-mini`; a missing tool alias causes the query to fail even when chat itself works:

```yaml
ai_bridge::backend: ollama
ai_bridge::upstream_model: gemma4:12b
ai_bridge::upstream_base_url: http://ollama.example.net:11434
ai_bridge::ollama_think: false
ai_bridge::extra_aliases:
  gpt-5.4-mini: ollama_chat/gemma4:12b
  gpt-5.4: ollama_chat/gemma4:12b
ai_bridge::normalize_usage: true
```

`normalize_usage` defaults to `false`. Enable it when PE throws a null-pointer exception in `ConversationService.finalizeAssistantMessage` for missing token usage detail objects. It adds missing/null prompt and completion detail fields with zero defaults, preserving aggregate token counts, supplied detail counts, and response content. These defaults are compatibility values, not measured cache/audio/reasoning statistics. Responses without usage remain unchanged. The callback and its helpers are mounted read-only and loaded through `/app`.

With Docker, bind-mounted configuration/TLS files are root-owned so the container can read them with all Linux capabilities dropped. Secrets remain mode `0600`; Podman uses the configured service account as before.

Lab evidence: Ubuntu 24.04, Puppet 9.1.1, LiteLLM 1.106.6 and Gemma 4 12B. The PE API recorded response finalization after enabling this workaround. Visible clearing of the console's "Thinking" indicator remains unverified; previously stuck conversations may need a fresh chat.

## Capturing what PE really sends

Before trusting any config, run `pe-capture` for one console save and read `capture.jsonl`:

```bash
cd tools/pe-capture && go build .
./pe-capture -listen :4000 -cert server.crt -key server.key -log capture.jsonl
# point PE at https://<host>:4000/v1 with any API key, click Update API settings
jq . capture.jsonl
```

It answers `/v1/models` and `/v1/chat/completions` convincingly enough for the console's validation to pass, and logs headers (credentials redacted) and bodies. Add `-upstream https://api.openai.com -upstream-key $OPENAI_API_KEY -rewrite-model o4-mini=gpt-5-mini` and it acts as a zero-dependency bridge for the OpenAI-to-OpenAI case.

## Repository layout

| Path | What |
|------|------|
| `manifests/`, `templates/`, `types/`, `files/` | Puppet module `souldo-ai_bridge` and its LiteLLM callbacks |
| `plans/`, `tasks/`, `examples/bolt/` | Bolt deployment plan, runtime task and sample project |
| `tools/pe-capture/` | Go tool that records exactly what PE sends (and can act as a minimal bridge itself) |
| `litellm/` | Standalone `docker-compose.yml` and reference `config.yaml` for testing without Puppet |
| `examples/` | Hiera examples for Claude, OpenAI and Ollama |

## Documentation

- [ELI10](docs/ELI10.md): the plain-language explanation
- [User guide](docs/USER_GUIDE.md): step-by-step setup and day-2 operations
- [Bolt deployment](docs/BOLT_DEPLOYMENT.md): agentless deployment
- [Troubleshooting](docs/TROUBLESHOOTING.md): symptoms and fixes
- [Security](docs/SECURITY.md): threat model and hardening
- [Human UAT](docs/UAT_HUMAN_TESTING.md): tests that need a person and a real PE
- [Design](docs/DESIGN.md): why it is built this way
- [Forge readiness](docs/FORGE_READINESS.md): release gates and test commands

## Testing

```bash
cd tools/pe-capture && go test -race -cover ./...     # Go
pdk validate && pdk test unit                          # Puppet (or: bundle exec rake spec)
python3 -m unittest discover -s tests -p test_pe_usage.py   # pure Python
```

Runtime callback tests require the pinned LiteLLM environment; see [Forge readiness](docs/FORGE_READINESS.md) for commands and remaining release gates.

## Status

Built test-first and the automated tests are green. Final acceptance against a real PE console is tracked in [Human UAT](docs/UAT_HUMAN_TESTING.md).

## License

Apache-2.0. See [LICENSE](LICENSE).
