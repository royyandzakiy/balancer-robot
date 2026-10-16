"""E2E test: drives the real app through Spix (XML-RPC), like a user clicking.

Needs an ENABLE_SPIX=ON build. ctest runs it automatically; by hand:
    python test/e2e/test_counter_e2e.py --app bin/clang-cl-debug/qt_qml_simple_hello.exe
Standard library only (unittest + xmlrpc), so no pip install needed.
"""

import argparse
import os
import subprocess
import sys
import time
import unittest
import xmlrpc.client

APP = None
PORT = int(os.environ.get("SPIX_PORT", "9000"))


def wait_for_spix(proxy, path, timeout_s=20.0):
    """Polls until the app's Spix server answers and `path` is on screen."""
    deadline = time.monotonic() + timeout_s
    while time.monotonic() < deadline:
        try:
            if proxy.existsAndVisible(path):
                return
        except (ConnectionError, OSError, xmlrpc.client.Fault):
            pass  # app still starting
        time.sleep(0.2)
    raise TimeoutError(f"Spix server on port {PORT} not ready or '{path}' not visible after {timeout_s}s")


class CounterE2E(unittest.TestCase):
    def setUp(self):
        env = dict(os.environ, SPIX_PORT=str(PORT))
        self.app = subprocess.Popen([APP], env=env)
        self.spix = xmlrpc.client.ServerProxy(f"http://localhost:{PORT}")
        # addCleanup, not tearDown: tearDown is skipped when setUp fails, which would leave the app
        # running and hang ctest on its open output pipe.
        self.addCleanup(self.stop_app)
        wait_for_spix(self.spix, "mainWindow/incrementButton")

    def stop_app(self):
        try:
            self.spix.quit()
        except (ConnectionError, OSError, xmlrpc.client.Fault):
            pass  # quit closes the connection mid-reply
        try:
            self.app.wait(timeout=10)
        except subprocess.TimeoutExpired:
            self.app.kill()
            self.app.wait()

    def label(self):
        return self.spix.getStringProperty("mainWindow/counterLabel", "text")

    def test_click_and_reset(self):
        self.assertEqual(self.label(), "Not clicked yet")

        self.spix.mouseClick("mainWindow/incrementButton")
        self.spix.wait(100)
        self.assertEqual(self.label(), "Clicked once")

        self.spix.mouseClick("mainWindow/incrementButton")
        self.spix.wait(100)
        self.assertEqual(self.label(), "Clicked 2 times")

        self.spix.mouseClick("mainWindow/resetButton")
        self.spix.wait(100)
        self.assertEqual(self.label(), "Not clicked yet")
        self.assertEqual(self.spix.getErrors(), [])

    def test_viewer_tab_zoom(self):
        self.spix.mouseClick("mainWindow/viewerTab")
        self.assertTrue(self.spix.waitForItem("mainWindow/zoomInButton", 5000), "3D tab didn't open")

        def distance():
            return float(self.spix.getStringProperty("mainWindow/modelViewer", "distance"))

        start = distance()
        self.spix.mouseClick("mainWindow/zoomInButton")
        self.spix.wait(100)
        self.assertLess(distance(), start)

        self.spix.mouseClick("mainWindow/resetViewButton")
        self.spix.wait(100)
        self.assertEqual(distance(), start)
        self.assertEqual(self.spix.getErrors(), [])


if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("--app", required=True, help="path to the ENABLE_SPIX=ON app executable")
    args, rest = parser.parse_known_args()
    APP = args.app
    unittest.main(argv=[sys.argv[0], *rest], verbosity=2)
