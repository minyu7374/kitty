import json
import os
from pathlib import Path
import subprocess
import tempfile
import unittest


class NavigationTests(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.addCleanup(self.tmp.cleanup)
        self.root = Path(self.tmp.name)
        self.fake = self.root / "herdr"
        self.fake.write_text('''#!/usr/bin/env python3
import json, os, sys
with open(os.environ['CALL_LOG'], 'a') as f:
    f.write(json.dumps(sys.argv[1:]) + '\\n')
cmd = sys.argv[2]
if cmd == 'process-info':
    print(json.dumps({'result': {'process_info': {'foreground_processes': [{'name': os.environ['FOREGROUND']}]}}}))
elif cmd == 'focus':
    if os.environ.get('FOCUS_ERROR'): sys.exit(1)
    if os.environ.get('MALFORMED'): print('invalid'); sys.exit(0)
    changed = os.environ.get('CHANGED') == 'true'
    print(json.dumps({'result': {'focus': {'changed': changed, 'reason': None if changed else 'no_neighbor'}}}))
''')
        self.fake.chmod(0o755)
        kitten = self.root / "kitten"
        kitten.write_text('''#!/usr/bin/env python3
import json, os, sys
with open(os.environ['KITTY_CALL_LOG'], 'a') as f:
    f.write(json.dumps(sys.argv[1:]) + '\\n')
sys.exit(int(os.environ.get('KITTY_EXIT', '0')))
''')
        kitten.chmod(0o755)
        self.env = dict(os.environ, HERDR_PANE_ID="w1:p2", HERDR_BIN_PATH=str(self.fake),
                        CALL_LOG=str(self.root / "calls"), FOREGROUND="zsh",
                        KITTY_CALL_LOG=str(self.root / "kitty-calls"))
        self.env["XDG_RUNTIME_DIR"] = str(self.root)
        (self.root / "smart-splits-herdr-kitty").write_text("unix:/tmp/current-kitty\n17\n")
        self.env.pop("KITTY_LISTEN_ON", None)
        self.env["PATH"] = str(self.root) + os.pathsep + self.env["PATH"]

    def invoke(self, direction="left"):
        script = Path(__file__).resolve().parents[1] / "scripts/herdr-navigate.sh"
        result = subprocess.run(["bash", str(script), direction], env=self.env,
                                capture_output=True, text=True, timeout=3)
        self.assertEqual(result.returncode, 0, result.stderr)
        return [json.loads(line) for line in (self.root / "calls").read_text().splitlines()]

    def test_nvim_receives_navigation_key_without_moving_herdr(self):
        self.env["FOREGROUND"] = "nvim"
        calls = self.invoke()
        self.assertEqual(calls[-1], ["pane", "send-keys", "w1:p2", "ctrl+h"])
        self.assertFalse(any(call[1] == "focus" for call in calls))

    def test_custom_command_context_uses_active_pane(self):
        del self.env["HERDR_PANE_ID"]
        self.env["HERDR_ACTIVE_PANE_ID"] = "w1:p2"
        self.env["FOREGROUND"] = "vim"
        calls = self.invoke("down")
        self.assertEqual(calls[0], ["pane", "process-info", "--pane", "w1:p2"])
        self.assertEqual(calls[-1], ["pane", "send-keys", "w1:p2", "ctrl+j"])

    def test_shell_neighbor_moves_focus_without_sending_key(self):
        self.env["CHANGED"] = "true"
        calls = self.invoke("right")
        self.assertEqual(calls[-1], ["pane", "focus", "--direction", "right", "--pane", "w1:p2"])

    def test_shell_at_edge_keeps_clear_screen_key(self):
        calls = self.invoke("right")
        self.assertEqual(calls[-1], ["pane", "send-keys", "w1:p2", "ctrl+l"])

    def test_herdr_edge_moves_to_outer_kitty_in_each_direction(self):
        self.env["KITTY_LISTEN_ON"] = "unix:/tmp/kitty-test"
        for direction, neighbor in [("left", "left"), ("right", "right"),
                                    ("up", "top"), ("down", "bottom")]:
            with self.subTest(direction=direction):
                calls = self.invoke(direction)
                self.assertFalse(any(call[1] == "send-keys" for call in calls))
                kitty_calls = [json.loads(line) for line in (self.root / "kitty-calls").read_text().splitlines()]
                self.assertEqual(kitty_calls[-1], ["@", "--to", "unix:/tmp/current-kitty", "focus-window", "--match", "neighbor:" + neighbor])

    def test_outer_kitty_edge_keeps_shell_clear_screen_key(self):
        self.env.update(KITTY_LISTEN_ON="unix:/tmp/kitty-test", KITTY_EXIT="1")
        calls = self.invoke("right")
        self.assertTrue((self.root / "kitty-calls").exists())
        self.assertEqual(calls[-1], ["pane", "send-keys", "w1:p2", "ctrl+l"])

    def test_herdr_neighbor_takes_priority_over_outer_kitty(self):
        self.env.update(KITTY_LISTEN_ON="unix:/tmp/kitty-test", CHANGED="true")
        self.invoke("right")
        self.assertFalse((self.root / "kitty-calls").exists())

    def test_failed_or_malformed_focus_falls_back_to_key(self):
        self.env["KITTY_LISTEN_ON"] = "unix:/tmp/kitty-test"
        for flag in ["FOCUS_ERROR", "MALFORMED"]:
            with self.subTest(flag=flag):
                self.env[flag] = "1"
                calls = self.invoke("up")
                self.assertEqual(calls[-1], ["pane", "send-keys", "w1:p2", "ctrl+k"])
                self.assertFalse((self.root / "kitty-calls").exists())
                del self.env[flag]


if __name__ == "__main__":
    unittest.main()
