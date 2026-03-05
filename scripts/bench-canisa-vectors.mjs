#!/usr/bin/env node
import fs from 'node:fs';
import path from 'node:path';
import crypto from 'node:crypto';
import { spawnSync } from 'node:child_process';
import { fileURLToPath } from 'node:url';

const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);
const repoRoot = path.resolve(__dirname, '..');

function arg(name, fallback = null) {
  const idx = process.argv.indexOf(name);
  if (idx === -1) return fallback;
  return process.argv[idx + 1] ?? fallback;
}

function sha256File(filePath) {
  return `sha256:${crypto.createHash('sha256').update(fs.readFileSync(filePath)).digest('hex')}`;
}

function main() {
  const outDir = path.resolve(arg('--out-dir', path.join(repoRoot, 'artifacts', 'vm', 'canisa')));
  const warmup = Number(arg('--warmup', '100'));
  const iterations = Number(arg('--iterations', '10000'));
  fs.mkdirSync(outDir, { recursive: true });

  const binPath = path.join(outDir, 'canisa_mvp_bench_runner');
  const compileArgs = [
    '-std=c11',
    '-O2',
    path.join(repoRoot, 'scripts', 'canisa_mvp_bench_runner.c'),
    path.join(repoRoot, 'embedded', 'canisa-mvp', 'canisa_mvp.c'),
    path.join(repoRoot, 'embedded', 'canisa-mvp', 'canisa_poly_f2.c'),
    path.join(repoRoot, 'embedded', 'canisa-mvp', 'sha256.c'),
    '-o',
    binPath
  ];
  const c = spawnSync('gcc', compileArgs, { cwd: repoRoot, encoding: 'utf8' });
  if (c.status !== 0) {
    process.stderr.write(c.stdout || '');
    process.stderr.write(c.stderr || '');
    process.exit(c.status || 1);
  }

  const t0 = process.hrtime.bigint();
  const r = spawnSync(binPath, [String(warmup), String(iterations)], { cwd: repoRoot, encoding: 'utf8' });
  const t1 = process.hrtime.bigint();
  if (r.status !== 0) {
    process.stderr.write(r.stdout || '');
    process.stderr.write(r.stderr || '');
    process.exit(r.status || 1);
  }

  const result = JSON.parse((r.stdout || '').trim());

  const benchNdjsonPath = path.join(outDir, 'canisa-bench.ndjson');
  const events = [
    {
      event: 'vm.bench.start',
      seq: 1,
      payload: { runtime: 'canisa-mvp-c', case: 'state_hash_path', warmup, iterations }
    },
    {
      event: 'vm.bench.metric',
      seq: 2,
      payload: {
        runtime: 'canisa-mvp-c',
        case: 'state_hash_path',
        metric: 'exec_ns',
        total: result.total_ns,
        ns_per_iter: result.ns_per_iter,
        ops_per_sec: result.ops_per_sec
      }
    },
    {
      event: 'vm.bench.end',
      seq: 3,
      payload: {
        runtime: 'canisa-mvp-c',
        case: 'state_hash_path',
        pass: result.ok,
        state_hash: result.state_hash,
        fano_hash: result.fano_hash
      }
    }
  ];
  fs.writeFileSync(benchNdjsonPath, `${events.map((e) => JSON.stringify(e)).join('\n')}\n`);

  const summary = {
    schema_version: 1,
    runtime: 'canisa-mvp-c',
    case: 'state_hash_path',
    warmup_iterations: warmup,
    iterations,
    pass: Boolean(result.ok),
    compile_ns: Number(t1 - t0),
    exec_ns: {
      total: result.total_ns,
      ns_per_iter: result.ns_per_iter,
      ops_per_sec: result.ops_per_sec
    },
    hashes: {
      state_hash: result.state_hash,
      fano_hash: result.fano_hash
    },
    artifacts: {
      bench_ndjson_sha256: sha256File(benchNdjsonPath),
      binary_sha256: sha256File(binPath),
      runner_sha256: sha256File(path.join(repoRoot, 'scripts', 'canisa_mvp_bench_runner.c'))
    }
  };

  const summaryPath = path.join(outDir, 'canisa-bench.json');
  fs.writeFileSync(summaryPath, `${JSON.stringify(summary, null, 2)}\n`);
  process.stdout.write(`${JSON.stringify(summary)}\n`);

  if (!summary.pass) process.exit(2);
}

main();
