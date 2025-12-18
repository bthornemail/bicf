#!/usr/bin/env python3

import argparse
import struct
import sys
import time
from pathlib import Path


CLBT_MAGIC = 0x434C4254  # 'CLBT'
CLBT_VERSION = 0x0001

MSG_LOAD_PROGRAM = 0x0001
MSG_RUN = 0x0002

MSG_ACK = 0x8001
MSG_NACK = 0x8002
MSG_RUN_RESULT = 0x8003


def _import_serial():
    try:
        import serial  # type: ignore

        return serial
    except Exception as e:
        raise RuntimeError(
            "pyserial is required: pip install pyserial\n"
            f"import error: {e}"
        )


def pack_frame(msg_type: int, payload: bytes) -> bytes:
    hdr = struct.pack("<IHHI", CLBT_MAGIC, CLBT_VERSION, msg_type, len(payload))
    return hdr + payload


def read_exact(ser, n: int, timeout_s: float) -> bytes:
    deadline = time.time() + timeout_s
    chunks = []
    got = 0
    while got < n and time.time() < deadline:
        b = ser.read(n - got)
        if b:
            chunks.append(b)
            got += len(b)
    if got != n:
        raise TimeoutError(f"timeout reading {n} bytes (got {got})")
    return b"".join(chunks)


def read_frame(ser, timeout_s: float = 2.0):
    hdr = read_exact(ser, 12, timeout_s)
    magic, version, msg_type, payload_len = struct.unpack("<IHHI", hdr)
    if magic != CLBT_MAGIC:
        raise ValueError(f"bad magic 0x{magic:08x}")
    if version != CLBT_VERSION:
        raise ValueError(f"bad version 0x{version:04x}")
    payload = read_exact(ser, payload_len, timeout_s) if payload_len else b""
    return msg_type, payload


def parse_nack(payload: bytes):
    if len(payload) < 8:
        return {"error_code": None, "message": payload}
    error_code, msg_len = struct.unpack("<II", payload[:8])
    msg = payload[8 : 8 + msg_len]
    return {"error_code": error_code, "message": msg.decode("utf-8", errors="replace")}


def main(argv: list[str]) -> int:
    ap = argparse.ArgumentParser(description="CLBT serial runner (Pico 2 USB CDC).")
    ap.add_argument("port", help="Serial device, e.g. /dev/ttyACM0")
    ap.add_argument("clbc", type=Path, help="Path to .clbc container bytes")
    ap.add_argument("--timeout", type=float, default=2.0, help="Read timeout seconds")
    args = ap.parse_args(argv)

    serial = _import_serial()

    clbc_bytes = args.clbc.read_bytes()
    load_payload = struct.pack("<I", len(clbc_bytes)) + clbc_bytes
    run_payload = struct.pack("<I", 0)

    with serial.Serial(args.port, baudrate=115200, timeout=0.1) as ser:
        ser.reset_input_buffer()
        ser.reset_output_buffer()

        ser.write(pack_frame(MSG_LOAD_PROGRAM, load_payload))
        msg_type, payload = read_frame(ser, timeout_s=args.timeout)
        if msg_type == MSG_NACK:
            info = parse_nack(payload)
            print(f"NACK load: {info['error_code']} {info['message']}", file=sys.stderr)
            return 2
        if msg_type != MSG_ACK:
            print(f"unexpected response to load: 0x{msg_type:04x}", file=sys.stderr)
            return 2

        ser.write(pack_frame(MSG_RUN, run_payload))
        msg_type, payload = read_frame(ser, timeout_s=args.timeout)
        if msg_type == MSG_NACK:
            info = parse_nack(payload)
            print(f"NACK run: {info['error_code']} {info['message']}", file=sys.stderr)
            return 2
        if msg_type != MSG_RUN_RESULT:
            print(f"unexpected response to run: 0x{msg_type:04x}", file=sys.stderr)
            return 2

        if len(payload) < 12:
            print("short RUN_RESULT payload", file=sys.stderr)
            return 2
        ok, events, hash_len = struct.unpack("<III", payload[:12])
        h = payload[12 : 12 + hash_len]
        print(f"ok: {ok}")
        print(f"events: {events}")
        print(f"transcript-hash: {h.decode('ascii', errors='replace')}")
        return 0


if __name__ == "__main__":
    raise SystemExit(main(sys.argv[1:]))

