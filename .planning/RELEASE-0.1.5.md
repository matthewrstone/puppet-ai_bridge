# Forge release 0.1.5

Published 2026-11-11 as souldo/ai_bridge (0.1.4 was never published; it was renamed 0.1.5 before release).

- Upload: POST /v3/releases with the existing local Forge key, HTTP 201.
- Public release: https://forge.puppet.com/modules/souldo/ai_bridge/0.1.5
- Artifact: pkg/souldo-ai_bridge-0.1.5.tar.gz, 66,269 bytes, 59 entries,
  SHA-256 f1848c661643a3ddc579f7e885b538ed44b1e03cc8dacbb8e3f2d22baf7c354b.
- Built from commit 77ef9b5 (tag v0.1.5, on remote main). pdk validate 0 findings; pdk test unit 45 examples.
- Verified after upload: API record version 0.1.5, pdk=true, file_sha256 matches; downloaded archive checksum
  and size match; modules endpoint lists releases [0.1.5, 0.1.3] with current_release 0.1.5.
- Forge-processed content: README 12,450 chars (no stray HTML comment, image URL is the GitHub assets path),
  changelog top "## 0.1.5 — 2026-11-11", Reference tab populated (10,921 chars; empty for 0.1.3),
  license present, tags include llm/puppet-enterprise/docker, task docker_runtime listed.
- Observed gap: the Forge lists no plans for this release (plans: []), so the Bolt plan ai_bridge::deploy
  is not shown on the page; same as 0.1.3. Cause not determined.
- Not republishable: 0.1.5 is immutable; any content change needs 0.1.6.
- Lab still has the module installed under the 0.1.4 label (same code; older metadata/docs).
