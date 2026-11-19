---
quick_id: 261119-kwx
mode: quick
date: 2026-11-19
---

# Quick task 261119-kwx: the warning persists for flagless podman commands

The operator still sees `The cgroupv2 manager is set to systemd but there is no systemd user
session available`. CI showed that the patched unit never logs it, so the remaining sources
are podman commands run as the service user without the flags (manual debugging) and hosts
still on module 0.1.5.

## Tasks

1. Manage `<install_dir>/.config/containers/containers.conf` (podman runtime only) with
   `cgroup_manager = "cgroupfs"` and `events_logger = "file"`. Keep the unit flags.
2. Specs: Podman manages the file with that content. Docker does not manage it.
3. Acceptance: fail if the unit's journal or a manual flagless `podman ps` as the service
   user logs the warning. The control run also removes containers.conf.
4. Docs: TROUBLESHOOTING (exact message, cause, check command), CONFIGURATION, CHANGELOG,
   TESTING.
