# ai_bridge — OpenAI-compatible model bridge for Puppet Enterprise AI Agent

## What this is

Puppet Enterprise's AI Agent hard-codes the OpenAI model name `o4-mini`. OpenAI has
deprecated that model, so the console refuses to save AI settings
(`404: The model o4-mini has been deprecated`). The only configurable knobs in the
console are the **URL** and the **API key**.

`ai_bridge` is a small, Puppet-managed sidecar that sits between PE and any real model
provider. It accepts requests for `o4-mini` (or any alias you choose) and routes them to:

- **Anthropic** (Claude) — translated by LiteLLM
- **OpenAI** — a current model such as `gpt-5-mini`, pure rename
- **Ollama** — a local model on a homelab host
- **Any OpenAI-compatible server** — vLLM, LM Studio, llama.cpp, TGI, PAG, …

PE only ever sees a standard OpenAI API, so no PE code is touched.

## Why

- Unblocks every PE customer hitting the deprecation today, without waiting for a release.
- Lets Matthew run the PE AI Agent against Claude or local models in the homelab.
- Doubles as a demo asset: "PE AI Agent on your own models, air-gapped."
- Feeds the longer-term PAG story: PE → gateway → governed models.

## Scope

**In:**
1. `pe-capture` — tiny Go logging proxy that records exactly what PE sends, and answers
   well enough that the console's "Update API settings" validation passes.
2. LiteLLM proxy config + compose file for fast standalone testing.
3. Puppet module `souldo-ai_bridge` that deploys LiteLLM as a container under systemd,
   templates its config from Hiera, manages secrets, TLS and the service.
4. Exhaustive docs: README, ELI10, user guide, human UAT guide, security notes, design.

**Out (for now):**
- Modifying PE itself or filing the product bug (Matthew does that internally).
- A high-availability / multi-replica deployment.
- Automatic cert issuance from Step CA (documented, cert/key are inputs).

## Constraints

- TDD: tests written before implementation (Go `testing`, rspec-puppet).
- Security: secrets only via `Sensitive`, 0600 files, non-root container, TLS on the
  listener, master key required, no request bodies in logs unless explicitly enabled.
- Container runtime: Podman by default (rootless-friendly), Docker supported.
- Target OS: EL9 / Ubuntu 22.04+ homelab host, separate from the PE primary.

## Success criteria

1. PE console saves AI settings with URL = `https://ai-bridge.<domain>:4000/v1` and the
   bridge master key, no error banner.
2. PE AI Agent features function end-to-end against Claude, OpenAI and Ollama backends,
   switched purely by Hiera data.
3. `rspec-puppet`, `puppet-lint`, and `go test ./...` all pass in CI.
4. A human can follow `docs/UAT_HUMAN_TESTING.md` without needing the author.
