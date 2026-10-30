import contextlib
import io
import json
import os
from pathlib import Path
import runpy
import stat
import tempfile
import unittest
from unittest.mock import patch

SCRIPT = Path(__file__).resolve().parents[1] / 'examples/bolt/create_params.py'


class ParameterFileTests(unittest.TestCase):
    def test_generates_both_modes_with_private_files_and_no_secret_output(self):
        with tempfile.TemporaryDirectory() as folder:
            base = Path(folder)
            (base / 'private').mkdir(mode=0o700)
            (base / 'chain.pem').write_text('test-chain')
            (base / 'key.pem').write_text('test-private-key')
            output = io.StringIO()
            previous = Path.cwd()
            try:
                os.chdir(base)
                with patch('builtins.input', side_effect=['chain.pem', 'key.pem', 'http://ollama.example.net:11434']), patch('getpass.getpass', return_value='test-master-secret'), contextlib.redirect_stdout(output):
                    runpy.run_path(str(SCRIPT))
                for filename, install in [('deploy-existing-docker.json', False), ('deploy-install-docker.json', True)]:
                    path = base / 'private' / filename
                    data = json.loads(path.read_text())
                    self.assertIs(data['install_docker'], install)
                    self.assertEqual(stat.S_IMODE(path.stat().st_mode), 0o600)
                    self.assertEqual(data['config']['master_key'], 'test-master-secret')
                    self.assertEqual(data['config']['tls_key'], 'test-private-key')
                self.assertNotIn('test-master-secret', output.getvalue())
                self.assertNotIn('test-private-key', output.getvalue())
            finally:
                os.chdir(previous)


if __name__ == '__main__': unittest.main()
