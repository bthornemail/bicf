#!/usr/bin/env python3

import argparse
import sys
import time


def _import_serial():
    try:
        import serial  # type: ignore

        return serial
    except Exception as e:
        raise RuntimeError("pyserial is required: pip install pyserial\n" f"import error: {e}")


NEEDED_KEYS = {"VM_OK", "VM_EVENTS", "VM_TRANSCRIPT_SHA256", "CLBC_SHA256"}


def reset_esp32(ser) -> None:
    # Keep IO0 high (DTR false) while toggling EN (RTS).
    ser.setDTR(False)  # IO0 high
    ser.setRTS(True)   # EN low
    time.sleep(0.15)
    ser.setRTS(False)  # EN high
    time.sleep(0.15)
    ser.reset_input_buffer()


def main(argv: list[str]) -> int:
    ap = argparse.ArgumentParser(description="Read ESP32 CLBC VM key/value output from UART.")
    ap.add_argument("port", help="Serial device, e.g. /dev/ttyUSB0 or /dev/serial/by-path/...")
    ap.add_argument("--baud", type=int, default=115200)
    ap.add_argument("--timeout", type=float, default=5.0, help="Seconds to wait for keys")
    ap.add_argument("--reset", action="store_true", help="Toggle DTR/RTS reset before reading")
    ap.add_argument("--reset-delay", type=float, default=0.5, help="Seconds to wait after reset")
    args = ap.parse_args(argv)

    serial = _import_serial()
    deadline = time.time() + args.timeout

    kv: dict[str, str] = {}

    with serial.Serial(args.port, baudrate=args.baud, timeout=0.2) as ser:
        # Drain any stale bytes first.
        ser.reset_input_buffer()
        if args.reset:
            reset_esp32(ser)
            time.sleep(args.reset_delay)
        buf = b""
        while time.time() < deadline and (NEEDED_KEYS - kv.keys()):
            chunk = ser.read(4096)
            if not chunk:
                continue
            buf += chunk
            while b"\n" in buf:
                line, buf = buf.split(b"\n", 1)
                line = line.strip().decode("utf-8", errors="replace")
                if "=" not in line:
                    continue
                k, v = line.split("=", 1)
                k = k.strip()
                v = v.strip()
                if k:
                    kv[k] = v

    missing = sorted(NEEDED_KEYS - kv.keys())
    if missing:
        print(f"error: missing keys: {', '.join(missing)}", file=sys.stderr)
        for k in sorted(kv.keys()):
            print(f"{k}={kv[k]}", file=sys.stderr)
        return 2

    for k in sorted(NEEDED_KEYS):
        print(f"{k}={kv[k]}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main(sys.argv[1:]))
