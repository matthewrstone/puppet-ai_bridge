# Changelog

## 0.1.0 — 2026-10-29

Initial release.

- Puppet module `ai_bridge`: LiteLLM container under systemd, four backends (anthropic, openai, ollama, openai_compatible), Hiera-driven, TLS, Sensitive secrets, `ensure => absent`.
- `tools/pe-capture`: Go request-capture / minimal-bridge tool.
- `litellm/`: standalone compose + reference config.
- Docs: README, ELI10, user guide, human UAT, security, design, troubleshooting.
- GSD planning under `.planning/`.
