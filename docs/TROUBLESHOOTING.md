# Troubleshooting — ai_bridge

Start with `journalctl -u ai_bridge -n 200 --no-pager` and `curl -sk https://localhost:4000/health/liveliness` on the bridge host.

| Symptom | Likely cause | Fix |
|---------|--------------|-----|
| PE save fails: `PKIX path building failed` / `unable to find valid certification path` | PE's JVM doesn't trust the bridge cert | Issue the cert from a CA the JVM trusts (Puppet CA is the safe bet), or import your CA into the PE console truststore. Check with `curl` from the primary without `-k` |
| PE save fails: `Connection refused` | Service not running, wrong port, firewall | `systemctl status ai_bridge`; `ss -ltnp | grep 4000`; firewall rule from primary to bridge:4000 |
| PE save fails: `401` | Master key in PE ≠ `master_key` in Hiera | Re-paste the key. Remember rotation requires updating PE too |
| PE save fails: `404 model o4-mini` *through the bridge* | `exposed_model` changed, or LiteLLM config didn't render | `grep model_name /opt/ai_bridge/config.yaml`; `curl .../v1/models` |
| Bridge log: `AuthenticationError` from provider | Bad/expired `upstream_api_key` | Fix in Hiera, run Puppet |
| Bridge log: `UnsupportedParamsError` / provider 400 on `reasoning_effort`, `max_completion_tokens` | `drop_params` is false | Set `ai_bridge::drop_params: true` (default) |
| Bridge log: `ollama_chat ... connection refused` | Ollama not listening on the network | `OLLAMA_HOST=0.0.0.0` on the Ollama host; check `upstream_base_url` has no `/v1` suffix for Ollama |
| Ollama answers but ignores tools / returns garbage for tool calls | Model lacks tool-calling support | Use a tool-capable model (Qwen3, Llama 3.1+, Mistral Nemo…) |
| PE AI Agent times out on local model | Model slower than PE's client timeout | Smaller model, GPU, or quantised variant; raise `request_timeout` (helps only the bridge side) |
| `podman: permission denied` / sub-UID errors | Rootless podman needs sub-IDs for the service user | The module adds them via `usermod`; if `/etc/subuid` is managed elsewhere, add `ai_bridge:200000:65536` there |
| Unit fails with `Error: statfs ... permission denied` on `-v ...:Z` | SELinux relabel on a path it can't label | Keep files under `/opt/ai_bridge` (default), or drop the `,Z` in the template if SELinux is disabled |
| Puppet: `tls_cert and tls_key are required` | `manage_tls` true without material | Provide both, or set `manage_tls: false` (lab only) |
| Puppet: `expects a Sensitive` | A key passed as plain String | Wrap in `Sensitive()` or use eyaml (Hiera eyaml values arrive as Sensitive when `ai_bridge::master_key` is looked up with `lookup_options` convert_to Sensitive) — add to your control repo: ```lookup_options: { '^ai_bridge::(master_key|upstream_api_key|tls_key)$': { convert_to: Sensitive } }``` |
| Second Puppet run restarts the service every time | Something rewrites a file each run (e.g. trailing newline differences in `tls_cert`) | `puppet agent -t --noop` to see which file; normalise the Hiera value |
| Want to see exactly what PE sends | — | Run `pe-capture` in forward mode in front of the bridge (see compose `capture` profile) |

## Reading `capture.jsonl`

```sh
jq -c '{ts, method, path, model: .body.model, stream: .body.stream, has_tools: (.body.tools != null), status: .response_status}' capture.jsonl
jq '.body | keys' capture.jsonl | sort -u       # every field PE ever sent
jq '.headers' capture.jsonl | head              # credentials are already redacted
```
