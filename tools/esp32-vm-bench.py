#!/usr/bin/env python3

import argparse
import statistics
import sys
import time


def _import_serial():
    try:
        import serial  # type: ignore
        return serial
    except Exception as e:
        raise RuntimeError("pyserial is required: pip install pyserial\n" f"import error: {e}")


NEEDED_KEYS = {"VM_OK", "VM_EVENTS", "VM_TRANSCRIPT_SHA256", "CLBC_SHA256"}


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


def reset_esp32(ser):
    """Reset ESP32 via RTS/EN while keeping IO0 high (DTR false)."""
    # Many ESP32 dev boards wire RTS->EN and DTR->IO0 (both active-low).
    # Ensure IO0 is high (not in bootloader) during reset.
    ser.setDTR(False)  # IO0 high
    ser.setRTS(True)   # EN low
    time.sleep(0.15)
    ser.setRTS(False)  # EN high
    time.sleep(0.15)
    ser.reset_input_buffer()


def read_esp32_output(ser, timeout_s: float):
    """Read ESP32 key-value output and return (kv, tail_bytes)."""
    deadline = time.time() + timeout_s
    kv: dict[str, str] = {}
    buf = b""

    while time.time() < deadline and (NEEDED_KEYS - kv.keys()):
        chunk = ser.read(4096)
        if not chunk:
            time.sleep(0.01)
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

    return kv, buf


def main(argv: list[str]) -> int:
    ap = argparse.ArgumentParser(description="Benchmark ESP32 CLBC VM by resetting and reading output.")
    ap.add_argument("port", help="Serial device, e.g. /dev/ttyUSB0")
    ap.add_argument("--baud", type=int, default=115200)
    ap.add_argument("--runs", type=int, default=50, help="Number of reset+run iterations")
    ap.add_argument("--expected-hash", default="", help="If set, validates transcript hash matches")
    ap.add_argument("--expected-events", type=int, default=-1, help="If set, validates events matches")
    ap.add_argument("--timeout", type=float, default=5.0, help="Read timeout per run (seconds)")
    ap.add_argument("--reset-delay", type=float, default=0.5, help="Delay after reset before reading (seconds)")
    ap.add_argument("--no-reset", action="store_true", help="Do not toggle DTR/RTS before reading")
    args = ap.parse_args(argv)

    serial = _import_serial()

    timings_ms: list[float] = []
    ok_count = 0
    hash_mismatches = 0
    events_mismatches = 0

    with serial.Serial(args.port, baudrate=args.baud, timeout=0.2) as ser:
        print(f"Benchmarking ESP32 on {args.port} ({args.runs} runs)...", file=sys.stderr)

        for run_num in range(1, args.runs + 1):
            # Reset ESP32
            if not args.no_reset:
                reset_esp32(ser)
                time.sleep(args.reset_delay)

            # Read output and measure time
            t0 = time.perf_counter()
            kv, tail = read_esp32_output(ser, timeout_s=args.timeout)
            t1 = time.perf_counter()

            # Validate required keys
            missing = sorted(NEEDED_KEYS - kv.keys())
            if missing:
                print(f"error: run {run_num} missing keys: {', '.join(missing)}", file=sys.stderr)
                if tail:
                    preview = tail[-512:].decode("utf-8", errors="replace")
                    print("error: tail (last 512 bytes):", file=sys.stderr)
                    print(preview, file=sys.stderr)
                continue

            # Extract values
            ok = kv.get("VM_OK", "0")
            events = int(kv.get("VM_EVENTS", "0"))
            hash_val = kv.get("VM_TRANSCRIPT_SHA256", "")

            # Validate
            if args.expected_hash and hash_val != args.expected_hash:
                hash_mismatches += 1
                if hash_mismatches == 1:  # Only print first mismatch
                    print(f"warning: run {run_num} hash mismatch: expected {args.expected_hash} got {hash_val}", file=sys.stderr)
            if args.expected_events >= 0 and events != args.expected_events:
                events_mismatches += 1
                if events_mismatches == 1:  # Only print first mismatch
                    print(f"warning: run {run_num} events mismatch: expected {args.expected_events} got {events}", file=sys.stderr)

            if ok == "1":
                ok_count += 1

            timing_ms = (t1 - t0) * 1000.0
            timings_ms.append(timing_ms)

            if run_num % 10 == 0:
                print(f"  run {run_num}/{args.runs}...", file=sys.stderr)

    if not timings_ms:
        print("error: no successful runs", file=sys.stderr)
        return 1

    mean = statistics.mean(timings_ms)
    stdev = statistics.pstdev(timings_ms) if len(timings_ms) > 1 else 0.0
    print(f"runs: {len(timings_ms)} ok: {ok_count}")
    if hash_mismatches > 0:
        print(f"hash_mismatches: {hash_mismatches}")
    if events_mismatches > 0:
        print(f"events_mismatches: {events_mismatches}")
    print(f"ms mean: {mean:.3f} stdev: {stdev:.3f}")
    print(f"ms min: {min(timings_ms):.3f} p50: {percentile(timings_ms, 0.50):.3f} p95: {percentile(timings_ms, 0.95):.3f} max: {max(timings_ms):.3f}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main(sys.argv[1:]))
