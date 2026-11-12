# Backlog

Open work as of 2026-11-12. Nothing here is committed to a release until the maintainer approves it.

## Candidate scope for 0.1.6

- Raise the Puppet upper bound in `metadata.json` to `< 10.0.0` (PE 2026 ships Puppet 9), with a
  Puppet 9 CI job added first.
- Fuller Puppet Strings header for the `ai_bridge::deploy` plan (`@example`, `@return`, required
  `config` keys), then regenerate `REFERENCE.md`.
- Ship the cleaned packaged docs (internal generator comments removed after 0.1.5 was built).
- Add a PE 2026 + Ollama example, and troubleshooting entries for invented PuppetDB answers
  (`tool_call_compat`), HTTP 400 on `gpt-5.4`, and empty replies or timeouts (`ollama_think`).
- Update the pass criteria in `docs/UAT_HUMAN_TESTING.md` to match the field-test findings.
- CI check that fails when `REFERENCE.md` is out of date.
- Keep an archive's own checksum out of packaged files (see `releases/0.1.5.md`).

## Phase 5 acceptance still open

- PE 2025.x with the current build.
- Provider switching (Anthropic, OpenAI, OpenAI-compatible) from Hiera alone.
- Failure injection: upstream down should produce a clean error in PE.
- Removal (`ensure => absent`).
- Real capture logging with `tools/pe-capture` against a live PE.
- Podman runtime, and operating systems other than Ubuntu 24.04.
- Comparison of a tool-tuned local model against Gemma.
- Re-converge the lab on the published 0.1.5 package and repeat the node-count test.

## Unexplained observations

- The Forge lists no plans for 0.1.3 or 0.1.5, although `ai_bridge::deploy` is in the package and
  in `REFERENCE.md`.
- One independent PuppetDB node count returned 17 hours before the same query returned 18.

## Documentation

- Seven claims about PE internals are unconfirmed: `DOC-VERIFY-ITEMS.md`.
- The documentation generator re-adds internal marker comments on regeneration; they need
  stripping before a package is built.
- A whole-project code review has not been done; the last review covered two commits.

## Phase 6 (hardening, not started)

Step CA auto-renewal, metrics, a governed gateway as the upstream, high availability.
