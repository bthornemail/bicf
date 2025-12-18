#!/usr/bin/env python3

import argparse
import selectors
import sys
import time

import serial


def reset_port(ser: serial.Serial) -> None:
    ser.dtr = False
    ser.rts = True
    time.sleep(0.05)
    ser.rts = False


def open_port(path: str) -> serial.Serial:
    return serial.Serial(path, 115200, timeout=0)


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--a")
    ap.add_argument("--b")
    ap.add_argument("--c")
    ap.add_argument("--seconds", type=float, default=8.0)
    ap.add_argument("--reset", action="store_true")
    ap.add_argument("--until", help="stop when this substring appears in output")
    args = ap.parse_args()

    ports = []
    if args.a:
        ports.append(("A", args.a))
    if args.b:
        ports.append(("B", args.b))
    if args.c:
        ports.append(("C", args.c))
    if not ports:
        print("no ports provided", file=sys.stderr)
        return 2

    sel = selectors.DefaultSelector()
    opened = {}

    try:
        for label, path in ports:
            ser = open_port(path)
            opened[label] = ser
            sel.register(ser.fileno(), selectors.EVENT_READ, data=label)
            if args.reset:
                reset_port(ser)

        deadline = time.time() + args.seconds
        needle = args.until.encode("utf-8") if args.until else None

        buffers = {label: b"" for label, _ in ports}

        while time.time() < deadline:
            events = sel.select(timeout=0.05)
            for key, _mask in events:
                label = key.data
                ser = opened[label]
                chunk = ser.read(4096)
                if not chunk:
                    continue
                buffers[label] += chunk

                # Print line-oriented when possible, but keep it robust against binary noise.
                while b"\n" in buffers[label]:
                    line, rest = buffers[label].split(b"\n", 1)
                    buffers[label] = rest
                    try:
                        text = line.decode("utf-8", errors="replace")
                    except Exception:
                        text = repr(line)
                    sys.stdout.write(f"[{label}] {text}\n")
                    sys.stdout.flush()

                    if needle and needle.decode("utf-8", errors="ignore") in text:
                        return 0

            if needle:
                for label in buffers:
                    if needle in buffers[label]:
                        return 0

        # Flush any tails (best-effort)
        for label, buf in buffers.items():
            if buf.strip():
                sys.stdout.write(f"[{label}] {buf.decode('utf-8', errors='replace')}\n")
        return 0
    finally:
        for ser in opened.values():
            try:
                ser.close()
            except Exception:
                pass


if __name__ == "__main__":
    raise SystemExit(main())

