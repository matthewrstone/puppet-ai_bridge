import importlib.util
from pathlib import Path
import unittest
from unittest.mock import patch

PATH = Path(__file__).resolve().parents[1] / 'tasks/docker_runtime.py'


class RuntimeTests(unittest.TestCase):
    def setUp(self):
        self.assertTrue(PATH.exists(), 'Docker runtime task must exist')
        spec = importlib.util.spec_from_file_location('docker_runtime', PATH)
        self.task = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(self.task)

    def test_existing_docker_is_checked_without_package_changes(self):
        with patch.object(self.task.shutil, 'which', return_value='/usr/bin/docker'), patch.object(self.task, 'run') as run:
            result = self.task.ensure_runtime(False)
        self.assertFalse(result['changed'])
        self.assertEqual(run.call_args_list[0].args[0], ['docker', 'info', '--format', '{{.ServerVersion}}'])
        self.assertEqual(run.call_count, 1)

    def test_missing_docker_requires_explicit_install(self):
        with patch.object(self.task.shutil, 'which', return_value=None), patch.object(self.task, 'run') as run:
            with self.assertRaisesRegex(RuntimeError, 'install_docker'):
                self.task.ensure_runtime(False)
        run.assert_not_called()

    def test_install_uses_distro_package_and_starts_service(self):
        with patch.object(self.task.shutil, 'which', return_value=None), patch.object(self.task, 'os_release', return_value={'ID':'ubuntu', 'VERSION_ID':'24.04'}), patch.object(self.task.os, 'geteuid', return_value=0), patch.object(self.task, 'run') as run:
            result = self.task.ensure_runtime(True)
        self.assertTrue(result['changed'])
        commands = [c.args[0] for c in run.call_args_list]
        self.assertEqual(commands, [['apt-get', 'update'], ['apt-get', 'install', '-y', 'docker.io'], ['systemctl', 'enable', '--now', 'docker'], ['docker', 'info', '--format', '{{.ServerVersion}}']])

    def test_unsupported_os_fails_before_mutation(self):
        with patch.object(self.task.shutil, 'which', return_value=None), patch.object(self.task, 'os_release', return_value={'ID':'rocky', 'VERSION_ID':'9'}), patch.object(self.task, 'run') as run:
            with self.assertRaisesRegex(RuntimeError, 'Ubuntu.*Debian'):
                self.task.ensure_runtime(True)
        run.assert_not_called()

    def test_existing_broken_daemon_is_not_reconfigured(self):
        with patch.object(self.task.shutil, 'which', return_value='/usr/bin/docker'), patch.object(self.task, 'run', side_effect=RuntimeError('daemon unavailable')) as run:
            with self.assertRaisesRegex(RuntimeError, 'daemon unavailable'):
                self.task.ensure_runtime(True)
        self.assertEqual(run.call_count, 1)


if __name__ == '__main__': unittest.main()
