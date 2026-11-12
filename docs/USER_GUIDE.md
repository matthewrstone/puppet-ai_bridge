# ai_bridge user guide

For an SE or customer admin who needs the PE AI Agent working again, or wants it running against Claude / a local model. Assumes a PE 2025.x or 2026.x console with the **Puppet AI Agent** tab (PE 2025.x asks for `o4-mini`; PE 2026.x also asks for `gpt-5.4-mini` and `gpt-5.4`, which the module serves by default; see the README's PE versions table; PE 2026 with Ollama also wants `tool_call_compat: true`), a Linux host for the bridge, and a Puppet control repo with Hiera eyaml.

## 1. Pick a host

Any EL9 or Ubuntu 22.04+ box the PE primary can reach on TCP 4000. It needs outbound access to your chosen provider (or to your Ollama/vLLM host). 1 vCPU / 1 GB is plenty; the bridge does no inference.

Do **not** put it on the PE primary unless you have to — PE already runs a lot of Java and you want the bridge's lifecycle independent.

## 2. Generate the master key

```sh
openssl rand -hex 32
```

This single value is both the bridge's `master_key` and what you paste into the PE console as the "OpenAI API key". Treat it like any API key.

## 3. Get a certificate

PE's console backend is Java; it must trust the bridge's cert. You do **not** need your own certificate authority. Every PE install already has one, so start there.

**a. PE's own CA (recommended)** — sign with the Puppet CA that your PE installation already runs. PE components trust it by default, but see the VERIFY note below.

```sh
# on the PE primary:
puppetserver ca generate --certname ai-bridge.example.com \
  --subject-alt-names ai-bridge.example.com
# the cert and key are written on the primary (see VERIFY below)
```

Use the same name here that you will type into the PE console URL, because the name in the URL must match the cert.


**b. A publicly trusted certificate (e.g. Let's Encrypt)** — only if the bridge has a public DNS name. Obtain the cert with your ACME client of choice and use the full chain. Public roots are generally already in Java truststores, but confirm that for your PE version.

**c. An external TLS proxy** — terminate TLS on a load balancer or reverse proxy you already have, set `manage_tls: false`, and point PE at the proxy's HTTPS URL. The proxy-to-bridge hop is plain HTTP, so keep it on a private network.

*If you already run an internal CA (Step CA, AD CS, …)*, that works too: issue a server cert for the bridge FQDN and make sure PE's JVM trusts the CA.

For (a) and (b) you end up with a PEM cert chain and a PEM key; those are `tls_cert` and `tls_key`.

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
- Certificate renewal: update `tls_cert`/`tls_key` in Hiera (Puppet will leave matching content alone, and restarts the service when the content changes). Put the renewal date in your calendar: a Puppet CA or ACME cert expiring silently is the most common cause of a sudden PE TLS error.

## Response style through Hiera

Set optional `ai_bridge::personality_prompt` in your node's Hiera data:

```yaml
ai_bridge::personality_prompt: 'Talk like a pirate'
```

Multiline text works too:

```yaml
ai_bridge::personality_prompt: |
  Talk like a pirate.
  Keep infrastructure advice clear and concise.
```

The default is unset. The module writes this text to a read-only container mount
and enables a LiteLLM chat-completion callback. It appends a style supplement to
the first existing system message, preserving that message's original content
and every other message, tool definition and request field. If there is no system
message, it adds one before the existing conversation. It supports string and
text-block system content. The text is data, never executed as Python or shell.

This is a model instruction, not an access-control mechanism or a guarantee of
tone. It grants no tool permissions and does not change PE approval settings.
Keep it about style; existing PE instructions and authorization requirements
still apply. A model may follow style imperfectly. This setting affects all chat
completion requests through this bridge, including streaming requests; it does
not alter embeddings. It can be combined with `ai_bridge::normalize_usage: true`.
It is intended for `/v1/chat/completions`, not the separate Responses API.

After changing Hiera, run Puppet on the bridge; the service restarts to load the
new text. To disable it, remove the Hiera key (or set it to YAML `null`); Puppet
removes the style files and disables that callback. Keep credentials out of the
prompt. The file is not encrypted and upstream models receive its text. No debug
logging is required. Pin and retest LiteLLM when changing images; callback API
compatibility was tested with the lab's 1.106.6 image.
