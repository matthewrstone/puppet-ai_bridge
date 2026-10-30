# Forge readiness assessment — 2026-10-30

Verdict: candidate package builds; hold public release pending the gates below.
This is a community module assessment, not Puppet Supported certification or a
CIS/ISO compliance assertion. No MCP service is enabled by this change.

## Included in 0.1.1

Opt-in PE usage-detail normalization with synchronous-completion and streaming
hooks, restrictive Docker bind-file ownership corrections, callback sources,
regression tests, PE 2026 alias guidance, corrected GitHub metadata and packaging
exclusions. Existing configurable aliases are reused, not a new routing feature.

## Checks

- 29 RSpec catalog examples passed using installed Puppet 8.17 tooling.
- Five pure Python normalizer tests passed.
- Three callback tests passed against the lab's running LiteLLM 1.106.6 container;
  they cover real response classes, supplied counts and streaming usage chunks.
- Puppet parser validation, lint (`--relative --fail-on-warnings`), and
  metadata-json-lint passed. Relative layout checking avoids mistaking the
  checkout directory name for the Puppet namespace.
- PDK built `pkg/souldo-ai_bridge-0.1.1.tar.gz`. Archive inspection verifies
  runtime Python helpers are included and fixture symlinks/caches are excluded.
- Lab: Docker, Ubuntu 24.04, Puppet 9.1.1, Gemma 4 12B. PE API recorded a
  completion timestamp. Final visual “Thinking” clearance remains unverified.

## Release gates

1. Establish PDK compatibility and working CI on the actual GitHub repository.
   Current `.gitlab-ci.yml` calls PDK validate/test without compatible module
   metadata. Do not treat the build's success as a successful PDK validation run.
2. Test installation, second-run idempotence, restart-on-config-change and removal
   across claimed OS/Puppet/runtime combinations. Current metadata lists Puppet
   7/8 and multiple Linux families, while live evidence is Ubuntu/Docker/Puppet 9.
   Narrow claims or collect that evidence before release; do not expand Puppet 9
   support solely from one successful lab rollout.
3. Validate the default rootless Podman service with reboot, sub-id mappings and
   TLS access. Its user/systemd and volume behavior has not been live-tested.
   Validate distro runtime package names (notably `docker`) or document an
   externally managed runtime (`manage_package => false`).
4. Pin and test a supported LiteLLM artifact. The module default is mutable
   `main-stable`; the lab used digest
   `sha256:37e2dafb088a7723beb998590682957386dfc83ffea1848486f8e0e5cfac0b06`.
   Confirm callback API compatibility on every supported image update.
5. Complete browser UAT and actual tool-call/streaming round trips. A PE PQL
   response and callback chunk tests do not establish full conversational quality.
6. Confirm the Forge account owns namespace `souldo` and version 0.1.1 is available;
   check the final archive and release notes, then explicitly authorize publishing.
7. Review the README's original unconditional model-deprecation claims and provider
   examples against current vendor documentation before public release.

## Reproduction

```sh
python3 -B -m unittest discover -s tests -p test_pe_usage.py
# With the tested LiteLLM environment installed:
python3 -B tests/test_pe_compat_runtime.py
bundle exec rspec spec/classes/init_spec.rb
bundle exec puppet-lint --relative --fail-on-warnings manifests types
bundle exec metadata-json-lint metadata.json
puppet parser validate manifests/*.pp types/*.pp
pdk build --force
# Inspect package contents before upload; no fixtures, symlinks or bytecode.
tar -tzf pkg/souldo-ai_bridge-0.1.1.tar.gz
```

The standalone Go capture utility has separate tests; it is not needed at runtime
for this module and is excluded by PDK's package defaults.

Sources: [Puppet publishing preparation](https://help.puppet.com/core/current/Content/PuppetCore/modules_publishing_prep.htm),
[module metadata](https://help.puppet.com/core/current/Content/PuppetCore/modules_metadata.htm),
[PDK command reference](https://help.puppet.com/pdk/current/topics/pdk_reference.htm).
