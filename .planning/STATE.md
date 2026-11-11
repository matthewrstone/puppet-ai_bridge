# State

**Last updated:** 2026-11-11
**Current phase:** 5 — Field test (paused after Forge release)
**Status:** paused
**Resume file:** .planning/.continue-here.md

## Where things stand

- Forge release 0.1.3 published as `souldo/ai_bridge` at the user's request after
  `souldonetworks` publishing authorization failed. Public API metadata and the
  downloaded archive's SHA-256 were verified. See `RELEASE-0.1.3.md`.
- Phases 1–4 complete in this repo. All automated tests green (`go test`, `rspec-puppet`, `puppet-lint`).
- Phase 5 field testing has started on PE 2026.0.0 (`pe-advanced-01`) and the
  existing Ollama bridge (`ai-bridge-01`). End-to-end acceptance has not passed.
- PE's PuppetDB tool additionally requests `gpt-5.4`; the deployed aliases only
  include `o4-mini` and `gpt-5.4-mini`. A temporary alias removed that HTTP 400.
- Gemma probes returned complete replies with `think=false`; full PE validation
  remains pending. Puppet reverted temporary bridge config changes and restarted
  the bridge during the final retest. See `FIELD-TEST-2026-11-11.md` for evidence.

## Open questions (resolved by the capture log)

1. Does PE validate with `GET /v1/models`, a chat completion, or both?
2. Does PE send `max_completion_tokens`, `reasoning_effort`, `temperature`, `response_format`?
3. Does PE use tool calling? Streaming?
4. Does PE accept an `http://` URL or require TLS? (Try https first; it's what we want anyway.)

## Next actions

1. Add `gpt-5.4` to the bridge node's authoritative Hiera aliases.
2. Deploy the released module with `ollama_think: false` for this Gemma deployment;
   the parameter is implemented and shipped, but not yet deployed to the lab.
3. Apply Puppet, wait for API readiness, check idempotence, then retry a fresh PE
   inventory question. Independent PuppetDB count during testing was 17.
4. Complete remaining UAT, including real capture logging and provider switching.

## Blockers

- Durable model configuration is required before continuing acceptance testing;
  scheduled Puppet runs revert temporary fixes and interrupt active requests.
