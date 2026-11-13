"""Show a live Android emulator screenshot in a local browser tab."""

import argparse
import json
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
header{padding:10px}img{display:block;max-height:calc(100dvh - 88px);max-width:96vw;
width:auto;height:auto;margin:auto;touch-action:none;user-select:none}
</style>
<header id="status">ShrimpMetric / Android Emulator</header>
<nav><button data-key="4">Back</button> <button data-key="3">Home</button>
<button data-key="187">Recent</button></nav>
<img alt="Android emulator screen" draggable="false">
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

function sendInput(values) {
  fetch('/input', {
    method: 'POST',
    headers: {'Content-Type': 'application/json'},
    body: JSON.stringify(values),
  }).then(response => {
    if (!response.ok) throw new Error('Android input unavailable');
  }).catch(error => { status.textContent = error.message; });
}

function point(event) {
  const rect = screen.getBoundingClientRect();
  const x = (event.clientX - rect.left) * screen.naturalWidth / rect.width;
  const y = (event.clientY - rect.top) * screen.naturalHeight / rect.height;
  return [
    Math.min(screen.naturalWidth - 1, Math.max(0, Math.round(x))),
    Math.min(screen.naturalHeight - 1, Math.max(0, Math.round(y))),
  ];
}

let start;
screen.addEventListener('pointerdown', event => {
  if (!event.isPrimary || event.button !== 0 || !screen.naturalWidth) return;
  start = {point: point(event), time: performance.now()};
  screen.setPointerCapture(event.pointerId);
});
screen.addEventListener('pointerup', event => {
  if (!event.isPrimary || !start) return;
  const end = point(event);
  const duration = Math.min(1500, Math.max(80, Math.round(performance.now() - start.time)));
  const distance = Math.hypot(end[0] - start.point[0], end[1] - start.point[1]);
  sendInput(distance < 12 && duration < 450
    ? ['tap', ...start.point]
    : ['swipe', ...start.point, ...end, duration]);
  start = undefined;
});
screen.addEventListener('pointercancel', () => { start = undefined; });
document.querySelectorAll('[data-key]').forEach(button => {
  button.onclick = () => sendInput(['keyevent', Number(button.dataset.key)]);
});
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

        def do_POST(self):
            host = self.headers.get("Host")
            allowed_hosts = {f"localhost:{args.port}", f"127.0.0.1:{args.port}"}
            if (self.path != "/input" or host not in allowed_hosts
                    or self.headers.get("Origin") != f"http://{host}"
                    or self.headers.get_content_type() != "application/json"):
                self.send_error(403)
                return

            try:
                size = int(self.headers.get("Content-Length", "0"))
                if not 0 < size <= 128:
                    raise ValueError
                command, *values = json.loads(self.rfile.read(size))
                lengths = {"tap": 2, "swipe": 5, "keyevent": 1}
                if (len(values) != lengths.get(command)
                        or not all(type(value) is int and 0 <= value <= 10000 for value in values)
                        or (command == "keyevent" and values[0] not in {3, 4, 187})):
                    raise ValueError
            except (TypeError, ValueError):
                self.send_error(400)
                return

            try:
                subprocess.run(
                    ["adb", "-s", args.device, "shell", "input", command, *map(str, values)],
                    check=True, capture_output=True, timeout=5,
                )
            except (OSError, subprocess.SubprocessError):
                self.send_error(503, "Android input unavailable")
                return
            self.respond("text/plain", b"OK")

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
