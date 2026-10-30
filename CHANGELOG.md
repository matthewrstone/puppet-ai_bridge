# Changelog

## 0.1.1 — 2026-10-30

- Add opt-in PE token-usage normalization, including streaming response objects.
- Preserve upstream aggregate and supplied detail counts; zero defaults indicate unreported detail statistics.
- Correct Docker bind-file ownership with dropped capabilities, retaining restrictive secret modes.
- Document PE 2026 model aliases, add Python regression tests, and correct repository metadata.
- Record Forge readiness gaps without expanding untested support claims.

## 0.1.0 — 2026-10-29

Initial release.

- Puppet module `ai_bridge`: LiteLLM container under systemd, four backends (anthropic, openai, ollama, openai_compatible), Hiera-driven, TLS, Sensitive secrets, `ensure => absent`.
- `tools/pe-capture`: Go request-capture / minimal-bridge tool.
- `litellm/`: standalone compose + reference config.
- Docs: README, ELI10, user guide, human UAT, security, design, troubleshooting.
- GSD planning under `.planning/`.
