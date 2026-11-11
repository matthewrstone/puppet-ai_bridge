<!-- generated-by: gsd-doc-writer -->
# Configuration

This page documents every setting the `ai_bridge` module reads: class parameters (normally set through Hiera), the environment variables the module writes for the container, the settings rendered into the LiteLLM `config.yaml`, and the inputs of the `ai_bridge::deploy` Bolt plan.

The module has no configuration file of its own and reads no environment variables on the Puppet side. All configuration is class parameters. Everything the container sees is rendered by Puppet from those parameters.

## Where configuration comes from

| Layer | File | What it does |
|-------|------|--------------|
| Class defaults | `manifests/init.pp` | Defaults declared in the class signature |
| Module Hiera data | `data/common.yaml`, `hiera.yaml` | Repeats `backend`, `upstream_model`, `exposed_model`, `listen_port`, `container_runtime`, `drop_params` at their default values. The file says to override in your control repo, never here |
| Your control repo | Your Hiera hierarchy | Where you set real values and all secrets |
| Bolt plan | `plans/deploy.pp` | Passes a `config` hash straight through as class parameters |

Secrets (`master_key`, `upstream_api_key`, `tls_key`) have deliberately no default. The catalog fails to compile until you provide them.

## Environment variables

### Written into the container env file

Puppet renders `<install_dir>/ai_bridge.env` (`templates/ai_bridge.env.epp`) with mode `0600`, owned by the service user (root with Docker), and never shows its diff. The unit passes it to the container with `--env-file`.

| Variable | Present when | Value | Description |
|----------|--------------|-------|-------------|
| `LITELLM_MASTER_KEY` | Always | `master_key` | Bearer token PE must present. `config.yaml` references it as `os.environ/LITELLM_MASTER_KEY` |
| `ANTHROPIC_API_KEY` | `backend: anthropic` and `upstream_api_key` set | `upstream_api_key` | Provider key read by LiteLLM |
| `OPENAI_API_KEY` | `backend: openai` and `upstream_api_key` set | `upstream_api_key` | Provider key read by LiteLLM |
| `UPSTREAM_API_KEY` | `backend: openai_compatible` and `upstream_api_key` set | `upstream_api_key` | Optional key for the compatible server |
| `LITELLM_LOG` | `debug: true` | `DEBUG` | Verbose logging, including full prompts |
| `LITELLM_TELEMETRY` | Always | `False` | Stops LiteLLM phoning home |
| `NO_DOCS` | Always | `True` | Disables LiteLLM's documentation pages |

With `backend: ollama` there is no provider key variable, so `upstream_api_key` is ignored even if set.

### Set by the systemd unit

| Variable | Present when | Value |
|----------|--------------|-------|
| `PYTHONPATH` | `normalize_usage` or `personality_prompt` is set | `/app`, so LiteLLM can import the mounted callback modules |

## Class parameters

Set these as `ai_bridge::<name>` keys in Hiera. Only `master_key` is required unconditionally.

