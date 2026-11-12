# Forge release 0.1.3

Goal: publish an experimental community release as souldo/ai_bridge (namespace
changed by the user after the souldonetworks authorization failures).

## Published

- Forge accepted the release with HTTP 201 on 2026-11-11.
- Public release: https://forge.puppet.com/modules/souldo/ai_bridge/0.1.3
- GET /v3/releases/souldo-ai_bridge-0.1.3 returned HTTP 200, version 0.1.3,
  metadata name souldo-ai_bridge.
- The public module endpoint reports current_release.version=0.1.3.
- Downloaded the public archive and verified its SHA-256 matches the upload:
  515425c82517b98202a3d622e2dd684a9b0e46d03d7bb752192276ccd2ece2cb.
- Final published artifact: pkg/souldo-ai_bridge-0.1.3.tar.gz, 1,223,430 bytes.
- Existing local Forge key successfully published for souldo. No browser MFA was
  required for this API upload. Full PE acceptance remains open as documented.

## Earlier namespace attempt (not published)

Completed preparation:
- Rename Forge metadata and current install/documentation references.
- Add optional Ollama thinking control with red/green catalog tests.
- Update PE 2026 aliases and protected Bolt parameter generation.
- Narrow OS metadata to Ubuntu 24.04; document incomplete PE acceptance.
- Include full Apache-2.0 license and upstream third-party licensing notes.
- Pass catalog tests on Puppet 7/8, Bolt, Python, real callback tests and Go race tests.
- Build and inspect the candidate archive, excluding credentials and development files.

Final artifact: pkg/souldonetworks-ai_bridge-0.1.3.tar.gz (1,223,438 bytes).
SHA-256: a4521841e7db0a486fb32eb75fca90ae04e2657e5b08822fb20d86fef5f74426.

API publication was attempted with the existing local Forge key. Forge returned
HTTP 403: the key cannot publish releases for user souldonetworks. Nothing was
published by that request. The user confirmed Souldo Networks is an organization;
the browser shows organization admin access. The exact archive was selected in
the browser uploader and Upload was submitted. The user completed email MFA.
Forge's browser uploader then rejected the release with the same authorization
message: "You cannot publish releases for the user 'souldonetworks'."
Nothing was published through either path.

Forge's organization documentation says users publish through their personal
Forge accounts: https://help.puppet.com/forge/current/Content/intro/benefits_organizations.htm
An organization named Souldo Networks alone has not provided publishing rights
to the souldonetworks namespace. A publisher account/key authorized for that exact
namespace or a Forge-side namespace correction is required. Do not silently
publish to a different namespace.

The earlier attempt required resolving namespace authorization. The public API returned 404 for
both users/souldonetworks and modules/souldonetworks-ai_bridge during preparation.
No new live PE or bridge changes were made during this release preparation.
