# Phase 3 — Puppet module `souldo-ai_bridge`

## Goal
`include ai_bridge` + Hiera → running, TLS-terminated, authenticated bridge.

## Design
```
ai_bridge            (params, validation, class ordering)
├── ai_bridge::install   user, dirs, runtime package
├── ai_bridge::config    env file (0600), config.yaml, tls cert/key
└── ai_bridge::service   systemd unit wrapping `podman run` / `docker run`
```
- Type `Ai_bridge::Backend = Enum['anthropic','openai','ollama','openai_compatible']`
- Secrets: `Sensitive[String]` → env file written with `Sensitive` content, mode 0600.
- Container runs as the `ai_bridge` system user, read-only rootfs, no extra caps.
- TLS: `tls_cert`/`tls_key` contents or source paths; `manage_tls=false` to run plain HTTP
  behind another terminator.
- Validation: `upstream_api_key` required for anthropic/openai; `upstream_base_url`
  required for ollama/openai_compatible — enforced with `fail()` so a bad Hiera layer
  fails at compile, not at runtime.

## Tasks
- [x] rspec-puppet specs written first (`spec/classes/init_spec.rb`)
- [x] Manifests + EPP templates
- [x] `puppet-lint` and `rspec` green
- [x] `.gitlab-ci.yml` running lint + spec + go test
- [x] Example Hiera (`data/common.yaml`, `examples/`)
