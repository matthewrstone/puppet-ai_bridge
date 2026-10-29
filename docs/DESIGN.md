# Design — ai_bridge

## Problem statement

PE's console backend builds OpenAI chat-completion requests with a hard-coded `model: "o4-mini"`. The only operator-controllable inputs are the base URL and the bearer token. OpenAI retired `o4-mini`, so the console's save-time validation gets a 404 and refuses the settings. Until PE makes the model name configurable, nothing in the console can fix this.

## Approach

Exploit the configurable URL. Stand up an OpenAI-API-shaped service that accepts `o4-mini` and resolves it to a real model. Because the OpenAI chat-completions format is a de facto standard, LiteLLM can translate it to Anthropic's Messages API, Ollama's `/api/chat`, or pass it through to any OpenAI-compatible server.

```
┌──────────────┐  https://bridge:4000/v1          ┌───────────────────────┐
│ PE console / │  Authorization: Bearer <master>  │  ai_bridge (LiteLLM)  │
│ AI Agent     │ ───────────────────────────────▶ │  model_list:          │
│ model=o4-mini│ ◀─────────────────────────────── │   o4-mini → provider/x│
└──────────────┘  OpenAI-shaped response           └───────────┬───────────┘
                                                               │ provider key lives here
                       ┌───────────────────┬───────────────────┼─────────────────┐
                       ▼                   ▼                   ▼                 ▼
                 Anthropic API        OpenAI API          Ollama /api/chat   vLLM / LM Studio /
                 (translated)         (renamed)           (translated)       llama.cpp / PAG (/v1)
```

## Components

### pe-capture (Go)
A ~300-line `net/http` server. Modes:
- **Canned**: answers `/v1/models`, `/v1/models/{id}`, `/v1/chat/completions` (incl. SSE streaming) with valid shapes so the PE console's validation passes, logging every request as JSONL.
- **Forward**: `-upstream` relays after logging; `-rewrite-model` rewrites the `model` field; `-upstream-key` swaps the bearer. This makes it a minimal bridge for the OpenAI→OpenAI case with zero dependencies.
- `-require-key` for bearer auth, `-cert/-key` for TLS.

Why Go: single static binary, scratch container, no runtime on the box, matches the rest of Matthew's tooling.

### LiteLLM (container)
Does the heavy lifting: provider translation, tool-call mapping, streaming, `drop_params`. Run with `--config`, no DB, no UI. Pinned image recommended.

### Puppet module
Three private classes under one public class:

| Class | Resources |
|-------|-----------|
| `ai_bridge::install` | group, user (system, nologin), runtime package, dirs, sub-UID exec (podman) |
| `ai_bridge::config` | `ai_bridge.env` (Sensitive, 0600), `config.yaml` (0640, no secrets), `tls/server.{crt,key}` |
| `ai_bridge::service` | systemd unit (EPP), daemon-reload exec, service |

Ordering: install → config ~> service. `ensure: absent` reverses it: stop service → remove files.

Compile-time validation (`fail()`) for the backend/key/url/TLS combinations that would otherwise produce a container that starts and immediately 500s.

No dependency on `puppetlabs-stdlib` or `puppetlabs-docker`: three tiny local type aliases replace the stdlib ones and the unit file wraps `podman run`/`docker run` directly. This keeps the module droppable into any control repo, including customer ones.

### Data flow of a secret
Hiera (eyaml) → `Sensitive[String]` param → `.unwrap` inside the EPP call → `Sensitive($env_content)` file content → `/opt/ai_bridge/ai_bridge.env` (0600) → `--env-file` → process env of the container → LiteLLM reads `os.environ/NAME`. Never in `config.yaml`, never in a Puppet diff, never on the command line (`ps` can't see it).

## Design decisions

| Decision | Alternatives considered | Why |
|----------|-------------------------|-----|
| LiteLLM rather than hand-rolled translation | custom Go bridge with Anthropic translation | Tool-call and streaming translation is fiddly and changes with provider APIs; LiteLLM is maintained. The Go tool covers the rename-only case for those who want zero dependencies |
| One class with a `backend` switch | one subclass per provider | Switching provider should be a data change, not a code/classification change. PE doesn't care |
| Podman rootless by default | Docker | Smaller blast radius; Docker remains for hosts that already have it |
| TLS in the bridge | Nginx/Caddy in front | Fewer moving parts; LiteLLM supports `--ssl_*` natively. A fronting proxy is trivially added later |
| Cert/key as inputs | ACME/Step CA automation in-module | PKI-agnostic; Step CA renewal is a one-liner in a profile |
| `drop_params: true` by default | strict | PE treats o4-mini as a reasoning model; strict mode would 400 on `reasoning_effort` against non-reasoning backends |

## Known unknowns (resolved by Test 1 in UAT)

- Exact validation call PE makes on save.
- Whether PE sends `tools`, `response_format`, `stream`.
- Whether PE accepts plain `http://`.

## Future

- **PAG as upstream**: set `backend: openai_compatible`, `upstream_base_url` = PAG's OpenAI endpoint → policy, audit and model routing move into the gateway and the bridge becomes a pure shim. Eventually PE could point straight at PAG once PAG exposes an `o4-mini` alias itself.
- Metrics: LiteLLM exposes `/metrics` (Prometheus) if enabled; wire into Grafana.
- HA: two bridge hosts behind a VIP; the bridge is stateless so this is purely a classification change.
- Product fix: make the model name configurable in PE. This repo is the stopgap and the evidence (`capture.jsonl`) for that ticket.
