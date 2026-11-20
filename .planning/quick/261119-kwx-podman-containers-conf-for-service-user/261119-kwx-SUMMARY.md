---
quick_id: 261119-kwx
status: complete
date: 2026-11-19
---

# Summary: containers.conf for the Podman service user

- `manifests/install.pp` writes `.config/containers/containers.conf` for the Podman runtime.
- `pdk test unit`: 47 examples, 0 failures.
- CI `podman-systemd` at 4337cf4: all 21 checks pass. These include no warning in the unit
  journal and none from a manual flagless `podman ps` as `ai_bridge`. The control run
  (no flags, no containers.conf) reproduces the operator's exact warning.

## Still manual

Upgrade the affected host to a build with this change, then run Puppet and
`systemctl restart ai_bridge`. Then confirm `sudo -u ai_bridge sh -c 'cd /opt/ai_bridge && podman ps'`
prints no warning.
