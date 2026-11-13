"""Show a live Android emulator screenshot in a local browser tab."""

import argparse
import subprocess
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--device", default="emulator-5554")
    parser.add_argument("--port", type=int, default=8765)
    args = parser.parse_args()

    class PreviewHandler(BaseHTTPRequestHandler):
        def do_GET(self):
            if self.path == "/":
                self.respond("text/html; charset=utf-8", b"""<!doctype html>
<meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1">
<title>ShrimpMetric Android Emulator</title>
<style>
body{margin:0;background:#101b1e;color:#e8eeeb;font:14px system-ui;text-align:center}
header{padding:10px}img{display:block;height:calc(100dvh - 48px);max-width:96vw;
object-fit:contain;margin:auto}
</style>
<header id="status">ShrimpMetric / Android Emulator</header>
<img alt="Android emulator screen">
<script>
const screen = document.querySelector('img');
const status = document.querySelector('#status');
let previous;
async function refresh() {
  try {
    const response = await fetch('/screen.png', {cache: 'no-store'});
    if (!response.ok) throw new Error('ADB unavailable');
    const next = URL.createObjectURL(await response.blob());
    screen.src = next;
    if (previous) URL.revokeObjectURL(previous);
    previous = next;
    status.textContent = 'ShrimpMetric / Android Emulator';
  } catch {
    status.textContent = 'Waiting for Android Emulator';
  }
  setTimeout(refresh, 750);
}
refresh();
</script>""")
                return
            if self.path != "/screen.png":
                self.send_error(404)
                return

            try:
                capture = subprocess.run(
                    ["adb", "-s", args.device, "exec-out", "screencap", "-p"],
                    check=True,
                    capture_output=True,
                    timeout=5,
                )
            except (OSError, subprocess.SubprocessError):
                self.send_error(503, "Android emulator unavailable")
                return
            self.respond("image/png", capture.stdout)

        def respond(self, content_type, body):
            self.send_response(200)
            self.send_header("Content-Type", content_type)
            self.send_header("Content-Length", str(len(body)))
            self.send_header("Cache-Control", "no-store")
            self.end_headers()
            self.wfile.write(body)

        def log_message(self, *args):
            pass

    with ThreadingHTTPServer(("127.0.0.1", args.port), PreviewHandler) as server:
        print(f"Android preview: http://127.0.0.1:{args.port}", flush=True)
        server.serve_forever()


if __name__ == "__main__":
    main()
