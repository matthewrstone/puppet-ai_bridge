# Deploy ai_bridge with Bolt

The `ai_bridge::deploy` plan deploys the same Puppet class used by a normal
agent run. It uses Docker in two modes:

| Situation | `install_docker` | Behavior |
|---|---|---|
| Docker already installed | `false` (default) | Require a working Docker daemon. No package or daemon changes. |
| Docker missing | `true` | Install the distribution's `docker.io` package, enable/start Docker, then deploy the bridge. |

Existing installations are never replaced by the runtime task. If an existing
Docker executable cannot reach its daemon, the plan fails; repair that installation
before retrying. The bridge's own container is managed/restarted by the module.

## Requirements

- Bolt on your workstation; plan/task discovery was checked with Bolt 5.2.0.
- Linux target with systemd, Python 3, SSH, and root or passwordless sudo access.
- Automatic Docker installation supports Ubuntu 22.04/24.04 and Debian 12.
  Other distributions require Docker to be installed and managed externally.
- Targets need access to their approved package repositories and the selected
  container registry. The bridge needs access to the chosen LLM backend.
- A certificate chain and matching key for the bridge hostname, trusted by PE.
  The plan keeps TLS enabled by default. It does not issue certificates, configure
  DNS/firewalls, join PE, accept AI usage terms, or change PE's provider settings.
- `apply_prep` installs Puppet Agent if it is missing, using Bolt's agent installer,
  and gathers facts. Review and satisfy the vendor's repository/license requirements
  first. Existing PE-managed targets should already have their agent installed.

**Choose one configuration owner.** Do not let a PE classification and this
standalone Bolt apply manage the same bridge with different settings. For
PE-managed targets, align the class parameters with Hiera or deploy through PE.
Bolt does not remove the existing agent or enroll a target in PE.

## 1. Create a Bolt project

```sh
mkdir -p bolt-ai-bridge/modules
cd bolt-ai-bridge
git clone https://github.com/matthewrstone/puppet-ai_bridge.git modules/ai_bridge
cp modules/ai_bridge/examples/bolt/bolt-project.yaml .
cp modules/ai_bridge/examples/bolt/inventory.yaml .
printf '\nprivate/\n.bolt/\n' >> .gitignore
```

Use a reviewed revision containing `plans/deploy.pp`; until these commits are
pushed, copy the local module checkout into `modules/ai_bridge` instead of cloning
the earlier remote revision. Keep the directory name **ai_bridge**, regardless of
the Git repository's name. No external Puppet module dependency is required by
this plan; Bolt supplies its apply helpers.

Edit `inventory.yaml`: replace hostname, SSH user and key path. Verify the SSH
host key through a trusted channel and populate your normal `known_hosts` file.
Do not disable host-key checking. Then check connectivity and discovery:

```sh
bolt command run 'id -u' --targets ai_bridge_host
bolt plan show ai_bridge::deploy
bolt task show ai_bridge::docker_runtime
```

`id -u` should return `0` under the configured `run-as: root` setting.

## 2. Create protected deployment parameters

The plan takes `targets`, a sensitive `config` hash containing class parameters,
and `install_docker`. Secrets are plain strings in the protected input file;
the plan wraps them as Puppet `Sensitive` values before applying the class.
Do not pass keys on the command line, commit the input files, or enable debug
logging. The files still contain real secrets: protect them like credentials.

Example for local Ollama/Gemma. Run from the Bolt project directory:

```sh
mkdir -p private
chmod 700 private
python3 modules/ai_bridge/examples/bolt/create_params.py
```

The script refuses to overwrite existing credential files. To use Anthropic or
OpenAI, set `backend`, `upstream_model`, and `upstream_api_key` in the protected
configuration; remove the Ollama URL and update aliases to the correct
`anthropic/model` or `openai/model`. For `openai_compatible`, provide its base
URL and optional upstream key. `normalize_usage` is an opt-in PE compatibility
workaround; zero detail counts represent unreported statistics.

The pinned image above is the lab-tested artifact, not a promise of ongoing
security support. Review an image before upgrading and retest callback support.

## 3. Deploy: choose one command

**Docker already installed:**

```sh
bolt plan run ai_bridge::deploy --params @private/deploy-existing-docker.json
```

**Install Docker if missing, then deploy:**

```sh
bolt plan run ai_bridge::deploy --params @private/deploy-install-docker.json
```

The second mode uses `apt-get update`, `apt-get install -y docker.io`, and
`systemctl enable --now docker` only if no Docker executable exists. It does not
run a downloaded convenience script or switch existing hosts to Docker CE.
Package installation may refresh package indexes and install distro dependencies.
It does not automatically upgrade an existing runtime.

The plan forces `container_runtime: docker` and `manage_package: false` on the
class, overriding those fields in `config`, because the runtime task owns that
step. Other class parameters such as aliases, image, timeouts and TLS are passed
through. A failed task stops the plan before applying the bridge.

## 4. Verify and connect PE

```sh
bolt command run 'systemctl is-active ai_bridge' --targets ai_bridge_host
bolt command run 'docker ps --filter name=ai_bridge --format "{{.Names}} {{.Status}}"' --targets ai_bridge_host
```

Do not dump container environment/configuration or use `docker inspect` in shared
logs: the deployment includes credentials. Check the authenticated `/v1/models`
endpoint from the PE host using the bridge key through your normal secret-aware
tooling; verify certificate trust and hostname normally.

In PE's Infra Assist provider settings, choose the OpenAI-compatible option,
set `https://BRIDGE_HOSTNAME:4000/v1`, and enter the bridge master key. Ensure PE
can reach that port and trusts the certificate issuer. If terminating TLS on an
external proxy, configure it separately and use that HTTPS URL; `manage_tls: false`
exposes plain HTTP on the bridge port and requires appropriate network isolation.
No MCP service is enabled by this plan.

Ask a read-only question in a fresh conversation. Confirm both an answer and the
end of “Thinking” before treating browser UAT as passed. A healthy container alone
does not prove provider reachability, tool compatibility or response quality.

## Runtime task alone

Read-only existing-Docker check:

```sh
bolt task run ai_bridge::docker_runtime --targets ai_bridge_host
```

Explicit Docker bootstrap on a supported OS:

```sh
bolt task run ai_bridge::docker_runtime install_docker=true --targets ai_bridge_host
```

This task does **not** deploy the bridge; use the plan for that. There is no
simulation flag: task execution is real. Test the installation path on a disposable
host before using it on a shared Docker server.

## Validation boundary

Unit tests cover missing/existing Docker, explicit install consent, supported
platform gating and daemon failure. Bolt plan tests cover default/explicit mode,
missing-key rejection and stopping on runtime failure. Plan/task discovery was
checked locally. Fresh-host Bolt installation and an end-to-end live plan apply
have not yet been performed; they remain release/UAT gates in the readiness report.

References: [Bolt plan functions](https://help.puppet.com/bolt/current/topics/plan_functions.htm)
and [sensitive plan parameters](https://help.puppet.com/bolt/current/topics/writing_plans.htm).
