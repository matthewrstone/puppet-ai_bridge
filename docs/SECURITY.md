# Security notes — ai_bridge

## What the bridge is trusted with

- The **provider API key** (Anthropic/OpenAI/upstream). Compromise = someone can spend your money and read whatever they send.
- **Every prompt and response** between PE and the model, which includes infrastructure details PE's AI Agent feeds in (node names, facts, report data, possibly secrets in facts).
- A **bearer token** (master key) that PE presents. Anyone with it can use your model allowance through the bridge.

So: treat the bridge host like the PE primary, not like a random utility VM.

## Controls in the module

| Threat | Control |
|--------|---------|
| Secrets in the catalog / reports / diffs | All keys typed `Sensitive`; env file written from `Sensitive` content with `show_diff => false`; the catalog still contains them (as all Puppet secrets do) — restrict PuppetDB/console access accordingly |
| Secrets on disk | `/opt/ai_bridge/ai_bridge.env` and `tls/server.key` are `0600`, owned by the `ai_bridge` system user (`nologin`). `config.yaml` contains only `os.environ/` references |
| Unauthenticated use | `master_key` is mandatory; LiteLLM rejects requests without the bearer. The capture tool also supports `-require-key` |
| Eavesdropping between PE and bridge | TLS terminated in the bridge; `manage_tls: false` exists for lab use only and the catalog fails if TLS is on without material |
| Container escape / privilege | `--read-only`, `--tmpfs /tmp`, `--cap-drop=ALL`, `--security-opt=no-new-privileges`; podman runs rootless as `ai_bridge` with its own sub-UID range. Docker mode runs the unit as root because the daemon socket requires it — prefer podman |
| Supply chain | `image` defaults to `main-stable`; **pin a digest in production** (`ghcr.io/berriai/litellm@sha256:…`) and bump deliberately |
| LiteLLM extras | No database, no UI, spend logs disabled, telemetry off (`LITELLM_TELEMETRY=False`), `disable_master_key_return` |
| Prompt logging | Off unless `debug: true`; debug logs full prompts to journald — turn it off after troubleshooting and `journalctl --vacuum-time=1d` |
| pe-capture logs | `capture.jsonl` holds full bodies by design (that's its job) but redacts `Authorization`/`x-api-key`/`api-key` to a 4-char prefix. File mode 0600. Delete after analysis |

## Things you still have to do

1. **Firewall**: allow TCP 4000 from the PE primary only. The module does not manage the firewall (keeps it dependency-free); add a `firewalld`/`ufw` rule in your profile.
2. **Egress**: for `ollama`/`openai_compatible` backends you can block all internet egress from the bridge host. For cloud providers, allow only the provider's API host.
3. **Key rotation**: rotate `master_key` and provider keys on your normal schedule; both are a Hiera change + Puppet run + PE console update.
4. **PuppetDB/console RBAC**: anyone who can read the bridge node's catalog can read the keys. Same as every other Puppet-managed secret, but worth saying.
5. **Data classification**: PE will send infrastructure context to whichever model you choose. For regulated environments use the `ollama`/`openai_compatible` backend with on-prem inference, which is the whole point of having those options.
6. **Provider terms**: using Claude through an OpenAI-shaped bridge is fine from Anthropic's side (it's a normal API call), but check your organisation's AI policy before sending internal data to any SaaS model.

## Threat model summary

In scope: network attackers between PE and bridge (TLS), unauthenticated users on the network (master key), compromised container (hardening, non-root), leaked catalogs/reports (Sensitive, no diffs), lost bridge host disk (0600 files — but no encryption at rest; use full-disk encryption on the VM if that matters).

Out of scope: a compromised PE primary (it legitimately holds the master key), a compromised Puppet server (it holds everything), prompt-injection against the model via node data (a PE AI Agent concern, not a bridge concern — though the bridge is where you'd add a policy gateway like PAG later).
