---
gsd_state_version: "1.0"
current_phase: 5 — Field test (PE 2026 inventory path passed; other UAT open)
status: unknown
last_updated: "2026-11-19T21:03:30.480Z"
last_activity: 2026-11-19
last_activity_desc: "Completed quick task 261119-g4w: rootless Podman cgroupfs fix"
state_head: 4337cf44c52c28bac1f18ba5f24258aa2b100542
progress:
  total_phases: 0
  completed_phases: 0
  total_plans: 0
  completed_plans: 0
---

# State

**Last updated:** 2026-11-19
**Last activity:** 2026-11-19 - Completed quick task 261119-kwx: Podman containers.conf for the service user (PR #2)
**Current release:** 0.1.5 on the Puppet Forge as `souldo/ai_bridge` (see `releases/0.1.5.md`)
**Current phase:** 5 — Field test (PE 2026 inventory path passed; other UAT open)

## Where things stand

- Phases 1–4 are complete: capture tool, LiteLLM reference config, Puppet module, docs.
- Two versions are published: 0.1.3 and 0.1.5. 0.1.4 was a pre-release label and was never
  published. Published versions are immutable; any content change needs a new version.
- Phase 5 acceptance passed for one path only: PE 2026.0.0 on Ubuntu 24.04 with Docker and
  Gemma 4 12B on Ollama answered the managed-node-count question correctly, matching an
  independent PuppetDB query. This needs `tool_call_compat: true` and `ollama_think: false`
  for that model. Evidence: `field-tests/2026-11-11.md`.
- The test lab runs the same code as 0.1.5 but installed under the 0.1.4 label. Re-converging it
  on the published 0.1.5 package is pending.

## What the field test established

- PE 2025.x requests the model `o4-mini`. PE 2026 requests `gpt-5.4-mini` for chat and
  `gpt-5.4` for its nested PuppetDB tool call. PE uses both streaming and tool calling.
- PE's nested PuppetDB request carries a tool and a strict JSON-schema response format. A local
  model given both may fill the schema directly and never call the tool, inventing the answer.
- Puppet owns the generated bridge config. Hand edits are reverted on the next agent run and
  restart the bridge mid-request, so every fix goes through the module and Hiera.
- An HTTP 200 or progress text in the PE console does not prove a correct answer. Check the
  final answer against an independent PuppetDB query and the PE logs.

### Quick Tasks Completed

| # | Description | Date | Commit | Directory |
|---|-------------|------|--------|-----------|
| 261119-g4w | Rootless Podman: run unit with cgroupfs cgroup manager and file events backend | 2026-11-19 | 2d70085 | [261119-g4w-fix-rootless-podman-systemd-unit-cgroupf](./quick/261119-g4w-fix-rootless-podman-systemd-unit-cgroupf/) |
| 261119-gt7 | Automate rootless Podman deploy checks (podman-systemd CI job) | 2026-11-19 | ed6813c | [261119-gt7-automate-rootless-podman-deploy-tests-in](./quick/261119-gt7-automate-rootless-podman-deploy-tests-in/) |
| 261119-kwx | Podman containers.conf (cgroupfs, file events) for the service user | 2026-11-19 | 4337cf4 | [261119-kwx-podman-containers-conf-for-service-user](./quick/261119-kwx-podman-containers-conf-for-service-user/) |

## Next

Open work is listed in `BACKLOG.md`. Nothing is published, tagged or pushed without the
maintainer's approval.
