# Minimal manifest-driven example (prefer Hiera in real use).
class { 'ai_bridge':
  backend           => 'openai_compatible',
  upstream_model    => 'Qwen/Qwen3-32B',
  upstream_base_url => 'http://vllm.souldo.lan:8000/v1',
  master_key        => Sensitive('replace-me'),
  manage_tls        => false, # behind another TLS terminator
}
