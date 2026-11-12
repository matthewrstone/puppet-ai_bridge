# Roadmap

| Phase | Name | Goal | Status |
|-------|------|------|--------|
| 1 | Capture | Know exactly what PE sends (`tools/pe-capture`) | ✅ built; real PE capture run still open |
| 2 | LiteLLM bridge | Standalone compose + config, all four backends | ✅ built |
| 3 | Puppet module | `souldo-ai_bridge` deploys the bridge from Hiera | ✅ built, rspec green |
| 4 | Docs & UAT | README, ELI10, user guide, human UAT, security | ✅ built |
| 5 | Field test | Point the real PE at it; tune `drop_params` / aliases from the capture log | ⏳ partial: PE 2026 inventory path passed; rest open (see `BACKLOG.md`) |
| 6 | Hardening | Step CA auto-renew, metrics, PAG as upstream, HA | 📋 backlog |

## Phase details

See `phases/0N-*.md` for the plans of phases 1–4. Phase 5 evidence is in `field-tests/`; releases are in `releases/`.

## Decisions log

- **2026-10-29** Backend is a Hiera switch, not separate modules. One class, one container.
- **2026-10-29** Podman by default; the systemd unit is runtime-agnostic (`podman run` / `docker run`).
- **2026-10-29** Capture proxy is Go, not Python — single static binary, trivially containerised, matches the maintainer's other Go tooling.
- **2026-10-29** TLS cert/key are module inputs. Step CA issuance is a documented follow-on, not baked in, so the module stays PKI-agnostic.
- **2026-10-29** Ollama added as a first-class backend (requested mid-build). Uses LiteLLM's `ollama_chat/` prefix so tool calling works.
- **2026-11-11** Published under the `souldo` Forge namespace (0.1.3) after the `souldonetworks` namespace could not be authorized. See `releases/0.1.3.md`.
- **2026-11-11** PE 2026 model names (`gpt-5.4-mini`, `gpt-5.4`) are served by default (`manage_pe_aliases`); the tool-call fix for local models (`tool_call_compat`) is opt-in. Released as 0.1.5; 0.1.4 was never published.
- **2026-11-11** Module converted to PDK 4.0.1; CI uses public RubyGems.
