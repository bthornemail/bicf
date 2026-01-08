#!/usr/bin/env python3

import argparse
import binascii
import json
import socket
import subprocess
import sys
import time
from pathlib import Path


def _import_mqtt():
    try:
        import paho.mqtt.client as mqtt  # type: ignore

        return mqtt
    except Exception as e:
        raise RuntimeError("paho-mqtt is required: pip install paho-mqtt\n" f"import error: {e}")


def _default_gateway_ip() -> str:
    try:
        out = subprocess.check_output(["ip", "route"], text=True)
    except Exception:
        out = ""
    for line in out.splitlines():
        parts = line.split()
        if len(parts) >= 3 and parts[0] == "default" and parts[1] == "via":
            return parts[2]

    # Fallback: if there's no IPv4 default, try mapping IPv6 router MAC to an IPv4 neighbor.
    try:
        out6 = subprocess.check_output(["ip", "-6", "route", "show", "default"], text=True).strip()
        parts6 = out6.split()
        if len(parts6) < 5 or parts6[0] != "default" or parts6[1] != "via":
            return ""
        v6_router = parts6[2]
        dev = parts6[4] if parts6[3] == "dev" else ""
        if not dev:
            return ""
        neigh = subprocess.check_output(["ip", "neigh", "show", "dev", dev], text=True)
        router_mac = ""
        for line in neigh.splitlines():
            if line.startswith(v6_router + " "):
                toks = line.split()
                if "lladdr" in toks:
                    router_mac = toks[toks.index("lladdr") + 1]
                break
        if not router_mac:
            return ""
        for line in neigh.splitlines():
            toks = line.split()
            if not toks:
                continue
            ip = toks[0]
            if ":" in ip:
                continue
            if "lladdr" in toks and toks[toks.index("lladdr") + 1].lower() == router_mac.lower():
                return ip
    except Exception:
        return ""
    return ""


def _resolve_broker_host(host: str) -> str:
    if host == "gateway":
        gw = _default_gateway_ip()
        if not gw:
            raise RuntimeError('broker host "gateway" requested, but default gateway could not be determined (try `ip route`)')
        return gw
    return host


def _udp_discover_esp32_ids(timeout_s: float, want: int) -> list[str]:
    group = ("239.255.42.42", 4242)
    query = b"BICF_DISCOVERY_QUERY\n"
    prefix = "BICF_DISCOVERY_HELLO "

    sock = socket.socket(socket.AF_INET, socket.SOCK_DGRAM, socket.IPPROTO_UDP)
    try:
        sock.settimeout(max(0.1, timeout_s))
        # Best-effort query; some APs block multicast.
        sock.sendto(query, group)
        ids: set[str] = set()
        deadline = time.time() + timeout_s
        while time.time() < deadline and (want <= 0 or len(ids) < want):
            try:
                data, _addr = sock.recvfrom(512)
            except socket.timeout:
                break
            try:
                text = data.decode("utf-8", errors="replace").strip()
            except Exception:
                continue
            if not text.startswith(prefix):
                continue
            dev_id = text[len(prefix) :].strip()
            if dev_id:
                ids.add(dev_id)
        return sorted(ids)
    finally:
        sock.close()


