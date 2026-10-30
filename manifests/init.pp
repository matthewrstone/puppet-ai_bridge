# @summary Deploys an OpenAI-compatible bridge (LiteLLM) so Puppet Enterprise's
#   AI Agent can keep asking for `o4-mini` while Claude, a current OpenAI model,
#   Ollama or any OpenAI-compatible server actually answers.
#
# @example Claude behind the bridge (Hiera)
#   ai_bridge::backend: anthropic
#   ai_bridge::upstream_model: claude-sonnet-4-5
#   ai_bridge::upstream_api_key: ENC[PKCS7,...]
#   ai_bridge::master_key: ENC[PKCS7,...]
#   ai_bridge::tls_cert: "%{lookup('profile::certs::ai_bridge_cert')}"
#   ai_bridge::tls_key: ENC[PKCS7,...]
#
# @example Local Ollama model
#   ai_bridge::backend: ollama
#   ai_bridge::upstream_model: 'qwen3:32b'
#   ai_bridge::upstream_base_url: http://ollama.souldo.lan:11434
#
# @param ensure
#   `present` deploys and runs the bridge; `absent` stops it and removes all files.
# @param backend
#   Which provider answers. See `Ai_bridge::Backend`.
# @param upstream_model
#   Provider-side model name, e.g. `claude-sonnet-4-5`, `gpt-5-mini`, `qwen3:32b`.
# @param upstream_api_key
#   Provider API key. Required for anthropic/openai; optional for openai_compatible;
#   ignored for ollama. Must be `Sensitive`.
# @param upstream_base_url
#   Base URL of the provider. Required for ollama (e.g. `http://host:11434`) and
#   openai_compatible (e.g. `http://host:8000/v1`).
# @param master_key
#   The bearer token PE must present. This is what you paste into the PE console's
#   "API key" field. Generate with `openssl rand -hex 32`. Must be `Sensitive`.
# @param exposed_model
#   The model name PE asks for. PE hard-codes `o4-mini`; change only if PE changes.
# @param normalize_usage
#   Opt-in PE usage-detail compatibility defaults; unreported detail fields become zero.
# @param personality_prompt
#   Optional response style text appended to chat system instructions. No permissions granted.
# @param extra_aliases
#   Additional `{ exposed_name => 'provider/model' }` entries, rendered verbatim
#   as LiteLLM model strings (e.g. `{'o3' => 'anthropic/claude-opus-4-1'}`). They
#   reuse the same api key / api_base as the primary backend.
# @param listen_port
#   TCP port the bridge listens on. PE URL becomes `https://<host>:<port>/v1`.
# @param manage_tls
#   Terminate TLS in the bridge. Strongly recommended; PE's JVM must trust the cert.
# @param tls_cert
#   PEM certificate (chain) contents. Required when `manage_tls` is true.
# @param tls_key
#   PEM private key contents, `Sensitive`. Required when `manage_tls` is true.
# @param container_runtime
#   `podman` (default, runs rootless as the ai_bridge user) or `docker` (runs as root).
# @param image
#   LiteLLM container image. Pin a tag/digest in production.
# @param install_dir
#   Where config, env and TLS material live.
# @param user
#   System user that owns files and (with podman) runs the container.
# @param drop_params
#   Strip request params the backend doesn't support instead of failing. PE treats
#   o4-mini as a reasoning model and may send `reasoning_effort` etc. Keep true.
# @param request_timeout
#   Seconds LiteLLM waits for the provider.
# @param debug
#   Sets `LITELLM_LOG=DEBUG`. Logs full prompts — troubleshooting only.
# @param manage_package
#   Install the container runtime package.
# @param service_ensure
#   Service state when `ensure` is present.
class ai_bridge (
  Sensitive[String[1]]           $master_key,
  Enum['present', 'absent']      $ensure            = 'present',
  Ai_bridge::Backend             $backend           = 'anthropic',
  String[1]                      $upstream_model    = 'claude-sonnet-4-5',
  Optional[Sensitive[String[1]]] $upstream_api_key  = undef,
  Optional[Ai_bridge::Url]     $upstream_base_url = undef,
  String[1]                      $exposed_model     = 'o4-mini',
  Hash[String[1], String[1]]     $extra_aliases     = {},
  Ai_bridge::Port              $listen_port       = 4000,
  Boolean                        $manage_tls        = true,
  Optional[String[1]]            $tls_cert          = undef,
  Optional[Sensitive[String[1]]] $tls_key           = undef,
  Enum['podman', 'docker']       $container_runtime = 'podman',
  String[1]                      $image             = 'ghcr.io/berriai/litellm:main-stable',
  Ai_bridge::Absolutepath      $install_dir       = '/opt/ai_bridge',
  String[1]                      $user              = 'ai_bridge',
  Boolean                        $drop_params       = true,
  Integer[1]                     $request_timeout   = 300,
  Boolean                        $debug             = false,
  Boolean                        $normalize_usage   = false,
  Optional[String[1]]            $personality_prompt = undef,
  Boolean                        $manage_package    = true,
  Enum['running', 'stopped']     $service_ensure    = 'running',
) {
  # ---- Validation: fail at compile time, not at 3am ------------------------
  if $backend in ['anthropic', 'openai'] and !$upstream_api_key {
    fail("ai_bridge: upstream_api_key is required when backend is '${backend}'")
  }
  if $backend in ['ollama', 'openai_compatible'] and !$upstream_base_url {
    fail("ai_bridge: upstream_base_url is required when backend is '${backend}'")
  }
  if $manage_tls and $ensure == 'present' and (!$tls_cert or !$tls_key) {
    fail('ai_bridge: tls_cert and tls_key are required when manage_tls is true (set manage_tls: false to run plain HTTP)')
  }

  # Provider-prefixed model string and the env var LiteLLM reads the key from.
  $provider_model = $backend ? {
    'anthropic'         => "anthropic/${upstream_model}",
    'openai'            => "openai/${upstream_model}",
    'ollama'            => "ollama_chat/${upstream_model}",
    'openai_compatible' => "openai/${upstream_model}",
  }
  $key_env = $backend ? {
    'anthropic'         => 'ANTHROPIC_API_KEY',
    'openai'            => 'OPENAI_API_KEY',
    'openai_compatible' => 'UPSTREAM_API_KEY',
    default             => undef,
  }

  if $ensure == 'present' {
    contain ai_bridge::install
    contain ai_bridge::config
    contain ai_bridge::service

    Class['ai_bridge::install']
    -> Class['ai_bridge::config']
    ~> Class['ai_bridge::service']
  } else {
    contain ai_bridge::service
    contain ai_bridge::config

    Class['ai_bridge::service']
    -> Class['ai_bridge::config']
  }
}
