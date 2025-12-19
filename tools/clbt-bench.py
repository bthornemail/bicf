#!/usr/bin/env python3

import argparse
import statistics
import struct
import time
from pathlib import Path


CLBT_MAGIC = 0x434C4254  # 'CLBT'
CLBT_VERSION = 0x0001

MSG_LOAD_PROGRAM = 0x0001
MSG_RUN = 0x0002

MSG_ACK = 0x8001
MSG_RUN_RESULT = 0x8003


def _import_serial():
    try:
        import serial  # type: ignore

        return serial
    except Exception as e:
        raise RuntimeError("pyserial is required: pip install pyserial\n" f"import error: {e}")


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


def read_frame(ser, timeout_s: float):
    hdr = read_exact(ser, 12, timeout_s)
    magic, version, msg_type, payload_len = struct.unpack("<IHHI", hdr)
    if magic != CLBT_MAGIC:
        raise ValueError(f"bad magic 0x{magic:08x}")
    if version != CLBT_VERSION:
        raise ValueError(f"bad version 0x{version:04x}")
    payload = read_exact(ser, payload_len, timeout_s) if payload_len else b""
    return msg_type, payload


def parse_run_result(payload: bytes):
    if len(payload) < 12:
        raise ValueError("short RUN_RESULT payload")
    ok, events, hash_len = struct.unpack("<III", payload[:12])
    h = payload[12 : 12 + hash_len].decode("ascii", errors="replace")
    return ok, events, h


def percentile(xs: list[float], p: float) -> float:
    if not xs:
        return float("nan")
    s = sorted(xs)
    k = (len(s) - 1) * p
    f = int(k)
    c = min(f + 1, len(s) - 1)
    if f == c:
        return s[f]
    return s[f] * (c - k) + s[c] * (k - f)


def main(argv: list[str]) -> int:
    ap = argparse.ArgumentParser(description="Benchmark CLBT over Pico USB CDC.")
    ap.add_argument("port", help="Serial device, e.g. /dev/ttyACM0")
    ap.add_argument("clbc", type=Path, help="Path to .clbc container bytes")
    ap.add_argument("--expected-hash", default="", help="If set, validates transcript hash matches")
    ap.add_argument("--expected-events", type=int, default=-1, help="If set, validates events matches")
    ap.add_argument("--runs", type=int, default=50, help="Number of RUN requests")
    ap.add_argument("--timeout", type=float, default=2.0, help="Read timeout seconds")
    args = ap.parse_args(argv)

    serial = _import_serial()

    clbc_bytes = args.clbc.read_bytes()
    load_payload = struct.pack("<I", len(clbc_bytes)) + clbc_bytes
    run_payload = struct.pack("<I", 0)

    timings_ms: list[float] = []
    ok_count = 0

    with serial.Serial(args.port, baudrate=115200, timeout=0.1) as ser:
        ser.reset_input_buffer()
        ser.reset_output_buffer()

        ser.write(pack_frame(MSG_LOAD_PROGRAM, load_payload))
        msg_type, payload = read_frame(ser, timeout_s=args.timeout)
        if msg_type != MSG_ACK:
            raise SystemExit(f"LOAD_PROGRAM failed, msg_type=0x{msg_type:04x} payload_len={len(payload)}")

        for _ in range(args.runs):
            t0 = time.perf_counter()
            ser.write(pack_frame(MSG_RUN, run_payload))
            msg_type, payload = read_frame(ser, timeout_s=args.timeout)
            t1 = time.perf_counter()
            if msg_type != MSG_RUN_RESULT:
                raise SystemExit(f"RUN failed, msg_type=0x{msg_type:04x} payload_len={len(payload)}")
            ok, events, h = parse_run_result(payload)

            if args.expected_hash and h != args.expected_hash:
                raise SystemExit(f"hash mismatch: expected {args.expected_hash} got {h}")
            if args.expected_events >= 0 and events != args.expected_events:
                raise SystemExit(f"events mismatch: expected {args.expected_events} got {events}")

            ok_count += 1 if ok == 1 else 0
            timings_ms.append((t1 - t0) * 1000.0)

    mean = statistics.mean(timings_ms) if timings_ms else float("nan")
    stdev = statistics.pstdev(timings_ms) if len(timings_ms) > 1 else 0.0
    print(f"runs: {len(timings_ms)} ok: {ok_count}")
    print(f"ms mean: {mean:.3f} stdev: {stdev:.3f}")
    print(f"ms min: {min(timings_ms):.3f} p50: {percentile(timings_ms, 0.50):.3f} p95: {percentile(timings_ms, 0.95):.3f} max: {max(timings_ms):.3f}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main(__import__('sys').argv[1:]))
