# @summary Creates the service user, directories and container runtime.
# @api private
class ai_bridge::install {
  $user        = $ai_bridge::user
  $install_dir = $ai_bridge::install_dir
  $file_owner  = $ai_bridge::container_runtime ? {
    'docker' => 'root',
    default  => $user,
  }

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
    owner  => $file_owner,
    group  => $file_owner,
    mode   => '0750',
  }

  # Rootless podman needs sub-id ranges for the service user.
  if $ai_bridge::container_runtime == 'podman' {
    exec { "ai_bridge-subids-${user}":
      command => "/usr/sbin/usermod --add-subuids 200000-265535 --add-subgids 200000-265535 ${user}",
      unless  => "/bin/grep -q '^${user}:' /etc/subuid",
      require => User[$user],
    }

    # The service user is a nologin system account with no systemd user session, so
    # Podman's default systemd cgroup manager and journald events cannot work for it.
    # Setting them here covers every podman command run as this user (the unit and
    # manual `sudo -u <user> podman ...` debugging), not only the unit's ExecStart lines.
    file { ["${install_dir}/.config", "${install_dir}/.config/containers"]:
      ensure => directory,
      owner  => $user,
      group  => $user,
      mode   => '0750',
    }

    file { "${install_dir}/.config/containers/containers.conf":
      ensure  => file,
      owner   => $user,
      group   => $user,
      mode    => '0644',
      content => @(CONF),
        # Managed by Puppet (ai_bridge)
        # No systemd user session exists for this account: use cgroupfs and file events.
        [engine]
        cgroup_manager = "cgroupfs"
        events_logger = "file"
        | CONF
    }
  }
}
