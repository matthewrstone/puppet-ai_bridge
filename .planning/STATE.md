# State

**Last updated:** 2026-10-29
**Current phase:** 5 — Field test (hand-off to Matthew)

## Where things stand

- Phases 1–4 complete in this repo. All automated tests green (`go test`, `rspec-puppet`, `puppet-lint`).
- Nothing has been pointed at a real PE yet. Phase 5 starts with running `pe-capture`
  for one console save and reading `capture.jsonl`.

## Open questions (resolved by the capture log)

1. Does PE validate with `GET /v1/models`, a chat completion, or both?
2. Does PE send `max_completion_tokens`, `reasoning_effort`, `temperature`, `response_format`?
3. Does PE use tool calling? Streaming?
4. Does PE accept an `http://` URL or require TLS? (Try https first; it's what we want anyway.)

## Next actions

1. Deploy `pe-capture` (see docs/UAT_HUMAN_TESTING.md, Test 1).
2. Point PE at it, click "Update API settings", inspect the log.
3. Adjust `ai_bridge::extra_aliases` / `drop_params` in Hiera if needed.
4. Switch PE URL to the LiteLLM bridge, run UAT Tests 2–6.

## Blockers

- None in code. Needs a homelab host with Podman and a cert from Step CA.
