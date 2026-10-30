# @summary Deploy ai_bridge using Docker, optionally installing the runtime first.
# @param targets SSH targets with systemd, Python 3 and root/sudo access.
# @param config Class parameters; plain secret strings are wrapped before apply.
# @param install_docker Install docker.io on supported Ubuntu/Debian if missing.
plan ai_bridge::deploy (
  TargetSpec $targets,
  Sensitive[Hash[String, Any]] $config,
  Boolean $install_docker = false,
) {
  $raw = $config.unwrap
  if !('master_key' in $raw) or $raw['master_key'] !~ String[1] {
    fail('config.master_key must be a non-empty string')
  }
  $upstream_key = 'upstream_api_key' in $raw ? {
    true    => Sensitive($raw['upstream_api_key']),
    default => undef,
  }
  $tls_key = 'tls_key' in $raw ? {
    true    => Sensitive($raw['tls_key']),
    default => undef,
  }
  $settings = $raw + {
    'master_key'        => Sensitive($raw['master_key']),
    'upstream_api_key'  => $upstream_key,
    'tls_key'           => $tls_key,
    'container_runtime' => 'docker',
    'manage_package'    => false,
  }

  run_task('ai_bridge::docker_runtime', $targets, 'install_docker' => $install_docker)
  apply_prep($targets)
  $result = apply($targets) {
    class { 'ai_bridge':
      * => $settings,
    }
  }
  return($result)
}
