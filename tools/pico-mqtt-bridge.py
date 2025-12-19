#!/usr/bin/env python3

"""
USB CDC to MQTT Bridge for Pico 2 / Pico 2 W
Bridges a Pico USB CDC CLBT device to an MQTT broker.
Useful when you want the Pico to participate via a host bridge (even if the board has WiFi).
"""

import argparse
import json
import sys
import time
import struct
from pathlib import Path

try:
    import paho.mqtt.client as mqtt
    import serial
except ImportError:
    print("error: required packages: pip install paho-mqtt pyserial", file=sys.stderr)
    sys.exit(1)


CLBT_MAGIC = 0x434C4254
CLBT_VERSION = 0x0001
MSG_LOAD_PROGRAM = 0x0001
MSG_RUN = 0x0002
MSG_ACK = 0x8001
MSG_RUN_RESULT = 0x8003


def pack_frame(msg_type: int, payload: bytes) -> bytes:
    hdr = struct.pack("<IHHI", CLBT_MAGIC, CLBT_VERSION, msg_type, len(payload))
    return hdr + payload


def read_frame(ser, timeout_s: float):
    deadline = time.time() + timeout_s
    hdr = b""
    while len(hdr) < 12 and time.time() < deadline:
        chunk = ser.read(12 - len(hdr))
        if chunk:
            hdr += chunk
        time.sleep(0.01)
    
    if len(hdr) < 12:
        raise TimeoutError("timeout reading frame header")
    
    magic, version, msg_type, payload_len = struct.unpack("<IHHI", hdr)
    if magic != CLBT_MAGIC:
        raise ValueError(f"bad magic 0x{magic:08x}")
    
    payload = b""
    while len(payload) < payload_len and time.time() < deadline:
        chunk = ser.read(payload_len - len(payload))
        if chunk:
            payload += chunk
        time.sleep(0.01)
    
    if len(payload) < payload_len:
        raise TimeoutError(f"timeout reading payload ({len(payload)}/{payload_len})")
    
    return msg_type, payload


def parse_run_result(payload: bytes):
    import struct
    if len(payload) < 12:
        raise ValueError("short RUN_RESULT payload")
    ok, events, hash_len = struct.unpack("<III", payload[:12])
    h = payload[12:12 + hash_len].decode("ascii", errors="replace")
    return ok, events, h


def on_mqtt_connect(client, userdata, flags, rc):
    if rc == 0:
        print("Connected to MQTT broker", file=sys.stderr)
        # Subscribe to topics for Pico
        client.subscribe("bicf/pico/command")
    else:
        print(f"Failed to connect to MQTT broker: {rc}", file=sys.stderr)


def on_mqtt_message(client, userdata, msg):
    """Handle incoming MQTT messages and forward to Pico via USB CDC"""
    ser = userdata.get("serial")
    if not ser:
        return
    
    try:
        # Parse message (expect JSON with CLBC program or command)
        data = json.loads(msg.payload.decode("utf-8"))
        
        if data.get("type") == "load_program":
            # Load CLBC program to Pico
            if "clbc_hex" in data:
                clbc_bytes = bytes.fromhex(data["clbc_hex"])
            else:
                clbc_path = data.get("clbc_path")
                if not clbc_path:
                    raise ValueError("load_program requires clbc_hex or clbc_path")
                clbc_bytes = Path(clbc_path).read_bytes()

            load_payload = struct.pack("<I", len(clbc_bytes)) + clbc_bytes
            ser.write(pack_frame(MSG_LOAD_PROGRAM, load_payload))

            msg_type, _ = read_frame(ser, timeout_s=2.0)
            if msg_type == MSG_ACK:
                client.publish("bicf/pico/events", json.dumps({"type": "loaded", "clbc_len": len(clbc_bytes)}))
        
        elif data.get("type") == "run":
            # Run CLBC program
            run_payload = struct.pack("<I", 0)
            ser.write(pack_frame(MSG_RUN, run_payload))
            
            # Wait for result
            msg_type, payload = read_frame(ser, timeout_s=2.0)
            if msg_type == MSG_RUN_RESULT:
                ok, events, hash_val = parse_run_result(payload)
                # Publish result
                client.publish("bicf/pico/events", json.dumps({"type": "run_result", "ok": ok, "events": events, "transcript_hash": hash_val}))
    
    except Exception as e:
        print(f"error handling MQTT message: {e}", file=sys.stderr)


def main(argv):
    ap = argparse.ArgumentParser(description="Bridge Pico 2 USB CDC to MQTT broker")
    ap.add_argument("pico_port", help="Pico USB CDC port, e.g. /dev/ttyACM0")
    ap.add_argument("--broker", default="localhost", help="MQTT broker host")
    ap.add_argument("--port", type=int, default=1883, help="MQTT broker port")
    ap.add_argument("--client-id", default="pico-bridge", help="MQTT client ID")
    ap.add_argument("--baud", type=int, default=115200, help="Serial baud rate")
    args = ap.parse_args(argv)
    
    # Open serial connection to Pico
    try:
        ser = serial.Serial(args.pico_port, baudrate=args.baud, timeout=0.1)
        ser.reset_input_buffer()
        ser.reset_output_buffer()
    except Exception as e:
        print(f"error: failed to open {args.pico_port}: {e}", file=sys.stderr)
        return 1
    
    # Connect to MQTT broker
    mqtt_client = mqtt.Client(client_id=args.client_id)
    mqtt_client.user_data_set({"serial": ser})
    mqtt_client.on_connect = on_mqtt_connect
    mqtt_client.on_message = on_mqtt_message
    
    try:
        mqtt_client.connect(args.broker, args.port, 60)
        mqtt_client.loop_start()
    except Exception as e:
        print(f"error: failed to connect to MQTT broker: {e}", file=sys.stderr)
        ser.close()
        return 1
    
    print(f"Bridge running: {args.pico_port} <-> MQTT ({args.broker}:{args.port})", file=sys.stderr)
    print("Publishing Pico events to: bicf/pico/events", file=sys.stderr)
    print("Subscribing to: bicf/pico/command", file=sys.stderr)
    
    # Main loop: read from Pico and publish to MQTT
    try:
        while True:
            try:
                # Check for messages from Pico (non-blocking)
                if ser.in_waiting > 0:
                    # Read and parse frame
                    msg_type, payload = read_frame(ser, timeout_s=0.1)
                    
                    # Publish to MQTT
                    if msg_type == MSG_RUN_RESULT:
                        ok, events, hash_val = parse_run_result(payload)
                        mqtt_client.publish("bicf/pico/events", json.dumps({
                            "type": "run_result",
                            "ok": ok,
                            "events": events,
                            "transcript_hash": hash_val,
                            "timestamp": time.time()
                        }))
                
                time.sleep(0.1)  # Small delay to avoid busy-waiting
            
            except TimeoutError:
                continue  # No data available, continue
            except Exception as e:
                print(f"error in main loop: {e}", file=sys.stderr)
                time.sleep(0.1)
    
    except KeyboardInterrupt:
        print("\nShutting down...", file=sys.stderr)
    finally:
        mqtt_client.loop_stop()
        mqtt_client.disconnect()
        ser.close()
    
    return 0


if __name__ == "__main__":
    raise SystemExit(main(sys.argv[1:]))