def main(argv: list[str]) -> int:
    ap = argparse.ArgumentParser(description="Send CANBC to devices over MQTT and compare state hashes.")
    ap.add_argument("--broker", required=True, help="MQTT broker host/ip (e.g. gateway or 10.0.0.1)")
    ap.add_argument("--port", type=int, default=1883)
    ap.add_argument("--canbc", required=True, type=Path, help="Path to .canbc file")
    ap.add_argument("--timeout", type=float, default=10.0)
    ap.add_argument("--retain-load", action="store_true", help="Publish load_canbc as a retained message (helps late subscribers)")
    ap.add_argument("--runs", type=int, default=1, help="Number of run iterations (default: 1)")
    ap.add_argument("--pause", type=float, default=0.0, help="Seconds to pause between runs (default: 0)")
    ap.add_argument("--reload-each-run", action="store_true", help="Republish load_canbc before each run")
    ap.add_argument("--auto-esp32", type=int, default=0, help="Auto-discover N ESP32 devices via bicf/announce/<id> (requires retained announce)")
    ap.add_argument("--udp-discover-esp32", type=int, default=0, help="Auto-discover N ESP32 devices via UDP multicast (no MQTT announce needed)")
    ap.add_argument("--no-pico", action="store_true", help="Run ESP32-only (no pico expected)")
    ap.add_argument("--pico-id", default="pico", help="Pico device id (default: pico)")
    ap.add_argument("--esp32-a", default="esp32-a")
    ap.add_argument("--esp32-b", default="esp32-b")
    ap.add_argument("--esp32-c", default="", help="Optional third ESP32 device id (e.g. esp32-c)")
    args = ap.parse_args(argv)

    mqtt = _import_mqtt()
    broker_host = _resolve_broker_host(args.broker)

    canbc_hex = binascii.hexlify(args.canbc.read_bytes()).decode("ascii")

    devices: dict[str, dict[str, str]] = {}
    if not args.no_pico:
        devices[args.pico_id] = {"cmd": "bicf/pico/command", "evt": "bicf/pico/events", "status": "bicf/pico/status"}
    if args.auto_esp32 <= 0 and args.udp_discover_esp32 <= 0:
        devices[args.esp32_a] = {"cmd": f"bicf/{args.esp32_a}/command", "evt": f"bicf/{args.esp32_a}/events", "status": f"bicf/{args.esp32_a}/status"}
        devices[args.esp32_b] = {"cmd": f"bicf/{args.esp32_b}/command", "evt": f"bicf/{args.esp32_b}/events", "status": f"bicf/{args.esp32_b}/status"}
        if args.esp32_c:
            devices[args.esp32_c] = {"cmd": f"bicf/{args.esp32_c}/command", "evt": f"bicf/{args.esp32_c}/events", "status": f"bicf/{args.esp32_c}/status"}

    results: dict[str, dict] = {}
    loaded: set[str] = set()
    announced_esp32: dict[str, dict] = {}

    def on_connect(client, userdata, flags, reason_code, properties):
        (void_flags, void_props) = (flags, properties)
        if reason_code != 0:
            raise RuntimeError(f"MQTT connect failed reason_code={reason_code}")
        if args.auto_esp32 > 0:
            client.subscribe("bicf/announce/#", qos=1)
        for d in devices.values():
            client.subscribe(d["evt"], qos=1)
            client.subscribe(d["status"], qos=1)

    def on_message(client, userdata, msg):
        try:
            payload = msg.payload.decode("utf-8", errors="replace")
            data = json.loads(payload)
        except Exception:
            return
        if args.auto_esp32 > 0 and msg.topic.startswith("bicf/announce/"):
            if isinstance(data, dict) and data.get("kind") == "esp32" and isinstance(data.get("id"), str):
                announced_esp32[data["id"]] = data
            return
        # Loaded acks:
        # - Pico firmware publishes {"type":"loaded","clbc_len":...} to events
        # - ESP32 firmware publishes {"device":"...","status":"loaded_canbc",...} to status
        if data.get("type") == "loaded" and not args.no_pico:
            loaded.add(args.pico_id)
            return
        if data.get("status") in ("loaded_canbc", "loaded") and "device" in data:
            loaded.add(data["device"])
            return
        if data.get("type") == "run_result":
            if not args.no_pico:
                results[args.pico_id] = data
        elif "device" in data and "transcript_hash" in data:
            results[data["device"]] = data

    def _percentile(sorted_values: list[float], p: float) -> float:
        if not sorted_values:
            return 0.0
        if p <= 0:
            return sorted_values[0]
        if p >= 100:
            return sorted_values[-1]
        # Nearest-rank method
        k = int(round((p / 100.0) * (len(sorted_values) - 1)))
        k = max(0, min(len(sorted_values) - 1, k))
        return sorted_values[k]

    def _stats(values: list[float]) -> dict[str, float]:
        if not values:
            return {"mean": 0.0, "stdev": 0.0, "min": 0.0, "p50": 0.0, "p95": 0.0, "max": 0.0}
        n = len(values)
        mean = sum(values) / n
        var = 0.0
        if n >= 2:
            var = sum((v - mean) ** 2 for v in values) / (n - 1)
        s = sorted(values)
        return {
            "mean": mean,
            "stdev": var ** 0.5,
            "min": s[0],
            "p50": _percentile(s, 50),
            "p95": _percentile(s, 95),
            "max": s[-1],
        }

    client = mqtt.Client(mqtt.CallbackAPIVersion.VERSION2, client_id="bicf-canbc-3device")
    client.on_connect = on_connect
    client.on_message = on_message

    client.connect(broker_host, args.port, keepalive=20)
    client.loop_start()

    try:
        load = json.dumps({"type": "load_canbc", "canbc_hex": canbc_hex})
        run = json.dumps({"type": "run"})

        if args.udp_discover_esp32 > 0:
            found = _udp_discover_esp32_ids(timeout_s=min(max(args.timeout, 1.0), 10.0), want=args.udp_discover_esp32)
            if len(found) < args.udp_discover_esp32:
                print(f"udp-discovery: expected {args.udp_discover_esp32} esp32, got {len(found)}", file=sys.stderr)
                if found:
                    print("udp-discovery: seen ids: " + ", ".join(found), file=sys.stderr)
                print("hint: some hotspots/APs block client-to-client or multicast; use --auto-esp32 (MQTT announce) instead", file=sys.stderr)
                return 2
            for dev_id in found[: args.udp_discover_esp32]:
                devices[dev_id] = {"cmd": f"bicf/{dev_id}/command", "evt": f"bicf/{dev_id}/events", "status": f"bicf/{dev_id}/status"}

        if args.auto_esp32 > 0:
            deadline_disc = time.time() + min(max(args.timeout, 1.0), 30.0)
            while time.time() < deadline_disc and len(announced_esp32) < args.auto_esp32:
                time.sleep(0.05)
            if len(announced_esp32) < args.auto_esp32:
                print(f"auto-discovery: expected {args.auto_esp32} esp32 announces, got {len(announced_esp32)}", file=sys.stderr)
                if announced_esp32:
                    print("auto-discovery: seen ids: " + ", ".join(sorted(announced_esp32.keys())), file=sys.stderr)
                return 2
            # Replace any previously specified ESP32 devices with discovered ones.
            discovered_ids = sorted(announced_esp32.keys())[: args.auto_esp32]
            for dev_id in discovered_ids:
                devices[dev_id] = {"cmd": f"bicf/{dev_id}/command", "evt": f"bicf/{dev_id}/events", "status": f"bicf/{dev_id}/status"}
                client.subscribe(f"bicf/{dev_id}/events", qos=1)
                client.subscribe(f"bicf/{dev_id}/status", qos=1)

        def _publish_load_and_wait() -> bool:
            for topics in devices.values():
                client.publish(topics["cmd"], load, qos=1, retain=args.retain_load)
            deadline_load = time.time() + min(args.timeout, 20.0)
            needed_loaded = set(devices.keys())
            while time.time() < deadline_load:
                if needed_loaded.issubset(loaded):
                    return True
                time.sleep(0.05)
            return False

        if not _publish_load_and_wait():
            missing_loaded = [k for k in devices.keys() if k not in loaded]
            print(f"missing load ack from: {', '.join(missing_loaded)}", file=sys.stderr)
            return 2

        wall_ms: list[float] = []
        exec_ms: dict[str, list[float]] = {k: [] for k in devices.keys()}

        for run_idx in range(args.runs):
            if run_idx > 0 and args.pause > 0:
                time.sleep(args.pause)

            if args.reload_each_run:
                if not _publish_load_and_wait():
                    missing_loaded = [k for k in devices.keys() if k not in loaded]
                    print(f"missing load ack from: {', '.join(missing_loaded)}", file=sys.stderr)
                    return 2

            results.clear()
            t0 = time.time()
            for topics in devices.values():
                client.publish(topics["cmd"], run, qos=1)

            deadline = time.time() + args.timeout
            needed = set(devices.keys())
            while time.time() < deadline:
                if needed.issubset(set(results.keys())):
                    break
                time.sleep(0.05)
            t1 = time.time()
            wall_ms.append((t1 - t0) * 1000.0)

            missing = [k for k in devices.keys() if k not in results]
            if missing:
                print(f"missing results from: {', '.join(missing)}", file=sys.stderr)
                return 2

            def get_hash(dev: str) -> str | None:
                return results[dev].get("transcript_hash")

            hashes = {k: get_hash(k) for k in devices.keys()}
            fano_hashes = {k: results[k].get("fano_hash") for k in devices.keys()}
            events = {k: results[k].get("events") for k in devices.keys()}

            ok = len(set(hashes.values())) == 1
            ok_fano = True
            if any(v is not None for v in fano_hashes.values()):
                ok_fano = len(set(v for v in fano_hashes.values() if v is not None)) == 1
            if not ok:
                print("FAIL: hashes differ", file=sys.stderr)
                for k in hashes:
                    extra = ""
                    if fano_hashes.get(k):
                        extra = f" fano={fano_hashes[k]}"
                    print(f"{k}: events={events[k]} hash={hashes[k]}{extra}", file=sys.stderr)
                return 1
            if not ok_fano:
                print("WARN: state hashes match, but fano_hash differs", file=sys.stderr)

            for k in devices.keys():
                v = results[k].get("exec_ms")
                if isinstance(v, (int, float)) and v > 0:
                    exec_ms[k].append(float(v))

        # Print final run's values (matches existing output expectation)
        hashes = {k: results[k].get("transcript_hash") for k in devices.keys()}
        fano_hashes = {k: results[k].get("fano_hash") for k in devices.keys()}
        events = {k: results[k].get("events") for k in devices.keys()}
        for k in hashes:
            extra = ""
            if fano_hashes.get(k):
                extra = f" fano={fano_hashes[k]}"
            if "exec_ms" in results[k]:
                extra += f" exec_ms={results[k].get('exec_ms')}"
            print(f"{k}: events={events[k]} hash={hashes[k]}{extra}")

        print("PASS: all state hashes match")
        if args.runs > 1:
            s = _stats(wall_ms)
            print(
                "bench wall_ms "
                f"mean={s['mean']:.3f} stdev={s['stdev']:.3f} "
                f"min={s['min']:.3f} p50={s['p50']:.3f} p95={s['p95']:.3f} max={s['max']:.3f}"
            )
            for dev, values in exec_ms.items():
                if not values:
                    continue
                sd = _stats(values)
                print(
                    f"bench {dev} exec_ms "
                    f"mean={sd['mean']:.3f} stdev={sd['stdev']:.3f} "
                    f"min={sd['min']:.3f} p50={sd['p50']:.3f} p95={sd['p95']:.3f} max={sd['max']:.3f}"
                )
        return 0
    finally:
        client.loop_stop()
        client.disconnect()


if __name__ == "__main__":
    raise SystemExit(main(sys.argv[1:]))
