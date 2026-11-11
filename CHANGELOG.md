# Changelog

## 0.1.3 — 2026-11-11

- Publish package metadata for the `souldo/ai_bridge` Forge namespace.
- Add optional `ollama_think` control for Ollama primary models and aliases;
  preserve upstream behavior when unset.
- Include both PE 2026 model aliases in the Gemma deployment example and Bolt
  parameter generator.
- Narrow the OS claim to Ubuntu 24.04 and document incomplete PE acceptance and
  unverified Podman deployment behavior.
- Include the complete Apache-2.0 license and third-party licensing notes.
- Add optional Hiera `personality_prompt` for chat response style, preserving
  original messages and working alongside PE usage normalization.
- Keep the default unset; mount style data and callback code read-only.

## 0.1.2 — 2026-10-30

- Add a sales overview graphic and concise provider-choice README introduction.
- Add `ai_bridge::deploy` Bolt plan and `ai_bridge::docker_runtime` bootstrap/check task.
- Keep existing Docker unchanged; optional distro Docker installation supports Ubuntu 22.04/24.04 and Debian 12.
- Add protected-parameter deployment instructions, inventory examples and tests.

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
