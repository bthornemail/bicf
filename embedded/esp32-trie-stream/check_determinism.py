#!/usr/bin/env python3
import argparse
import time

import serial


def reset_and_capture(port: str, baud: int, seconds: float) -> str:
    with serial.Serial(port, baudrate=baud, timeout=0.2) as ser:
        ser.reset_input_buffer()

        # Toggle RTS/DTR to reset (works on most CP2102 ESP32 dev boards).
        ser.dtr = False
        ser.rts = True
        time.sleep(0.12)
        ser.rts = False
        time.sleep(0.12)
        ser.dtr = True

        end = time.time() + seconds
        chunks: list[bytes] = []
        while time.time() < end:
            b = ser.read(4096)
            if b:
                chunks.append(b)
            else:
                time.sleep(0.05)

    return b"".join(chunks).decode("utf-8", "replace")


def parse_hashes(output: str) -> tuple[str, str]:
    left = None
    right = None
    for raw in output.splitlines():
        line = raw.strip()
        if line.startswith("STREAM_LEFT_SHA256="):
            left = line.split("=", 1)[1]
        elif line.startswith("STREAM_RIGHT_SHA256="):
            right = line.split("=", 1)[1]
    if not left or not right:
        raise ValueError("missing STREAM_LEFT_SHA256/STREAM_RIGHT_SHA256")
    if len(left) != 64 or len(right) != 64:
        raise ValueError("invalid SHA-256 hex length")
    return left, right


def main() -> int:
    ap = argparse.ArgumentParser(description="Verify deterministic stream hashes across multiple resets.")
    ap.add_argument("--port", required=True, help="Serial port, e.g. /dev/serial/by-path/...")
    ap.add_argument("--baud", type=int, default=115200)
    ap.add_argument("--runs", type=int, default=5)
    ap.add_argument("--seconds", type=float, default=8.0)
    args = ap.parse_args()

    baseline = None
    for i in range(args.runs):
        out = reset_and_capture(args.port, args.baud, args.seconds)
        left, right = parse_hashes(out)
        pair = (left, right)
        print(f"run={i+1} left={left} right={right}")
        if baseline is None:
            baseline = pair
        elif pair != baseline:
            raise SystemExit(f"non-deterministic: expected {baseline} got {pair}")

    print("DETERMINISTIC=1")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())

