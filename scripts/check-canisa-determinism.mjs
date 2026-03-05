#!/usr/bin/env node
import fs from 'node:fs';
import os from 'node:os';
import path from 'node:path';
import { spawnSync } from 'node:child_process';
import { fileURLToPath } from 'node:url';

const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);
const repoRoot = path.resolve(__dirname, '..');
const runner = path.join(repoRoot, 'scripts', 'run-canisa-vectors.mjs');

function run(outDir) {
  const p = spawnSync('node', [runner, '--out-dir', outDir], {
    cwd: repoRoot,
    encoding: 'utf8'
  });
  if (p.status !== 0) {
    process.stderr.write(p.stdout || '');
    process.stderr.write(p.stderr || '');
    process.exit(p.status || 1);
  }
  return JSON.parse(fs.readFileSync(path.join(outDir, 'canisa-check.json'), 'utf8'));
}

const base = fs.mkdtempSync(path.join(os.tmpdir(), 'canisa-det-'));
const a = path.join(base, 'a');
const b = path.join(base, 'b');
fs.mkdirSync(a, { recursive: true });
fs.mkdirSync(b, { recursive: true });

const ca = run(a);
const cb = run(b);

const stable = ca.ndjson_sha256 === cb.ndjson_sha256 && ca.cases?.[0]?.state_hash === cb.cases?.[0]?.state_hash && ca.cases?.[0]?.fano_hash === cb.cases?.[0]?.fano_hash;
const out = {
  schema_version: 1,
  runtime: 'canisa-mvp-c',
  stable,
  run_a: {
    ndjson_sha256: ca.ndjson_sha256,
    state_hash: ca.cases?.[0]?.state_hash,
    fano_hash: ca.cases?.[0]?.fano_hash
  },
  run_b: {
    ndjson_sha256: cb.ndjson_sha256,
    state_hash: cb.cases?.[0]?.state_hash,
    fano_hash: cb.cases?.[0]?.fano_hash
  }
};

process.stdout.write(`${JSON.stringify(out)}\n`);
if (!stable) process.exit(2);
