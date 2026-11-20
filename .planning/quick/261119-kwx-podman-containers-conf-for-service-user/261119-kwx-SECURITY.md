---
quick_id: 261119-kwx
threats_total: 2
threats_open: 0
date: 2026-11-19
---

# Security review: containers.conf for the service user

| ID | Threat | Disposition | Evidence |
|----|--------|-------------|----------|
| T1 | Config weakens container isolation | Mitigated | Only cgroup_manager and events_logger are set. Unit hardening flags are unchanged and asserted by specs and the acceptance test |
| T2 | Service user can edit its own containers.conf | Accepted | The user already owns its rootless storage and runs its own containers. Puppet restores the file every run |

Open threats: 0.
