---
quick_id: 261119-g4w
status: complete
date: 2026-11-19
---

# Summary: rootless Podman cgroup manager fix

- `templates/ai_bridge.service.epp` builds the runtime command in the template. For Podman it is
  `/usr/bin/podman --cgroup-manager=cgroupfs --events-backend=file`. For Docker it stays
  `/usr/bin/docker`. The template's parameters are unchanged.
- `spec/classes/init_spec.rb` checks the flags on the Podman `ExecStartPre`, `ExecStart` and
  `ExecStop` lines, and checks that the Docker unit has no `--cgroup-manager`.
- `CHANGELOG.md` (Unreleased) and `docs/TROUBLESHOOTING.md` document the fix.

## Verification

- `pdk test unit`: 45 examples, 0 failures.
- Not run on a live Podman host. The Podman runtime is still unverified in the field
  (`BACKLOG.md`). Human check: run Puppet on a Podman bridge node, then
  `systemctl restart ai_bridge` and `systemctl status ai_bridge` shows active (running).
