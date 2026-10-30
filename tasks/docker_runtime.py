#!/usr/bin/env python3
"""Check Docker or explicitly install a supported distribution package."""
import json
import os
from pathlib import Path
import shutil
import subprocess
import sys


def run(argv):
    result = subprocess.run(argv, text=True, stdout=subprocess.PIPE, stderr=subprocess.PIPE,
                            env={**os.environ, 'DEBIAN_FRONTEND': 'noninteractive'}, check=False)
    if result.returncode:
        raise RuntimeError('Command failed: ' + argv[0] + '. ' + result.stderr[-1500:])
    return result.stdout.strip()


def os_release():
    values = {}
    for line in Path('/etc/os-release').read_text().splitlines():
        if '=' in line:
            key, value = line.split('=', 1)
            values[key] = value.strip('"\'')
    return values


def ensure_runtime(install_docker):
    if shutil.which('docker'):
        version = run(['docker', 'info', '--format', '{{.ServerVersion}}'])
        return {'changed': False, 'runtime': 'docker', 'server_version': version}
    if not install_docker:
        raise RuntimeError('Docker not found. Install it first or set install_docker=true.')
    distro = os_release()
    if (distro.get('ID'), distro.get('VERSION_ID')) not in {
        ('ubuntu', '22.04'), ('ubuntu', '24.04'), ('debian', '12')
    }:
        raise RuntimeError('Automatic installation supports Ubuntu 22.04/24.04 and Debian 12 only. Install Docker externally and rerun.')
    if os.geteuid() != 0:
        raise RuntimeError('Docker installation requires root; configure Bolt run-as: root.')
    run(['apt-get', 'update'])
    run(['apt-get', 'install', '-y', 'docker.io'])
    run(['systemctl', 'enable', '--now', 'docker'])
    version = run(['docker', 'info', '--format', '{{.ServerVersion}}'])
    return {'changed': True, 'runtime': 'docker', 'server_version': version}


def main():
    try:
        parameters = json.load(sys.stdin)
        install = parameters.get('install_docker', False)
        if not isinstance(install, bool):
            raise ValueError('install_docker must be a boolean')
        print(json.dumps(ensure_runtime(install)))
    except Exception as exc:
        print(json.dumps({'_error': {'kind': 'ai_bridge/docker_runtime', 'msg': str(exc)}}))
        return 1
    return 0


if __name__ == '__main__':
    sys.exit(main())
