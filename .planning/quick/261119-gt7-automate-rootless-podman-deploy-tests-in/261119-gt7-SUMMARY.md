---
quick_id: 261119-gt7
status: complete
date: 2026-11-19
---

# Summary: automated rootless Podman deploy test

- `tests/acceptance/podman_systemd.sh` and the CI job `podman-systemd` were added. All 18 checks
  pass on ubuntu-24.04 (Podman 4.9.3, Puppet 8).
- Findings while building it:
  - **Control run:** without the flags the unit still starts on Podman 4.9.3. Podman logs
    `The cgroupv2 manager is set to systemd but there is no systemd user session available`
    and falls back to cgroupfs. The fix removes that dependence on the fallback. It is not
    yet proven to fix the operator's exact error, which has not been captured.
  - **Wrong key:** with no database, LiteLLM refuses a wrong key with 400
    `No connected db.`, not 401. The test accepts any 4xx with no model list, and UAT
    Test 2 now says so.
  - **Harness:** a pre-pull through `sudo` picked up the runner's `XDG_RUNTIME_DIR` and
    `XDG_CONFIG_HOME`. It now runs under `env -i` with only `HOME` and `PATH`, matching a
    system unit with `User=`.
- Docs updated: `docs/TESTING.md`, `docs/UAT_HUMAN_TESTING.md`, `CHANGELOG.md`.

## Still manual

A real PE agent run, real provider keys, Docker on a real node, other operating systems,
and certificate trust from the PE primary (UAT Test 2).
