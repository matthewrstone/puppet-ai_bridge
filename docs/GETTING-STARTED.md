# Getting Started

This page takes you from nothing to a working bridge: a Linux host running LiteLLM in a container, answering Puppet Enterprise (PE) AI Agent requests with the model you choose. It is the short path. The [User guide](USER_GUIDE.md) covers the same ground in more depth, including day-2 operations.

## Prerequisites

You need the following before you start.

| Requirement | Detail |
|-------------|--------|
| Puppet Enterprise | A console with the **Puppet AI Agent settings** page. The bridge host must be reachable from the PE primary on the bridge port (default TCP 4000) |
| Puppet | `>= 7.0.0 < 9.0.0` on the bridge host, as declared in `metadata.json`. CI exercises Puppet 7 and 8 |
| Bridge host OS | RedHat, Rocky or AlmaLinux 9; Ubuntu 22.04 or 24.04; Debian 12 |
| Container runtime | `podman` (default) or `docker`. The module installs the package unless `manage_package` is `false` |
| Outbound access | From the bridge host to your model provider (Anthropic, OpenAI) or to your Ollama or other OpenAI-compatible server, plus the container registry for `ghcr.io/berriai/litellm:main-stable` |
| Hiera with eyaml | Secrets (`master_key`, `upstream_api_key`, `tls_key`) belong in encrypted Hiera values |
| Provider credentials | An API key for Anthropic or OpenAI, or the URL of your local model server |
| Tools | `openssl` to generate the key; `git` to fetch the module |

