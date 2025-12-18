#!/usr/bin/env python3
from __future__ import annotations

import argparse
import json
import queue
import threading
import time
from http import HTTPStatus
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path
from typing import Optional

import serial


class SseBroker:
    def __init__(self) -> None:
        self._lock = threading.Lock()
        self._clients: list[queue.Queue[str]] = []

    def subscribe(self) -> queue.Queue[str]:
        q: queue.Queue[str] = queue.Queue(maxsize=512)
        with self._lock:
            self._clients.append(q)
        return q

    def unsubscribe(self, q: queue.Queue[str]) -> None:
        with self._lock:
            try:
                self._clients.remove(q)
            except ValueError:
                pass

    def publish(self, line: str) -> None:
        with self._lock:
            clients = list(self._clients)
        for q in clients:
            try:
                q.put_nowait(line)
            except queue.Full:
                # Drop on slow consumers; determinism lives in the saved JSONL file.
                pass


def read_serial_lines(port: str, baud: int, out_q: queue.Queue[tuple[str, str]]) -> None:
    while True:
        try:
            with serial.Serial(port, baudrate=baud, timeout=0.5) as ser:
                ser.reset_input_buffer()
                while True:
                    raw = ser.readline()
                    if not raw:
                        continue
                    line = raw.decode("utf-8", "replace").strip()
                    if not line:
                        continue
                    out_q.put((port, line))
        except Exception:
            time.sleep(0.5)


def replay_lines(path: Path, out_q: queue.Queue[tuple[str, str]]) -> None:
    while True:
        with path.open("r", encoding="utf-8") as f:
            for line in f:
                line = line.strip()
                if not line:
                    continue
                out_q.put(("replay", line))
                time.sleep(0.05)
        # loop replay
        time.sleep(0.5)


class Handler(BaseHTTPRequestHandler):
    broker: SseBroker
    static_dir: Path
    events_path: Optional[Path]

    def log_message(self, format: str, *args) -> None:
        return

    def do_GET(self) -> None:
        if self.path == "/" or self.path.startswith("/?"):
            self._serve_file("index.html", "text/html; charset=utf-8")
            return

        if self.path == "/app.js":
            self._serve_file("app.js", "text/javascript; charset=utf-8")
            return

        if self.path == "/style.css":
            self._serve_file("style.css", "text/css; charset=utf-8")
            return

        if self.path == "/events":
            self._serve_sse()
            return

        if self.path == "/events.jsonl" and self.events_path:
            self._serve_events_file()
            return

        self.send_error(HTTPStatus.NOT_FOUND, "not found")

    def _serve_file(self, name: str, ctype: str) -> None:
        p = self.static_dir / name
        if not p.exists():
            self.send_error(HTTPStatus.NOT_FOUND, "missing static file")
            return
        b = p.read_bytes()
        self.send_response(HTTPStatus.OK)
        self.send_header("Content-Type", ctype)
        self.send_header("Content-Length", str(len(b)))
        self.end_headers()
        self.wfile.write(b)

    def _serve_events_file(self) -> None:
        assert self.events_path is not None
        b = self.events_path.read_bytes() if self.events_path.exists() else b""
        self.send_response(HTTPStatus.OK)
        self.send_header("Content-Type", "application/jsonl; charset=utf-8")
        self.send_header("Content-Length", str(len(b)))
        self.end_headers()
        self.wfile.write(b)

    def _serve_sse(self) -> None:
        q = self.broker.subscribe()
        try:
            self.send_response(HTTPStatus.OK)
            self.send_header("Content-Type", "text/event-stream")
            self.send_header("Cache-Control", "no-cache")
            self.send_header("Connection", "keep-alive")
            self.end_headers()

            while True:
                try:
                    line = q.get(timeout=5.0)
                    payload = line.replace("\n", "\\n")
                    self.wfile.write(f"data: {payload}\n\n".encode("utf-8"))
                    self.wfile.flush()
                except queue.Empty:
                    self.wfile.write(b": keep-alive\n\n")
                    self.wfile.flush()
        finally:
            self.broker.unsubscribe(q)


def main() -> int:
    ap = argparse.ArgumentParser(description="Serial JSONL -> events.jsonl + SSE for browser viewer")
    ap.add_argument("--host", default="127.0.0.1")
    ap.add_argument("--port", type=int, default=8765)
    ap.add_argument("--baud", type=int, default=115200)
    ap.add_argument("--a", help="Serial port for node A")
    ap.add_argument("--b", help="Serial port for node B")
    ap.add_argument("--c", help="Serial port for node C")
    ap.add_argument("--out", help="Path to events.jsonl (live mode)")
    ap.add_argument("--replay", help="Replay an existing events.jsonl instead of reading serial")
    args = ap.parse_args()

    static_dir = Path(__file__).resolve().parent
    broker = SseBroker()
    in_q: queue.Queue[tuple[str, str]] = queue.Queue()

    events_path: Optional[Path] = None

    if args.replay:
        events_path = Path(args.replay)
        t = threading.Thread(target=replay_lines, args=(events_path, in_q), daemon=True)
        t.start()
        print(f"MODE=replay file={events_path}")
    else:
        if not (args.a and args.b and args.c and args.out):
            raise SystemExit("live mode requires --a --b --c --out")
        events_path = Path(args.out)
        for p in [args.a, args.b, args.c]:
            t = threading.Thread(target=read_serial_lines, args=(p, args.baud, in_q), daemon=True)
            t.start()
        print(f"MODE=live out={events_path}")

    class _H(Handler):
        pass

    _H.broker = broker
    _H.static_dir = static_dir
    _H.events_path = events_path

    srv = ThreadingHTTPServer((args.host, args.port), _H)

    def writer_loop() -> None:
        idx = 0
        if events_path and not args.replay:
            events_path.parent.mkdir(parents=True, exist_ok=True)
            f = events_path.open("a", encoding="utf-8")
        else:
            f = None

        try:
            while True:
                src, line = in_q.get()
                if not line.startswith("{"):
                    continue

                # Validate it is JSON and has a node field (best-effort).
                try:
                    obj = json.loads(line)
                    if "node" not in obj:
                        continue
                except Exception:
                    continue

                if f is not None:
                    f.write(line + "\n")
                    f.flush()

                broker.publish(json.dumps({"idx": idx, "src": src, "event": obj}, separators=(",", ":")))
                idx += 1
        finally:
            if f is not None:
                f.close()

    threading.Thread(target=writer_loop, daemon=True).start()
    print(f"HTTP=http://{args.host}:{args.port}/")
    srv.serve_forever()
    return 0


if __name__ == "__main__":
    raise SystemExit(main())

