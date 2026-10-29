# @summary systemd unit that runs the LiteLLM container.
# @api private
class ai_bridge::service {
  $ensure  = $ai_bridge::ensure
  $runtime = $ai_bridge::container_runtime

  # Docker's daemon runs as root and its socket is root-owned; podman is rootless.
  $unit_user = $runtime ? {
    'podman' => $ai_bridge::user,
    'docker' => 'root',
  }

  $unit_ensure = $ensure ? {
    'present' => 'file',
    'absent'  => 'absent',
  }

  file { '/etc/systemd/system/ai_bridge.service':
    ensure  => $unit_ensure,
    owner   => 'root',
    group   => 'root',
    mode    => '0644',
    content => epp('ai_bridge/ai_bridge.service.epp', {
        runtime     => $runtime,
        unit_user   => $unit_user,
        install_dir => $ai_bridge::install_dir,
        image       => $ai_bridge::image,
        port        => $ai_bridge::listen_port,
        manage_tls  => $ai_bridge::manage_tls,
    }),
    notify  => Exec['ai_bridge-systemd-reload'],
  }

  exec { 'ai_bridge-systemd-reload':
    command     => '/bin/systemctl daemon-reload',
    refreshonly => true,
  }

  if $ensure == 'present' {
    service { 'ai_bridge':
      ensure    => $ai_bridge::service_ensure,
      enable    => true,
      subscribe => Exec['ai_bridge-systemd-reload'],
    }
  } else {
    service { 'ai_bridge':
      ensure => stopped,
      enable => false,
      before => File['/etc/systemd/system/ai_bridge.service'],
    }
  }
}
