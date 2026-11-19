---
quick_id: 261119-gt7
threats_total: 4
threats_open: 0
date: 2026-11-19
---

# Security review: Podman acceptance test and CI job

| ID | Threat | Disposition | Evidence |
|----|--------|-------------|----------|
| T1 | Workflow injection from untrusted event data | Mitigated | The job uses no `github.event.*` or other `${{ }}` values in `run:`. Only fixed strings and runner env vars appear |
| T2 | Script run by accident on a real host | Mitigated | It refuses without `CI=true` or `AI_BRIDGE_ACCEPTANCE=1` and requires root. The header and TESTING.md mark it destructive |
| T3 | Secrets leak into CI logs | Mitigated | The master key is random per run and only used on localhost. The TLS key is a throwaway self-signed key in a temp dir, deleted on exit. No repository secrets are used |
| T4 | Unpinned image pulled in CI | Mitigated | The default `IMAGE` is the digest-pinned LiteLLM image that the `callback-runtime` job already uses |

Open threats: 0.
