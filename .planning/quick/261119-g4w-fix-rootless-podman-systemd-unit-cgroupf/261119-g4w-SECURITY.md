---
quick_id: 261119-g4w
threats_total: 4
threats_open: 0
date: 2026-11-19
---

# Security review: rootless Podman cgroupfs fix

Scope: `templates/ai_bridge.service.epp`, which adds `--cgroup-manager=cgroupfs
--events-backend=file` to every Podman command.

| ID | Threat | Disposition | Evidence |
|----|--------|-------------|----------|
| T1 | Container hardening weakened by the change | Mitigated | `--read-only`, `--cap-drop=ALL` and `--security-opt=no-new-privileges` are unchanged and still asserted in `spec/classes/init_spec.rb` |
| T2 | Container escapes systemd supervision under cgroupfs | Mitigated | conmon and the container stay in `ai_bridge.service`'s cgroup. The default `KillMode=control-group` still stops everything |
| T3 | Event log exposes secrets | Accepted (no exposure) | Podman events hold container lifecycle metadata only, not env-file values. The file belongs to the service user's rootless storage |
| T4 | Injection via new template values | Mitigated | The flags are literals. No new parameters or user input reach the unit |

Open threats: 0.
