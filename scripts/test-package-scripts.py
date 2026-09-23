#!/usr/bin/env python3
"""Exercise real maintainer scripts with mocked commands and a Sileo pipe."""
import os
from pathlib import Path
import subprocess
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[1]

class MaintainerScriptTests(unittest.TestCase):
    def run_script(self, name, action, finish_env=None):
        with tempfile.TemporaryDirectory() as temp:
            base = Path(temp)
            log = base / 'commands'
            for command in ('killall', 'uicache'):
                mock = base / command
                mock.write_text('#!/bin/sh\nprintf "%s\\n" "' + command + ' $*" >> "$NFCCARD_TEST_LOG"\n')
                mock.chmod(0o755)
            read_fd, write_fd = os.pipe()
            env = {'PATH': str(base), 'NFCCARD_TEST_LOG': str(log)}
            if finish_env:
                key, value = finish_env
                env[key] = value.format(fd=write_fd)
            try:
                result = subprocess.run(['/bin/sh', str(ROOT / 'packaging' / name), action], env=env,
                                        pass_fds=(write_fd,), capture_output=True, timeout=5)
            finally:
                os.close(write_fd)
            finish = os.read(read_fd, 1024).decode()
            os.close(read_fd)
            self.assertEqual(result.returncode, 0, result.stderr.decode())
            commands = log.read_text() if log.exists() else ''
            return commands, finish

    def test_sileo_install_requests_restart_and_updates_registration(self):
        commands, finish = self.run_script('postinst', 'configure', ('SILEO', '{fd} 1'))
        self.assertEqual(finish, 'finish:restart\n')
        self.assertIn('killall -TERM NFCCard', commands)
        self.assertIn('uicache -p /var/jb/Applications/NFCCard.app', commands)
        self.assertNotIn('killall SpringBoard', commands)

    def test_cydia_pipe_is_supported(self):
        self.assertEqual(self.run_script('postinst', 'configure', ('CYDIA', '{fd} 1'))[1], 'finish:restart\n')

    def test_terminal_install_without_pipe_succeeds(self):
        self.assertEqual(self.run_script('postinst', 'configure')[1], '')

    def test_invalid_pipe_is_not_evaluated(self):
        self.assertEqual(self.run_script('postinst', 'configure', ('SILEO', 'invalid;exit'))[1], '')

    def test_abort_does_not_request_restart(self):
        self.assertEqual(self.run_script('postinst', 'abort-upgrade', ('SILEO', '{fd} 1')), ('', ''))

    def test_removal_stops_only_app_and_unregisters_its_path(self):
        commands, _ = self.run_script('prerm', 'remove')
        self.assertIn('killall -TERM NFCCard', commands)
        self.assertIn('uicache -u /var/jb/Applications/NFCCard.app', commands)

    def test_upgrade_stops_old_app_without_unregistering(self):
        commands, _ = self.run_script('prerm', 'upgrade')
        self.assertIn('killall -TERM NFCCard', commands)
        self.assertNotIn('uicache', commands)

if __name__ == '__main__':
    unittest.main()
