#!/usr/bin/env python3
"""
boundary-interior-combinatorial-framework -> ULP seam envelope emitter (Producer).

This adapter is intentionally boring:
- Input: a CanvasL JSONL trace (one JSON object per line).
- Output: port-matroid seam envelopes (NDJSON).
- All numeric-ish values are emitted as strings.
- Facts are fielded: digests + a few stable extracted fields.
"""

from __future__ import annotations

import argparse
import hashlib
import json
from pathlib import Path


def canonical_json(obj: object) -> str:
    return json.dumps(obj, sort_keys=True, separators=(",", ":"), ensure_ascii=True)


def sha256_hex(data: bytes) -> str:
    return hashlib.sha256(data).hexdigest()


def emit_ndjson(obj: dict) -> None:
    # Stable output, but consumer must not rely on ordering.
    print(json.dumps(obj, sort_keys=True, separators=(",", ":"), ensure_ascii=True))

def component_prefix(namespace: str) -> str:
    parts = namespace.split(".")
    if len(parts) < 4 or parts[0:2] != ["ulp", "trace"]:
        raise SystemExit(f"namespace invalid (expected ulp.trace.<producer>.*.vN): {namespace!r}")
    return parts[2] + "__"


def main() -> int:
    ap = argparse.ArgumentParser(description="Emit ULP seam envelopes from CanvasL JSONL.")
    ap.add_argument("--input", required=True, help="Path to CanvasL JSONL file")
    ap.add_argument("--namespace", default="ulp.trace.boundary_interior.canvasl.v0")
    ap.add_argument("--writer", default="boundary-interior-combinatorial-framework")
    ap.add_argument("--epoch", type=int, default=1)
    ap.add_argument("--gen", type=int, default=1)
    ap.add_argument("--owner-mask", type=int, default=15)
    args = ap.parse_args()
    prefix = component_prefix(args.namespace)

    in_path = Path(args.input)
    raw_lines = [l for l in in_path.read_text().splitlines() if l.strip()]
    records = [json.loads(l) for l in raw_lines]

    authority = {"kind": "direct", "basis": []}
    meta = {"writer": args.writer, "epoch": args.epoch, "gen": args.gen}

    def env(payload: dict) -> dict:
        return {
            "namespace": args.namespace,
            "authority": authority,
            "meta": meta,
            "payload": payload,
        }

    # Trace root entity
    trace_eid = 1
    emit_ndjson(env({"op": "create_entity", "eid": trace_eid, "etype": "trace", "owner_mask": args.owner_mask}))
    emit_ndjson(env({"op": "set_component_string", "eid": trace_eid, "key": prefix + "trace_kind", "value": "canvasl_jsonl"}))
    emit_ndjson(env({"op": "set_component_string", "eid": trace_eid, "key": prefix + "trace_source", "value": in_path.name}))
    emit_ndjson(env({"op": "set_component_string", "eid": trace_eid, "key": prefix + "trace_record_count", "value": str(len(records))}))

    rec_digests: list[str] = []

    # Record entities
    for idx, rec in enumerate(records):
        eid = 2 + idx
        emit_ndjson(env({"op": "create_entity", "eid": eid, "etype": "record", "owner_mask": args.owner_mask}))

        canon = canonical_json(rec)
        digest = "sha256:" + sha256_hex(canon.encode("utf-8"))
        rec_digests.append(digest)

        # Extract a few stable fields if present.
        schema = rec.get("schema", "")
        phase = rec.get("phase", "")
        kind = rec.get("kind", "")
        rtype = rec.get("type", "")

        emit_ndjson(env({"op": "set_component_string", "eid": eid, "key": prefix + "record_kind", "value": "canvasl_record"}))
        emit_ndjson(env({"op": "set_component_string", "eid": eid, "key": prefix + "record_index", "value": str(idx)}))
        if schema != "":
            emit_ndjson(env({"op": "set_component_string", "eid": eid, "key": prefix + "record_schema", "value": str(schema)}))
        if phase != "":
            emit_ndjson(env({"op": "set_component_string", "eid": eid, "key": prefix + "record_phase", "value": str(phase)}))
        if kind != "":
            emit_ndjson(env({"op": "set_component_string", "eid": eid, "key": prefix + "record_event_kind", "value": str(kind)}))
        if rtype != "":
            emit_ndjson(env({"op": "set_component_string", "eid": eid, "key": prefix + "record_type", "value": str(rtype)}))
        emit_ndjson(env({"op": "set_component_string", "eid": eid, "key": prefix + "record_digest", "value": digest}))

    # Trace digest binds the ordered record digests (stable across re-encoding).
    trace_digest = "sha256:" + sha256_hex(("\n".join(rec_digests) + "\n").encode("utf-8"))
    emit_ndjson(env({"op": "set_component_string", "eid": trace_eid, "key": prefix + "trace_digest", "value": trace_digest}))

    return 0


if __name__ == "__main__":
    raise SystemExit(main())