| Parameter | Type | Default | Required | Description |
|-----------|------|---------|----------|-------------|
| `ensure` | `Enum['present','absent']` | `present` | No | `present` deploys and runs the bridge. `absent` stops the service, removes the unit and deletes `install_dir`. The container runtime package and service user are left in place |
| `backend` | `Ai_bridge::Backend` | `anthropic` | No | `anthropic`, `openai`, `ollama` or `openai_compatible` |
| `upstream_model` | `String[1]` | `claude-sonnet-4-5` | No | Provider-side model name, for example `gpt-5-mini` or `qwen3:32b` |
| `upstream_api_key` | `Optional[Sensitive[String[1]]]` | `undef` | Conditional | Required for `anthropic` and `openai`. Optional for `openai_compatible`. Ignored for `ollama` |
| `upstream_base_url` | `Optional[Ai_bridge::Url]` | `undef` | Conditional | Required for `ollama` (for example `http://host:11434`) and `openai_compatible` (for example `http://host:8000/v1`). Must match `http(s)://...` with no whitespace |
| `master_key` | `Sensitive[String[1]]` | none | Yes | Token you paste into the PE console "API key" field. Generate with `openssl rand -hex 32` |
| `exposed_model` | `String[1]` | `o4-mini` | No | Primary model name PE asks for. PE 2025.x hard-codes `o4-mini`; change it only if PE changes. PE 2026.x additionally asks for `gpt-5.4-mini` and `gpt-5.4` (see `manage_pe_aliases`) |
| `manage_pe_aliases` | `Boolean` | `true` | No | Also expose `gpt-5.4-mini` and `gpt-5.4`, mapped to the same upstream model as `exposed_model`, so one bridge serves PE 2025.x and 2026.x. Entries in `extra_aliases` override them. `false` exposes only `exposed_model` |
| `tool_call_compat` | `Boolean` | `false` | No | Withhold a strict JSON-schema `response_format` from tool-enabled requests until a tool result is present, so local models call PE's PuppetDB tool instead of inventing an answer. Enable for PE 2026 with Ollama |
| `extra_aliases` | `Hash[String[1], String[1]]` | `{}` | No | Extra `exposed_name => 'provider/model'` entries, rendered verbatim as LiteLLM model strings |
| `listen_port` | `Ai_bridge::Port` (1-65535) | `4000` | No | Port the bridge listens on. The PE URL is `https://<host>:<port>/v1` |
| `manage_tls` | `Boolean` | `true` | No | Terminate TLS in the bridge. See [TLS parameters](#tls-parameters) |
| `tls_cert` | `Optional[String[1]]` | `undef` | If `manage_tls` | PEM certificate (chain) contents |
| `tls_key` | `Optional[Sensitive[String[1]]]` | `undef` | If `manage_tls` | PEM private key contents |
| `container_runtime` | `Enum['podman','docker']` | `podman` | No | `podman` runs rootless as `user`. `docker` runs as root |
| `image` | `String[1]` | `ghcr.io/berriai/litellm:main-stable` | No | LiteLLM image. Pin a tag or digest in production; the unit runs `pull` on every start |
| `install_dir` | `Ai_bridge::Absolutepath` | `/opt/ai_bridge` | No | Directory for config, env file, TLS material and callback files |
| `user` | `String[1]` | `ai_bridge` | No | System user and group that own the files. With Docker, files are owned by root instead |
| `drop_params` | `Boolean` | `true` | No | Strip request parameters the backend does not support instead of failing. PE may send reasoning parameters, so keep this true |
| `request_timeout` | `Integer[1]` | `300` | No | Seconds LiteLLM waits for the provider |
| `debug` | `Boolean` | `false` | No | Sets `LITELLM_LOG=DEBUG` and `set_verbose: true`. Logs full prompts; use for troubleshooting only |
| `normalize_usage` | `Boolean` | `false` | No | Enables the PE usage-detail compatibility callback. Unreported usage detail fields become zero |
| `personality_prompt` | `Optional[String[1]]` | `undef` | No | Response style text appended to the chat system instructions. Grants no permissions. See [personality_prompt](#personality_prompt) |
| `manage_package` | `Boolean` | `true` | No | Install the `podman` or `docker` package. The plan sets this to `false` |
| `service_ensure` | `Enum['running','stopped']` | `running` | No | Service state when `ensure` is `present`. The service is always enabled at boot |

### Backend requirements

Validated at compile time in `manifests/init.pp`. A failure aborts the catalog.

| Backend | LiteLLM model string | Needs | Key variable |
|---------|----------------------|-------|--------------|
| `anthropic` | `anthropic/<upstream_model>` | `upstream_api_key` | `ANTHROPIC_API_KEY` |
| `openai` | `openai/<upstream_model>` | `upstream_api_key` | `OPENAI_API_KEY` |
| `ollama` | `ollama_chat/<upstream_model>` | `upstream_base_url` | none |
| `openai_compatible` | `openai/<upstream_model>` | `upstream_base_url` | `UPSTREAM_API_KEY` (optional) |

Validation errors:

- `ai_bridge: upstream_api_key is required when backend is '<backend>'`
- `ai_bridge: upstream_base_url is required when backend is '<backend>'`
- `ai_bridge: tls_cert and tls_key are required when manage_tls is true (set manage_tls: false to run plain HTTP)`

Validation of `tls_cert` and `tls_key` is skipped when `ensure` is `absent`.

### Example Hiera

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

Secret parameters must arrive as `Sensitive`. If your eyaml values arrive as plain strings, add this to your control repo Hiera (from `docs/TROUBLESHOOTING.md`):

```yaml
lookup_options:
  '^ai_bridge::(master_key|upstream_api_key|tls_key)$':
    convert_to: Sensitive
```

## TLS parameters

`manage_tls`, `tls_cert` and `tls_key` control whether the bridge itself serves HTTPS.

PE's console backend is Java. Its JVM must trust the certificate the bridge presents, and the certificate must cover the hostname in the URL you give PE. If it does not, saving the model in the PE console fails with `PKIX path building failed`.

When `manage_tls` is true:

- Puppet writes `<install_dir>/tls/server.crt` (mode `0644`) from `tls_cert` and `<install_dir>/tls/server.key` (mode `0600`, diff hidden) from `tls_key`.
- The unit mounts `<install_dir>/tls` read-only at `/app/tls` and starts LiteLLM with `--ssl_certfile_path=/app/tls/server.crt --ssl_keyfile_path=/app/tls/server.key`.

When `manage_tls` is false, no certificate files are written or mounted and the bridge serves plain HTTP.

### Fail-fast validation

If `manage_tls` is true (the default), `ensure` is `present`, and either `tls_cert` or `tls_key` is unset, the catalog fails to compile with:

```
ai_bridge: tls_cert and tls_key are required when manage_tls is true (set manage_tls: false to run plain HTTP)
```

Provide both values, or opt out with `manage_tls: false` (see option 3 below).

### Option 1: Puppet CA (recommended)

Use this if you do not have your own internal CA. The PE console already trusts the Puppet CA, so no truststore changes are needed.

1. On the primary server, generate a certificate for the bridge host. Add alternative names for any other hostname PE might use (an alias or load balancer name):

   ```bash
   puppetserver ca generate --certname ai-bridge.example.com \
     --subject-alt-names ai-bridge.example.com,ai-bridge-alias.example.com
   ```

   `ai-bridge.example.com` is a placeholder for the bridge FQDN.
2. Find the generated certificate and private key. They are normally under the Puppet SSL directory on the primary, as `certs/<certname>.pem` and `private_keys/<certname>.pem` (default `/etc/puppetlabs/puppet/ssl/`). <!-- VERIFY: exact output paths of `puppetserver ca generate` depend on the PE version and ssldir setting -->
3. Copy the PEM contents into Hiera. The certificate is public, so a plain block scalar is fine. Encrypt the key with eyaml:

   ```bash
   eyaml encrypt -l 'ai_bridge::tls_key' -f private_keys/ai-bridge.example.com.pem
   ```

   ```yaml
   ai_bridge::tls_cert: |
     -----BEGIN CERTIFICATE-----
     ...
     -----END CERTIFICATE-----
   ai_bridge::tls_key: ENC[PKCS7,...]
   ```
4. Set the PE console URL to `https://ai-bridge.example.com:<listen_port>/v1`, using a name that appears in the certificate.
5. Verify from the primary without `-k`; this uses the same trust PE does:

   ```bash
   curl https://ai-bridge.example.com:4000/v1/models -H "Authorization: Bearer <master_key>"
   ```

   If this reports a certificate error, the PE JVM will too.

Do not paste a raw private key into unencrypted Hiera.

### Option 2: Public CA or ACME

If the bridge hostname is publicly resolvable, you can use a certificate from a public CA, for example one issued by an ACME client such as certbot or acme.sh.

1. Obtain the certificate with your ACME client of choice. The module does not run ACME or renew certificates.
2. Use the full chain file (leaf plus intermediates) as `tls_cert`, and the matching private key as `tls_key` (via eyaml).
3. The PE JVM trusts common public roots by default, so no truststore change should be needed. <!-- VERIFY: the PE console JVM truststore includes the public root used by your chosen CA -->

Public CA certificates are short-lived. Update the Hiera values on each renewal and run Puppet; the service restarts when the files change.

### Option 3: External TLS proxy (`manage_tls: false`)

Run TLS termination in front of the bridge with something you already operate (nginx, HAProxy, a load balancer) and set:

```yaml
ai_bridge::manage_tls: false
```

The bridge then serves plain HTTP on `listen_port`, and `tls_cert` and `tls_key` are not needed and not written. Keep the bridge reachable only from the proxy (for example firewall `listen_port` to the proxy host). The proxy must present a certificate the PE JVM trusts, and the PE URL points at the proxy. Whether PE accepts a plain `http://` URL directly has to be tested; do not expose the plain-HTTP port to untrusted networks, because the bearer token and prompts travel unencrypted.

### Internal CA (aside)

If you already run an internal CA, a certificate from it works the same way as Option 1, provided the PE JVM trusts that CA (or you import it into the PE console truststore).

## Parameter notes

### `personality_prompt`

When set (any non-empty string):

- Puppet writes `<install_dir>/personality.txt` (mode `0640`, diff hidden) with the text, plus `personality.py` and `personality_callback.py` (mode `0644`) from the module's `files/` directory.
- The unit mounts the three files read-only into `/app` and sets `PYTHONPATH=/app`.
- `config.yaml` registers `personality_callback.proxy_handler` under `litellm_settings.callbacks`.

When unset, Puppet removes those three files and omits the callback. The text is appended as a style supplement to the existing system message and grants no permissions. It is stored unencrypted and sent to the upstream model, so keep credentials out of it. See `docs/USER_GUIDE.md` for behavior and limits.

### `normalize_usage`

When true, Puppet copies `pe_compat.py` and `pe_usage.py` to `install_dir` (mode `0644`), mounts them into `/app`, sets `PYTHONPATH=/app`, and registers `pe_compat.proxy_handler` under `litellm_settings.callbacks`. When false, the files are not managed (they are not removed). It can be combined with `personality_prompt`; the callbacks are listed in the order `pe_compat`, then `personality_callback`.

### `extra_aliases`

Each entry becomes an additional `model_list` item. The target string is used verbatim (for example `{'o3' => 'anthropic/claude-opus-4-1'}`). Every alias reuses the primary backend's `api_key` environment reference and `api_base`, so aliases only work against the same provider and credentials.

### `container_runtime`

| Setting | Runs as | File owner | Extras |
|---------|---------|------------|--------|
| `podman` | `user` (rootless) | `user` | Puppet adds subuid/subgid ranges `200000-265535` to `user` if `/etc/subuid` has no entry |
| `docker` | `root` | `root` | Relies on the Docker daemon being present |

The unit runs the container with `--read-only`, `--tmpfs /tmp`, `--cap-drop=ALL` and `--security-opt=no-new-privileges`, and volume mounts carry the `:Z` SELinux relabel flag.

## Rendered LiteLLM `config.yaml`

`<install_dir>/config.yaml` (mode `0640`) is rendered from `templates/config.yaml.epp`. It contains no secret values, only `os.environ/` references.

| Section / key | Source |
|---------------|--------|
| `model_list[0].model_name` | `exposed_model` |
| `model_list[0].litellm_params.model` | Provider model string (see backend table) |
| `model_list[0].litellm_params.api_key` | `os.environ/<key variable>`, omitted for `ollama` |
| `model_list[0].litellm_params.api_base` | `upstream_base_url`, omitted when unset |
| Additional `model_list` entries | `extra_aliases` |
| `litellm_settings.callbacks` | Present only if `normalize_usage` or `personality_prompt` is set |
| `litellm_settings.drop_params` | `drop_params` |
| `litellm_settings.num_retries` | Fixed at `1` |
| `litellm_settings.request_timeout` | `request_timeout` |
| `litellm_settings.set_verbose` | `debug` |
| `general_settings.master_key` | `os.environ/LITELLM_MASTER_KEY` |
| `general_settings.disable_spend_logs` | Fixed at `true` |
| `general_settings.disable_master_key_return` | Fixed at `true` |

`num_retries`, `disable_spend_logs` and `disable_master_key_return` are not configurable.

## Managed files and permissions

| Path | Mode | Condition |
|------|------|-----------|
| `<install_dir>`, `<install_dir>/tls` | `0750` | `ensure: present` |
| `<install_dir>/ai_bridge.env` | `0600` | `ensure: present` |
| `<install_dir>/config.yaml` | `0640` | `ensure: present` |
| `<install_dir>/tls/server.crt` | `0644` | `manage_tls: true` |
| `<install_dir>/tls/server.key` | `0600` | `manage_tls: true` |
| `<install_dir>/pe_compat.py`, `pe_usage.py` | `0644` | `normalize_usage: true` |
| `<install_dir>/personality.txt` | `0640` | `personality_prompt` set |
| `<install_dir>/personality.py`, `personality_callback.py` | `0644` | `personality_prompt` set |
| `/etc/systemd/system/ai_bridge.service` | `0644` | Always managed; removed when `ensure: absent` |

The service user is created as a system account with shell `/sbin/nologin` and home `install_dir`.

## Required vs optional settings

| Needed for startup | Settings |
|--------------------|----------|
| Always | `master_key` |
| `backend` anthropic or openai | `upstream_api_key` |
| `backend` ollama or openai_compatible | `upstream_base_url` |
| `manage_tls: true` (default) | `tls_cert` and `tls_key` |

Everything else has a default listed in the parameter table.

## Per-environment overrides

The module ships a single Hiera level (`hiera.yaml`, `common.yaml`). Per-environment or per-node differences come from your own control repo hierarchy. A typical split:

- Common level: `backend`, `upstream_model`, `exposed_model`, `image` (pinned).
- Environment or node level: `listen_port`, `upstream_base_url`, TLS material, and the `debug` flag for a troubleshooting node.
- eyaml-encrypted level: `master_key`, `upstream_api_key`, `tls_key`.

Changing any Hiera value takes effect on the next Puppet run on the bridge host. The service is notified and restarts when config, env, TLS or callback files change.

## Bolt plan: `ai_bridge::deploy`

`plans/deploy.pp` applies the class over SSH using Docker.

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| `targets` | `TargetSpec` | none | SSH targets with systemd, Python 3 and root or sudo access |
| `config` | `Sensitive[Hash[String, Any]]` | none | Class parameters as a hash. Plain secret strings are wrapped in `Sensitive` before apply |
| `install_docker` | `Boolean` | `false` | Install `docker.io` on supported Ubuntu/Debian hosts when the `docker` executable is absent |

Plan behavior:

- `config.master_key` must be a non-empty string, or the plan fails with `config.master_key must be a non-empty string`.
- `master_key`, `upstream_api_key` (when present) and `tls_key` (when present) are wrapped in `Sensitive`.
- The plan always overrides `container_runtime` to `docker` and `manage_package` to `false`, whatever `config` contains. Docker is expected to exist already, or be installed by the `ai_bridge::docker_runtime` task.
- All other keys in `config` are passed unchanged as `ai_bridge` class parameters, so the same names and validation rules apply (including the TLS requirement).

Example `config` (JSON or YAML parameters file):

```json
{
  "targets": "bridge.example.com",
  "config": {
    "backend": "anthropic",
    "master_key": "<generated with openssl rand -hex 32>",
    "upstream_api_key": "<provider key>",
    "tls_cert": "-----BEGIN CERTIFICATE-----\n...\n-----END CERTIFICATE-----\n",
    "tls_key": "-----BEGIN PRIVATE KEY-----\n...\n-----END PRIVATE KEY-----\n"
  }
}
```

### Task: `ai_bridge::docker_runtime`

Defined in `tasks/docker_runtime.json`, input via stdin.

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| `install_docker` | `Boolean` | `false` | Install `docker.io` and enable and start Docker only when the executable is absent. Existing installations are checked, never replaced or restarted |

Installation is supported on Ubuntu 22.04/24.04 and Debian 12, and needs Python 3 and root.

## Related documentation

- `docs/USER_GUIDE.md` for step-by-step setup
- `docs/TROUBLESHOOTING.md` for error messages
- `docs/SECURITY.md` for secret handling
- `docs/BOLT_DEPLOYMENT.md` for the plan workflow
