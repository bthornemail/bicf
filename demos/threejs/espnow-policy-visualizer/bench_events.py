#!/usr/bin/env python3
from __future__ import annotations

import argparse
import hashlib
import json
import time
from dataclasses import dataclass
from pathlib import Path
from typing import Optional


SCHEMA_BYTES = (
    b'{"schema":"bicf-envelope@v1",'
    b'"fields":["node","seq","type","mkey","schema_id","deps","state_id"],'
    b'"deps":["prev_state","trace_anchor","content_anchor"],'
    b'"mkey":"rpc/<method>@schema/<schema_id>"}'
)


def sha256_prefixed(b: bytes) -> str:
    return "sha256:" + hashlib.sha256(b).hexdigest()

def hex32_prefixed(h32: bytes) -> str:
    if len(h32) != 32:
        raise ValueError("expected 32 bytes")
    return "sha256:" + h32.hex()


EXPECTED_SCHEMA_ID = sha256_prefixed(SCHEMA_BYTES)


def parse_sha256_prefixed(s: str) -> bytes:
    if not isinstance(s, str):
        raise ValueError("not a string")
    if not s.startswith("sha256:"):
        raise ValueError("missing sha256: prefix")
    h = s[7:]
    if len(h) != 64:
        raise ValueError("sha256 hex must be 64 chars")
    return bytes.fromhex(h)


def u32_le(n: int) -> bytes:
    return bytes((n & 0xFF, (n >> 8) & 0xFF, (n >> 16) & 0xFF, (n >> 24) & 0xFF))


def state_update(prev_state32: bytes, trace_anchor32: bytes, content_anchor32: bytes, node: str, seq: int) -> bytes:
    if len(prev_state32) != 32 or len(trace_anchor32) != 32 or len(content_anchor32) != 32:
        raise ValueError("bad sha256 bytes")
    if len(node) != 1:
        raise ValueError("node must be 1 char")
    buf = b"STATEv1" + prev_state32 + trace_anchor32 + content_anchor32 + node.encode("ascii") + u32_le(seq)
    return hashlib.sha256(buf).digest()


def statement_id(statement_text: str, trace_id32: bytes) -> bytes:
    b = bytearray(b"POLICYv1" + (b"\x00" * 128) + trace_id32)
    s = statement_text.encode("utf-8")[:128]
    b[8 : 8 + len(s)] = s
    return hashlib.sha256(b).digest()


@dataclass
class NodeCtx:
    last_seq: Optional[int] = None
    last_state_id: Optional[str] = None


def main() -> int:
    ap = argparse.ArgumentParser(description="Validate and benchmark espnow-policy-visualizer events.jsonl")
    ap.add_argument("events", type=Path, help="Path to events.jsonl")
    ap.add_argument("--allow-gaps", action="store_true", help="Allow missing seq increments per node")
    ap.add_argument(
        "--verify-state-hash",
        action="store_true",
        help="Verify state_id equals sha256(STATEv1||prev_state||trace_anchor||content_anchor||node||seq_le)",
    )
    ap.add_argument("--iters", type=int, default=1, help="Repeat validation N times for throughput")
    args = ap.parse_args()

    if not args.events.exists():
        raise SystemExit(f"missing file: {args.events}")

    lines = args.events.read_text(encoding="utf-8").splitlines()
    lines = [ln.strip() for ln in lines if ln.strip()]
    if not lines:
        raise SystemExit("empty events file")

    start = time.perf_counter()
    total = 0
    for _ in range(args.iters):
        ctx = {"A": NodeCtx(), "B": NodeCtx(), "C": NodeCtx()}
        for ln in lines:
            total += 1
            try:
                e = json.loads(ln)
            except Exception as ex:
                raise SystemExit(f"invalid json: {ex}: {ln[:200]}")

            node = e.get("node")
            if node not in ("A", "B", "C"):
                raise SystemExit(f"invalid node: {node}")
            seq = e.get("seq")
            if not isinstance(seq, int) or seq < 0:
                raise SystemExit(f"invalid seq: {seq}")

            schema_id = e.get("schema_id")
            if schema_id != EXPECTED_SCHEMA_ID:
                raise SystemExit(f"schema_id mismatch: got {schema_id} expected {EXPECTED_SCHEMA_ID}")

            mkey = e.get("mkey")
            if not isinstance(mkey, str) or not mkey.startswith("rpc/"):
                raise SystemExit(f"invalid mkey: {mkey}")
            if f"@schema/{schema_id}" not in mkey:
                raise SystemExit(f"mkey must include @schema/<schema_id>: {mkey}")

            deps = e.get("deps")
            if not isinstance(deps, list) or len(deps) != 3:
                raise SystemExit(f"deps must be len=3: {deps}")
            prev_state_s, trace_anchor_s, content_anchor_s = deps
            prev_state32 = parse_sha256_prefixed(prev_state_s)
            trace_anchor32 = parse_sha256_prefixed(trace_anchor_s)
            content_anchor32 = parse_sha256_prefixed(content_anchor_s)

            state_id_s = e.get("state_id")
            if not isinstance(state_id_s, str):
                raise SystemExit("missing state_id")
            # Always validate encoding; optionally validate the exact hash rule.
            got_state32 = parse_sha256_prefixed(state_id_s)
            if args.verify_state_hash:
                exp_state32 = state_update(prev_state32, trace_anchor32, content_anchor32, node, seq)
                if got_state32 != exp_state32:
                    raise SystemExit(f"state_id mismatch for node {node} seq {seq}")

            c = ctx[node]
            if c.last_seq is not None:
                # Nodes may reboot during a capture, resetting their local seq/state chain.
                # Detect a reset by non-monotonic seq and restart the local checker.
                if seq <= c.last_seq:
                    c.last_seq = None
                    c.last_state_id = None

            if c.last_seq is not None:
                if not args.allow_gaps and seq != c.last_seq + 1:
                    raise SystemExit(f"seq gap for node {node}: prev={c.last_seq} now={seq}")
                if prev_state_s != c.last_state_id:
                    raise SystemExit(f"prev_state mismatch for node {node} seq {seq}")
            c.last_seq = seq
            c.last_state_id = state_id_s

            if e.get("type") == "decision":
                trace_id_s = e.get("trace_id")
                statement_text = e.get("statement_text")
                statement_id_s = e.get("statement_id")
                if not isinstance(trace_id_s, str) or not isinstance(statement_id_s, str) or not isinstance(statement_text, str):
                    raise SystemExit("decision must include statement_text/statement_id/trace_id")
                # In this demo decision: deps[1]=trace_id, deps[2]=statement_id
                if trace_id_s != trace_anchor_s:
                    raise SystemExit("decision trace_id must equal deps[1]")
                if statement_id_s != content_anchor_s:
                    raise SystemExit("decision statement_id must equal deps[2]")
                exp_sid = hex32_prefixed(statement_id(statement_text, parse_sha256_prefixed(trace_id_s)))
                if statement_id_s != exp_sid:
                    raise SystemExit("statement_id binding mismatch")

    dur = time.perf_counter() - start
    eps = total / dur if dur > 0 else 0.0
    print(f"OK=1 lines={len(lines)} iters={args.iters} total={total} seconds={dur:.4f} events_per_sec={eps:.1f}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
