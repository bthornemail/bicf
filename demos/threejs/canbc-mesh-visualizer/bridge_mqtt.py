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
                pass


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


def _import_mqtt():
    try:
        import paho.mqtt.client as mqtt  # type: ignore

        return mqtt
    except Exception as e:
        raise RuntimeError("paho-mqtt is required: pip install paho-mqtt\n" f"import error: {e}")


def main() -> int:
    ap = argparse.ArgumentParser(description="MQTT bicf/* -> events.jsonl + SSE for browser viewer")
    ap.add_argument("--host", default="127.0.0.1")
    ap.add_argument("--port", type=int, default=8766)
    ap.add_argument("--broker", required=True, help="MQTT broker host/ip (e.g. 127.0.0.1)")
    ap.add_argument("--mqtt-port", type=int, default=1883)
    ap.add_argument("--out", help="Path to events.jsonl (live mode)")
    ap.add_argument("--replay", help="Replay an existing events.jsonl instead of MQTT")
    args = ap.parse_args()

    static_dir = Path(__file__).resolve().parent
    broker = SseBroker()
    in_q: queue.Queue[dict] = queue.Queue(maxsize=2048)

    events_path: Optional[Path] = None

    def replay_thread(path: Path) -> None:
        while True:
            with path.open("r", encoding="utf-8") as f:
                for line in f:
                    line = line.strip()
                    if not line:
                        continue
                    try:
                        in_q.put(json.loads(line))
                    except Exception:
                        pass
                    time.sleep(0.05)
            time.sleep(0.5)

    if args.replay:
        events_path = Path(args.replay)
        t = threading.Thread(target=replay_thread, args=(events_path,), daemon=True)
        t.start()
        print(f"MODE=replay file={events_path}")
    else:
        if not args.out:
            raise SystemExit("live mode requires --out")
        events_path = Path(args.out)
        mqtt = _import_mqtt()

        def on_connect(client, userdata, flags, reason_code, properties):
            (void_flags, void_props) = (flags, properties)
            if reason_code != 0:
                raise RuntimeError(f"MQTT connect failed reason_code={reason_code}")
            client.subscribe("bicf/announce/#", qos=1)
            client.subscribe("bicf/+/events", qos=1)
            client.subscribe("bicf/+/status", qos=1)

        def on_message(client, userdata, msg):
            try:
                payload = msg.payload.decode("utf-8", errors="replace")
                data = json.loads(payload)
            except Exception:
                return

            ev: dict = {"ts": time.time(), "topic": msg.topic}

            if msg.topic.startswith("bicf/announce/") and isinstance(data, dict):
                ev["type"] = "announce"
                ev["id"] = data.get("id")
                ev["kind"] = data.get("kind")
                ev["caps"] = data.get("caps")
                ev["ip"] = data.get("ip")
                ev["gw"] = data.get("gw")
            elif msg.topic.endswith("/events") and isinstance(data, dict):
                ev["type"] = "events"
                ev["device"] = data.get("device")
                ev["ok"] = data.get("ok")
                ev["events"] = data.get("events")
                ev["transcript_hash"] = data.get("transcript_hash")
                ev["fano_hash"] = data.get("fano_hash")
                ev["exec_ms"] = data.get("exec_ms")
            elif msg.topic.endswith("/status") and isinstance(data, dict):
                ev["type"] = "status"
                ev["device"] = data.get("device")
                ev["status"] = data.get("status")
                ev["size"] = data.get("size")
            else:
                return

            try:
                in_q.put_nowait(ev)
            except queue.Full:
                pass

        client = mqtt.Client(mqtt.CallbackAPIVersion.VERSION2, client_id="bicf-canbc-visualizer")
        client.on_connect = on_connect
        client.on_message = on_message
        client.connect(args.broker, args.mqtt_port, keepalive=20)
        client.loop_start()
        print(f"MODE=live mqtt={args.broker}:{args.mqtt_port} out={events_path}")

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
                ev = in_q.get()
                idx += 1
                ev["idx"] = idx
                line = json.dumps(ev, separators=(",", ":"), sort_keys=True)
                broker.publish(line)
                if f:
                    f.write(line + "\n")
                    f.flush()
        finally:
            if f:
                f.close()

    t = threading.Thread(target=writer_loop, daemon=True)
    t.start()

    print(f"HTTP: http://{args.host}:{args.port}/")
    srv.serve_forever()
    return 0


if __name__ == "__main__":
    raise SystemExit(main())

