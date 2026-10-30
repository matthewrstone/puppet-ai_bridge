# @summary Renders LiteLLM config, the secrets env file and TLS material.
# @api private
class ai_bridge::config {
  $user        = $ai_bridge::container_runtime ? {
    'docker' => 'root',
    default  => $ai_bridge::user,
  }
  $install_dir = $ai_bridge::install_dir
  $ensure      = $ai_bridge::ensure

  if $ensure == 'absent' {
    file { $install_dir:
      ensure => absent,
      force  => true,
    }
  } else {
    # ---- Secrets: one env file, 0600, never diffed -----------------------
    $upstream_key_value = $ai_bridge::upstream_api_key ? {
      undef   => undef,
      default => $ai_bridge::upstream_api_key.unwrap,
    }
    $env_content = epp('ai_bridge/ai_bridge.env.epp', {
        master_key   => $ai_bridge::master_key.unwrap,
        key_env      => $ai_bridge::key_env,
        upstream_key => $upstream_key_value,
        debug        => $ai_bridge::debug,
    })

    file { "${install_dir}/ai_bridge.env":
      ensure    => file,
      owner     => $user,
      group     => $user,
      mode      => '0600',
      content   => Sensitive($env_content),
      show_diff => false,
    }

    # ---- LiteLLM config: no secret values, only os.environ/ references ----
    file { "${install_dir}/config.yaml":
      ensure  => file,
      owner   => $user,
      group   => $user,
      mode    => '0640',
      content => epp('ai_bridge/config.yaml.epp', {
          exposed_model     => $ai_bridge::exposed_model,
          provider_model    => $ai_bridge::provider_model,
          key_env           => $ai_bridge::key_env,
          upstream_base_url => $ai_bridge::upstream_base_url,
          extra_aliases     => $ai_bridge::extra_aliases,
          drop_params       => $ai_bridge::drop_params,
          request_timeout   => $ai_bridge::request_timeout,
          debug             => $ai_bridge::debug,
          normalize_usage   => $ai_bridge::normalize_usage,
          personality       => $ai_bridge::personality_prompt != undef,
      }),
    }

    if $ai_bridge::normalize_usage {
      file { "${install_dir}/pe_compat.py":
        ensure => file,
        owner  => $user,
        group  => $user,
        mode   => '0644',
        source => 'puppet:///modules/ai_bridge/pe_compat.py',
      }
      file { "${install_dir}/pe_usage.py":
        ensure => file,
        owner  => $user,
        group  => $user,
        mode   => '0644',
        source => 'puppet:///modules/ai_bridge/pe_usage.py',
      }
    }

    if $ai_bridge::personality_prompt != undef {
      file { "${install_dir}/personality.txt":
        ensure    => file,
        owner     => $user,
        group     => $user,
        mode      => '0640',
        content   => $ai_bridge::personality_prompt,
        show_diff => false,
      }
      ['personality.py', 'personality_callback.py'].each |$filename| {
        file { "${install_dir}/${filename}":
          ensure => file,
          owner  => $user,
          group  => $user,
          mode   => '0644',
          source => "puppet:///modules/ai_bridge/${filename}",
        }
      }
    } else {
      ['personality.txt', 'personality.py', 'personality_callback.py'].each |$filename| {
        file { "${install_dir}/${filename}":
          ensure => absent,
        }
      }
    }

    # ---- TLS -----------------------------------------------------------------
    if $ai_bridge::manage_tls {
      file { "${install_dir}/tls/server.crt":
        ensure  => file,
        owner   => $user,
        group   => $user,
        mode    => '0644',
        content => $ai_bridge::tls_cert,
      }
      file { "${install_dir}/tls/server.key":
        ensure    => file,
        owner     => $user,
        group     => $user,
        mode      => '0600',
        content   => $ai_bridge::tls_key,
        show_diff => false,
      }
    }
  }
}
