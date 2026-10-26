"""Exercise overwrite confirmation through a controlling terminal."""

import errno
import os
from pathlib import Path
import pty
import select
import shutil
import signal
import tempfile
import time
import unittest


class ConfirmationTests(unittest.TestCase):
    def exercise(self, answer, quiet, redirected):
        library = Path(__file__).resolve().parents[2] / "dotfiles-lib.sh"
        with tempfile.TemporaryDirectory(prefix="dfl-pty-") as temporary:
            base = Path(temporary)
            home = base / "home"
            home.mkdir()
            source = base / "source"
            source.write_text("new\n")
            target = home / "config"
            target.write_text("old\n")
            output = base / "stdout"
            env = dict(os.environ, HOME=str(home), TERM="dumb",
                       DFL_PTY_LIB=str(library), DFL_PTY_SOURCE=str(source))
            env.pop("_dfl_force", None)
            env["_dfl_quiet"] = "true" if quiet else "false"
            script = 'set -euo pipefail\nsource "$DFL_PTY_LIB"\ndfl_safe_install "$DFL_PTY_SOURCE" "$HOME/config"\nprintf "completed\\n" >&2\n'
            consumer = os.environ.get("DFL_TEST_CONSUMER")
            if consumer:
                repo = base / "repo"
                category = repo / "dotfiles/pty-test"
                category.mkdir(parents=True)
                shutil.copy2(consumer, repo / "install.sh")
                shutil.copytree(Path(consumer).parent / "vendor", repo / "vendor")
                (category / "install.sh").write_text(script)
                command = ["bash", str(repo / "install.sh")]
                if quiet:
                    command.append("--quiet")
                command.append("pty-test")
            else:
                command = ["bash", "-c", script]

            pid, master = pty.fork()
            if pid == 0:
                try:
                    if redirected:
                        fd = os.open(output, os.O_WRONLY | os.O_CREAT | os.O_TRUNC, 0o600)
                        os.dup2(fd, 1)
                        os.close(fd)
                    os.execvpe(command[0], command, env)
                except BaseException:
                    os._exit(127)

            transcript = bytearray()
            sent = False
            reaped = False
            deadline = time.monotonic() + 10
            try:
                while True:
                    remaining = deadline - time.monotonic()
                    self.assertGreater(remaining, 0, "PTY timed out: " + repr(bytes(transcript)))
                    readable, _, _ = select.select([master], [], [], remaining)
                    self.assertTrue(readable, "PTY timed out: " + repr(bytes(transcript)))
                    try:
                        chunk = os.read(master, 65536)
                    except OSError as error:
                        if error.errno == errno.EIO:
                            break
                        raise
                    if not chunk:
                        break
                    transcript.extend(chunk)
                    if not sent and b"[y/N] " in transcript:
                        os.write(master, answer)
                        sent = True
                while True:
                    waited, status = os.waitpid(pid, os.WNOHANG)
                    if waited:
                        reaped = True
                        break
                    self.assertLess(time.monotonic(), deadline, "Child did not exit")
                    time.sleep(0.01)
            finally:
                if not reaped:
                    try:
                        os.killpg(pid, signal.SIGKILL)
                    except ProcessLookupError:
                        pass
                    os.waitpid(pid, 0)
                os.close(master)

            self.assertTrue(sent, bytes(transcript))
            code = os.waitstatus_to_exitcode(status)
            plain = bytes(transcript).replace(b"\r\n", b"\n")
            self.assertIn(b"--- ", plain)
            self.assertIn(b"overwrite ", plain)
            self.assertEqual(target.read_text(), "new\n" if answer == b"y\n" else "old\n")
            if answer == b"\x03":
                self.assertNotEqual(code, 0)
                self.assertNotIn(b"completed", plain)
            else:
                self.assertEqual(code, 0)
                self.assertIn(b"\ncompleted\n", plain)
            if answer == b"\x04":
                self.assertIn(b"[y/N] \ncompleted\n", plain)
            if redirected:
                captured = output.read_bytes()
                self.assertNotIn(b"overwrite ", captured)
                self.assertNotIn(b"--- ", captured)
                if quiet:
                    self.assertEqual(captured, b"")
            if quiet:
                self.assertNotIn(b"information:", plain)
                self.assertNotIn(b"warning:", plain)

    def combinations(self, answer):
        for quiet in (False, True):
            for redirected in (False, True):
                with self.subTest(quiet=quiet, redirected=redirected):
                    self.exercise(answer, quiet, redirected)

    def test_yes(self):
        self.combinations(b"y\n")

    def test_no(self):
        self.combinations(b"n\n")

    def test_ctrl_d(self):
        self.combinations(b"\x04")

    def test_ctrl_c(self):
        self.combinations(b"\x03")


if __name__ == "__main__":
    unittest.main(verbosity=2)