The bridge does no model inference, so 1 vCPU and 1 GB of memory is enough. Avoid running it on the PE primary if you can; see step 1 of the [User guide](USER_GUIDE.md#1-pick-a-host).

## Installation steps

1. Get the module. Either clone the repository:

   ```bash
   git clone https://github.com/matthewrstone/puppet-ai_bridge.git
   cd puppet-ai_bridge
   ```

   or add `souldo-ai_bridge` to your control repo `Puppetfile` from that repository. The module has no Puppet module dependencies.

2. Generate a master key. This single value is both the bridge's `master_key` and what you paste into PE as the "API key":

   ```bash
   openssl rand -hex 32
   ```

3. Get a TLS certificate for the bridge host. PE's console is Java and must trust the certificate the bridge presents, and the hostname you give PE must match the certificate name or one of its subject alternative names. The module does not issue certificates; it only takes the PEM text as `tls_cert` and `tls_key`. Choose one option.

   **Option A: the Puppet CA (recommended).** Every PE installation has one. On the primary, issue a certificate for the bridge host and add any other names PE might use:

   ```bash
   puppetserver ca generate --certname ai-bridge.example.com \
     --subject-alt-names ai-bridge.example.com,ai-bridge
   ```

   Replace `ai-bridge.example.com` with the bridge FQDN. The certificate and private key are normally written under the primary's Puppet SSL directory as `certs/<certname>.pem` and `private_keys/<certname>.pem` (default `/etc/puppetlabs/puppet/ssl/`).
   PE services already trust the Puppet CA, so no truststore change should be needed.

   **Option B: a public CA (ACME / Let's Encrypt).** This needs a publicly resolvable DNS name for the bridge host. Obtain the certificate with your ACME client (certbot, acme.sh) and use the full chain file as `tls_cert`. The module does not run ACME or renew certificates, so update Hiera on each renewal and run Puppet.

   **Option C: an external TLS proxy.** If you already operate a TLS-terminating proxy or load balancer, set `ai_bridge::manage_tls: false`. The bridge then serves plain HTTP and needs no certificate; the proxy presents the certificate and PE points at the proxy's HTTPS URL. Keep the bridge's plain-HTTP port reachable only from the proxy. Whether PE accepts a plain `http://` URL directly has not been confirmed; do not expose it to untrusted networks.

   If you happen to run an internal CA, a certificate from it also works, provided the PE console trusts that CA. See [Configuration](CONFIGURATION.md#tls-parameters) for the full TLS reference.

4. Put the settings in Hiera, for example in `data/nodes/<bridge-fqdn>.yaml` in your control repo. Encrypt every secret with eyaml:

   ```bash
   eyaml encrypt -l 'ai_bridge::tls_key' -f private_keys/ai-bridge.example.com.pem
   ```

   ```yaml
   ai_bridge::backend: anthropic
   ai_bridge::upstream_model: claude-sonnet-4-5
   ai_bridge::upstream_api_key: ENC[PKCS7,...]
   ai_bridge::master_key: ENC[PKCS7,...]
   ai_bridge::tls_cert: |
     -----BEGIN CERTIFICATE-----
     ...
     -----END CERTIFICATE-----
   ai_bridge::tls_key: ENC[PKCS7,...]
   ```

   For OpenAI, Ollama or another OpenAI-compatible server, change the `backend`, `upstream_model` and key or URL as shown in the [Backends table](../README.md#backends) and in `examples/` (`claude.yaml`, `openai.yaml`, `ollama.yaml`). Do not paste a raw private key into unencrypted Hiera.

5. Classify the bridge host:

   ```puppet
   include ai_bridge
   ```

   Prefer an agentless push with no Puppet agent on the target? Use the [Bolt deployment plan](BOLT_DEPLOYMENT.md) instead of steps 4 and 5.

## First run

On the bridge host, run Puppet:

```bash
puppet agent -t
```

The first run creates the `ai_bridge` service user, installs the container runtime, writes the config and TLS files under `/opt/ai_bridge`, installs the `ai_bridge` systemd unit and starts it. The unit pulls the LiteLLM image on start, so the first start can take a few minutes. You should see:

```
Notice: /Stage[main]/Ai_bridge::Service/Service[ai_bridge]/ensure: changed 'stopped' to 'running'
```

Then verify the bridge from the PE primary, using the same trust PE will use (no `-k`):

```bash
curl -s https://ai-bridge.example.com:4000/v1/models \
  -H "Authorization: Bearer <master_key>"

curl -s https://ai-bridge.example.com:4000/v1/chat/completions \
  -H "Authorization: Bearer <master_key>" -H "Content-Type: application/json" \
  -d '{"model":"o4-mini","messages":[{"role":"user","content":"Say hello in five words."}]}'
```

If the first command reports a certificate error, the PE console will too; fix the trust chain before continuing.

Finally, point PE at the bridge. In the PE console open **Puppet AI Agent settings** and set:

| Field | Value |
|-------|-------|
| AI service | Open AI |
| URL | `https://ai-bridge.example.com:4000/v1` |
| API key | the master key from step 2 |

Click **Update API settings**. No red banner means success. Open the AI Agent and ask it something about your infrastructure.

## Common setup issues

| Symptom | Cause and fix |
|---------|---------------|
| Puppet fails with `tls_cert and tls_key are required` | `manage_tls` is `true` by default. Provide both values, or set `ai_bridge::manage_tls: false` and use a TLS proxy |
| Puppet fails with `upstream_api_key is required` or `upstream_base_url is required` | `anthropic` and `openai` need `upstream_api_key`; `ollama` and `openai_compatible` need `upstream_base_url` |
| Puppet fails with `expects a Sensitive` | eyaml values arrived as plain strings. Add the `lookup_options` block from [Configuration](CONFIGURATION.md#example-hiera) to your control repo |
| PE save fails with `PKIX path building failed` | The PE JVM does not trust the bridge certificate. Use a certificate from a CA PE trusts, and check the hostname matches the certificate. See [Troubleshooting](TROUBLESHOOTING.md) |
| PE save fails with `Connection refused` | Check `systemctl status ai_bridge`, `ss -ltnp \| grep 4000`, and the firewall rule from the primary to the bridge port |
| PE save fails with `401` | The key in PE does not match `master_key` in Hiera. Re-paste it |
| Ollama answers but ignores tools | Use a tool-capable model; PE's agent relies on tool calling |

For anything else, start with `journalctl -u ai_bridge -n 200 --no-pager` on the bridge host and see [Troubleshooting](TROUBLESHOOTING.md).

## Next steps

- [User guide](USER_GUIDE.md): the full walk-through, switching backends, extra model aliases, and day-2 operations
- [ELI10](ELI10.md): the plain-language explanation of what the bridge does
- [Configuration](CONFIGURATION.md): every parameter, environment variable and TLS option
- [Architecture](ARCHITECTURE.md): how the pieces fit together
- [Bolt deployment](BOLT_DEPLOYMENT.md): agentless deployment
- [Security](SECURITY.md): threat model and hardening
- [Human UAT](UAT_HUMAN_TESTING.md): acceptance tests that need a person and a real PE console
- Running the module's automated tests: see the Testing section of the [README](../README.md#testing) and [Forge readiness](FORGE_READINESS.md)
