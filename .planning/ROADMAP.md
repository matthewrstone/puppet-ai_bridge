# Roadmap

| Phase | Name | Goal | Status |
|-------|------|------|--------|
| 1 | Capture | Know exactly what PE sends (`tools/pe-capture`) | ✅ built, awaiting real PE capture |
| 2 | LiteLLM bridge | Standalone compose + config, all four backends | ✅ built |
| 3 | Puppet module | `souldo-ai_bridge` deploys the bridge from Hiera | ✅ built, rspec green |
| 4 | Docs & UAT | README, ELI10, user guide, human UAT, security | ✅ built |
| 5 | Field test | Point the real PE at it; tune `drop_params` / aliases from the capture log | ⏳ Matthew |
| 6 | Hardening | Step CA auto-renew, metrics, PAG as upstream, HA | 📋 backlog |

## Phase details

See `phases/0N-*.md` for each phase's plan, tasks and acceptance criteria.

## Decisions log

- **2026-10-29** Backend is a Hiera switch, not separate modules. One class, one container.
- **2026-10-29** Podman by default; the systemd unit is runtime-agnostic (`podman run` / `docker run`).
- **2026-10-29** Capture proxy is Go, not Python — single static binary, trivially containerised, matches Matthew's Go direction (Boltinator, pe-mcp).
- **2026-10-29** TLS cert/key are module inputs. Step CA issuance is a documented follow-on, not baked in, so the module stays PKI-agnostic.
- **2026-10-29** Ollama added as a first-class backend (Matthew asked mid-build). Uses LiteLLM's `ollama_chat/` prefix so tool calling works.
