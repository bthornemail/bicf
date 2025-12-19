#!/usr/bin/env python3

import argparse
import binascii
import json
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
        return ""
    for line in out.splitlines():
        parts = line.split()
        # default via 192.168.43.1 dev wlp2s0 ...
        if len(parts) >= 3 and parts[0] == "default" and parts[1] == "via":
            return parts[2]

    # Some phone hotspots provide IPv6 default routing but no IPv4 default route.
    # In that case, try to map the IPv6 router's MAC to an IPv4 neighbor entry.
    try:
        out6 = subprocess.check_output(["ip", "-6", "route", "show", "default"], text=True).strip()
        if not out6:
            return ""
        # default via fe80::... dev wlp2s0 ...
        parts6 = out6.split()
        if len(parts6) < 5 or parts6[0] != "default" or parts6[1] != "via":
            return ""
        v6_router = parts6[2]
        dev = parts6[4] if parts6[3] == "dev" else ""
        if not dev:
            return ""

        neigh6 = subprocess.check_output(["ip", "neigh", "show", "dev", dev], text=True)
        router_mac = ""
        for line in neigh6.splitlines():
            # fe80::... lladdr 76:8f:... router REACHABLE
            if line.startswith(v6_router + " "):
                toks = line.split()
                if "lladdr" in toks:
                    router_mac = toks[toks.index("lladdr") + 1]
                break
        if not router_mac:
            return ""

        # Find an IPv4 neighbor with the same MAC.
        for line in neigh6.splitlines():
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


def main(argv: list[str]) -> int:
    ap = argparse.ArgumentParser(description="Send CLBC to pico+2 esp32 devices over MQTT and compare transcript hashes.")
    ap.add_argument("--broker", required=True, help="MQTT broker host/ip (e.g. 192.168.43.1)")
    ap.add_argument("--port", type=int, default=1883)
    ap.add_argument("--clbc", required=True, type=Path, help="Path to .clbc file")
    ap.add_argument("--timeout", type=float, default=10.0)
    ap.add_argument("--pico-id", default="pico")
    ap.add_argument("--esp32-a", default="esp32-a")
    ap.add_argument("--esp32-b", default="esp32-b")
    args = ap.parse_args(argv)

    mqtt = _import_mqtt()

    broker_host = _resolve_broker_host(args.broker)

    clbc_bytes = args.clbc.read_bytes()
    clbc_hex = binascii.hexlify(clbc_bytes).decode("ascii")

    devices = {
        args.pico_id: {"cmd": "bicf/pico/command", "evt": "bicf/pico/events"},
        args.esp32_a: {"cmd": f"bicf/{args.esp32_a}/command", "evt": f"bicf/{args.esp32_a}/events"},
        args.esp32_b: {"cmd": f"bicf/{args.esp32_b}/command", "evt": f"bicf/{args.esp32_b}/events"},
    }

    results: dict[str, dict] = {}

    def on_connect(client, userdata, flags, reason_code, properties):
        (void_flags, void_props) = (flags, properties)
        if reason_code != 0:
            raise RuntimeError(f"MQTT connect failed reason_code={reason_code}")
        for d in devices.values():
            client.subscribe(d["evt"], qos=1)

    def on_message(client, userdata, msg):
        try:
            payload = msg.payload.decode("utf-8", errors="replace")
            data = json.loads(payload)
        except Exception:
            return
        # pico bridge uses {"type":"run_result",...}; esp32 uses {"device": "...", ...}
        if data.get("type") == "run_result":
            results[args.pico_id] = data
        elif "device" in data and "transcript_hash" in data:
            results[data["device"]] = data

    client = mqtt.Client(mqtt.CallbackAPIVersion.VERSION2, client_id="bicf-3device")
    client.on_connect = on_connect
    client.on_message = on_message

    client.connect(broker_host, args.port, keepalive=20)
    client.loop_start()

    try:
        load = json.dumps({"type": "load_program", "clbc_hex": clbc_hex})
        run = json.dumps({"type": "run"})

        for dev, topics in devices.items():
            client.publish(topics["cmd"], load, qos=1)

        time.sleep(0.3)

        for dev, topics in devices.items():
            client.publish(topics["cmd"], run, qos=1)

        deadline = time.time() + args.timeout
        while time.time() < deadline:
            # Wait for pico + esp32-a + esp32-b
            got = set(results.keys())
            needed = {args.pico_id, args.esp32_a, args.esp32_b}
            if needed.issubset(got):
                break
            time.sleep(0.05)

        missing = []
        for k in [args.pico_id, args.esp32_a, args.esp32_b]:
            if k not in results:
                missing.append(k)
        if missing:
            print(f"missing results from: {', '.join(missing)}", file=sys.stderr)
            return 2

        hashes = {
            args.pico_id: results[args.pico_id].get("transcript_hash"),
            args.esp32_a: results[args.esp32_a].get("transcript_hash"),
            args.esp32_b: results[args.esp32_b].get("transcript_hash"),
        }
        events = {
            args.pico_id: results[args.pico_id].get("events"),
            args.esp32_a: results[args.esp32_a].get("events"),
            args.esp32_b: results[args.esp32_b].get("events"),
        }

        for k in hashes:
            print(f"{k}: events={events[k]} hash={hashes[k]}")

        ok = len(set(hashes.values())) == 1
        if ok:
            print("PASS: all transcript hashes match")
            return 0
        print("FAIL: hashes differ", file=sys.stderr)
        return 1
    finally:
        client.loop_stop()
        client.disconnect()


if __name__ == "__main__":
    raise SystemExit(main(sys.argv[1:]))
