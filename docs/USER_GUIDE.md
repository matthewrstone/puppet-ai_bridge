# ai_bridge user guide

For an SE or customer admin who needs the PE AI Agent working again, or wants it running against Claude / a local model. Assumes a PE 2025.x console with the **Puppet AI Agent** tab, a Linux host for the bridge, and a Puppet control repo with Hiera eyaml.

## 1. Pick a host

Any EL9 or Ubuntu 22.04+ box the PE primary can reach on TCP 4000. It needs outbound access to your chosen provider (or to your Ollama/vLLM host). 1 vCPU / 1 GB is plenty; the bridge does no inference.

Do **not** put it on the PE primary unless you have to — PE already runs a lot of Java and you want the bridge's lifecycle independent.

## 2. Generate the master key

```sh
openssl rand -hex 32
```

This single value is both the bridge's `master_key` and what you paste into the PE console as the "OpenAI API key". Treat it like any API key.

## 3. Get a certificate

PE's console backend is Java; it must trust the bridge's cert. Two easy paths:

**a. Your internal CA (Step CA, AD CS, …)** — issue a server cert for the bridge FQDN. If the PE JVM already trusts that CA, you're done.

```sh
step ca certificate ai-bridge.souldo.lan server.crt server.key --san ai-bridge.souldo.lan
```

**b. PE's own CA** — sign with the Puppet CA, which the PE console *definitely* trusts:

```sh
# on the bridge host (a Puppet agent):
puppetserver ca generate --certname ai-bridge.souldo.lan   # on the primary
# cert lands in /etc/puppetlabs/puppet/ssl/certs/, key in private_keys/
```

Either way you end up with a PEM cert chain and a PEM key; those are `tls_cert` and `tls_key`.

If you cannot get a trusted cert quickly, set `manage_tls: false`, run the bridge on plain HTTP **on a private network only**, and test whether PE accepts an `http://` URL. Treat this as temporary.

## 4. Choose and configure a backend

In your control repo, create `data/nodes/<bridge-fqdn>.yaml` (or a role file). Encrypt every secret with eyaml.

### Claude

```yaml
ai_bridge::backend: anthropic
ai_bridge::upstream_model: claude-sonnet-4-5
ai_bridge::upstream_api_key: ENC[PKCS7,...]
ai_bridge::master_key: ENC[PKCS7,...]
ai_bridge::tls_cert: |
  -----BEGIN CERTIFICATE-----
  ...
ai_bridge::tls_key: ENC[PKCS7,...]
```

### A current OpenAI model

```yaml
ai_bridge::backend: openai
ai_bridge::upstream_model: gpt-5-mini
ai_bridge::upstream_api_key: ENC[PKCS7,...]
# master_key, tls_* as above
```

### Ollama (local, air-gapped)

```yaml
ai_bridge::backend: ollama
ai_bridge::upstream_model: 'qwen3:32b'
ai_bridge::upstream_base_url: http://ollama.souldo.lan:11434
ai_bridge::request_timeout: 600
# master_key, tls_* as above — no upstream_api_key needed
```

Make sure the model is pulled (`ollama pull qwen3:32b`) and that Ollama listens on the network (`OLLAMA_HOST=0.0.0.0`). Use a model that supports tool calling; PE's agent relies on it.

### vLLM / LM Studio / llama.cpp / PAG

```yaml
ai_bridge::backend: openai_compatible
ai_bridge::upstream_model: Qwen/Qwen3-32B
ai_bridge::upstream_base_url: http://vllm.souldo.lan:8000/v1
ai_bridge::upstream_api_key: ENC[PKCS7,...]   # only if the server requires one
```

## 5. Classify and run

```puppet
# site.pp / role
include ai_bridge
```

Run the agent. You should see:

```
Notice: /Stage[main]/Ai_bridge::Service/Service[ai_bridge]/ensure: changed 'stopped' to 'running'
```

Verify from the PE primary (replace the key):

```sh
curl -s https://ai-bridge.souldo.lan:4000/v1/models \
  -H "Authorization: Bearer <master_key>" | jq .
curl -s https://ai-bridge.souldo.lan:4000/v1/chat/completions \
  -H "Authorization: Bearer <master_key>" -H "Content-Type: application/json" \
  -d '{"model":"o4-mini","messages":[{"role":"user","content":"Say hello in five words."}]}' | jq -r '.choices[0].message.content'
```

If the first command errors with a certificate problem, the PE JVM will too — fix the trust chain before moving on.

## 6. Point PE at it

PE console → **Puppet AI Agent** → settings:

| Field | Value |
|-------|-------|
| AI service | Open AI |
| Enter URL | `https://ai-bridge.souldo.lan:4000/v1` |
| Enter Open AI API key | the master key |

Click **Update API settings**. The red banner should be gone. Open the AI Agent and ask it something about your infrastructure.

## 7. Switching backends later

Change `ai_bridge::backend`, `upstream_model`, and the key/URL in Hiera, run Puppet. The service restarts (a few seconds). PE needs no change at all.

## 8. Adding more model names

If a future PE release asks for a different name, or you want other tools to share the bridge:

```yaml
ai_bridge::extra_aliases:
  o3: anthropic/claude-opus-4-1
  gpt-4o: anthropic/claude-sonnet-4-5
```

## 9. Turning it off

```yaml
ai_bridge::ensure: absent
```

Stops the service, removes the unit, config, env and TLS files. The container runtime package and the `ai_bridge` user are left in place.

## 10. Day-2

- Logs: `journalctl -u ai_bridge -f`
- Health: `curl -sk https://localhost:4000/health/liveliness`
- Upgrade LiteLLM: change `ai_bridge::image` to a newer tag/digest, run Puppet.
- Rotate the master key: new value in Hiera → Puppet → update PE console. Do PE immediately after; the old key stops working on restart.
- Certificate renewal: update `tls_cert`/`tls_key` in Hiera (or wire `step ca renew` to write the files and `systemctl restart ai_bridge`; Puppet will leave matching content alone).
