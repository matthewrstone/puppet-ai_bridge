#!/usr/bin/env python3
"""Interactively create protected Bolt parameter files; run in the Bolt project."""
import getpass
import json
import os
from pathlib import Path

certificate = Path(input('Certificate chain file: ').strip()).expanduser()
private_key = Path(input('TLS private-key file: ').strip()).expanduser()
master_key = getpass.getpass('Bridge API/master key (generate and save securely first): ')
if not master_key:
    raise SystemExit('A non-empty bridge key is required')
backend_url = input('Ollama URL, e.g. http://ollama.example.net:11434: ').strip()
parameters = {
    'targets': 'ai_bridge_host',
    'install_docker': False,
    'config': {
        'master_key': master_key,
        'backend': 'ollama',
        'upstream_model': 'gemma4:12b',
        'upstream_base_url': backend_url,
        'extra_aliases': {'gpt-5.4-mini': 'ollama_chat/gemma4:12b'},
        'normalize_usage': True,
        'image': 'ghcr.io/berriai/litellm@sha256:37e2dafb088a7723beb998590682957386dfc83ffea1848486f8e0e5cfac0b06',
        'manage_tls': True,
        'tls_cert': certificate.read_text(),
        'tls_key': private_key.read_text(),
    },
}
for name, install in [('deploy-existing-docker.json', False), ('deploy-install-docker.json', True)]:
    parameters['install_docker'] = install
    fd = os.open(Path('private') / name, os.O_WRONLY | os.O_CREAT | os.O_EXCL, 0o600)
    with os.fdopen(fd, 'w') as stream:
        json.dump(parameters, stream, indent=2)
        stream.write('\n')
print('Created two protected parameter files; no secrets printed.')
