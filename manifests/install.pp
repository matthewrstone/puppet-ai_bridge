# @summary Creates the service user, directories and container runtime.
# @api private
class ai_bridge::install {
  $user        = $ai_bridge::user
  $install_dir = $ai_bridge::install_dir

  group { $user:
    ensure => present,
    system => true,
  }

  user { $user:
    ensure     => present,
    system     => true,
    gid        => $user,
    home       => $install_dir,
    managehome => false,
    shell      => '/sbin/nologin',
    comment    => 'ai_bridge LiteLLM service account',
  }

  if $ai_bridge::manage_package {
    package { $ai_bridge::container_runtime:
      ensure => installed,
    }
  }

  file { [$install_dir, "${install_dir}/tls"]:
    ensure => directory,
    owner  => $user,
    group  => $user,
    mode   => '0750',
  }

  # Rootless podman needs sub-id ranges for the service user.
  if $ai_bridge::container_runtime == 'podman' {
    exec { "ai_bridge-subids-${user}":
      command => "/usr/sbin/usermod --add-subuids 200000-265535 --add-subgids 200000-265535 ${user}",
      unless  => "/bin/grep -q '^${user}:' /etc/subuid",
      require => User[$user],
    }
  }
}
