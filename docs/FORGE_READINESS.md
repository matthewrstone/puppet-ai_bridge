# Forge readiness assessment — 2026-10-30

Verdict: 0.1.2 candidate package builds; hold public release pending the gates below.
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

1. Confirm a green GitHub Actions run on the actual repository. The new
   `.github/workflows/ci.yml` runs explicit Bundler validation and catalog tests on
   Puppet 7/8, Bolt plan tests, Python/Go tests and reference module-builder packaging. PDK 3.8
   validate/test reject the module as not template-compatible; direct tools are
   the intentional alternative. No PDK compatibility claim is made. The legacy
   GitLab jobs now use the same direct validation instead of broken PDK commands.
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

## 0.1.2 Bolt and sales assets

The README now embeds a slide-ready PNG; provider examples are illustrative.
The Bolt plan reuses the class, defaults to checking existing Docker, and accepts
configuration as a Sensitive hash. The runtime task only bootstraps distro Docker
with explicit consent on Ubuntu 22.04/24.04 and Debian 12. Five task tests and four
plan tests cover the control flow. A parameter-helper test verifies both modes,
0600 credential files, and no printed secrets. Plan/task discovery passes with Bolt 5.2.0.
A fresh-host installation and real Bolt apply are still unverified release gates;
mocked plan success is not deployment evidence. See [deployment instructions](BOLT_DEPLOYMENT.md).

## CI validation approach — 2026-10-30

The module intentionally retains its small hand-maintained Gemfile and specs
instead of using `pdk convert`, which would replace repository scaffolding.
CI uses `puppet-modulebuilder` 2.1.0, the reference builder included in PDK.
Local packaging also passes with PDK 3.8.0; its successful build is not a PDK validate
result. Bundler resolves Puppet within the metadata range in separate 7/8 jobs.
Bolt plan specs use RubyGems Bolt 4.0.0 (the latest published gem); workstation
plan discovery also passed with packaged Bolt 5.2.0. Those are distinct artifacts.
The optional real-LiteLLM callback tests require the reviewed image and are not
included in the dependency-free Python CI job. Runtime and OS release gates above
remain open until deployment evidence is recorded.

## Disposable Docker runtime evidence — 2026-10-30

A new LXD project `ai-bridge-validation` and Ubuntu 24.04 VM `docker-paths`
were used, separate from the PE AI bridge. Image fingerprint:
`a80e9c9fd0d484dec024da3e9e264bbad4ce159b5312d6e149ef6ad532e18e43`.
The real `tasks/docker_runtime.py` was copied and run with JSON stdin:

- `{}` on the fresh VM: exit 1, Docker-not-found error; no package installed.
- `{"install_docker":true}`: exit 0, `changed: true`, Docker server 29.1.3.
- `{}` again: exit 0, `changed: false`, Docker server 29.1.3.

Docker was active under systemd. This establishes the runtime task's two modes
on Ubuntu 24.04 only, not a full Bolt apply, bridge deployment, reboot, or the
other OS/runtime combinations. No production target or MCP service was changed.
