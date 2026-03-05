#!/usr/bin/env node
import fs from 'node:fs';
import path from 'node:path';
import crypto from 'node:crypto';
import { spawnSync } from 'node:child_process';
import { fileURLToPath } from 'node:url';

const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);
const repoRoot = path.resolve(__dirname, '..');

function arg(name) {
  const idx = process.argv.indexOf(name);
  return idx >= 0 ? process.argv[idx + 1] : null;
}

function sha256File(filePath) {
  return `sha256:${crypto.createHash('sha256').update(fs.readFileSync(filePath)).digest('hex')}`;
}

function main() {
  const outDirArg = arg('--out-dir');
  const outDir = path.resolve(outDirArg || path.join(repoRoot, 'artifacts', 'vm', 'canisa'));
  fs.mkdirSync(outDir, { recursive: true });

  const binPath = path.join(outDir, 'canisa_mvp_vector_runner');
  const compileArgs = [
    '-std=c11',
    '-O2',
    path.join(repoRoot, 'scripts', 'canisa_mvp_vector_runner.c'),
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

  const r = spawnSync(binPath, [], { cwd: repoRoot, encoding: 'utf8' });
  if (r.status !== 0) {
    process.stderr.write(r.stdout || '');
    process.stderr.write(r.stderr || '');
    process.exit(r.status || 1);
  }

  const lines = (r.stdout || '').split('\n').filter(Boolean);
  const cases = lines.map((line) => JSON.parse(line));

  const ndjsonPath = path.join(outDir, 'canisa-run.ndjson');
  const fixedT = '1970-01-01T00:00:00.000Z';
  const events = [];
  events.push({ event: 'canisa.run.start', t: fixedT, payload: { cases: cases.length } });
  for (const cse of cases) {
    events.push({ event: 'canisa.case.end', t: fixedT, payload: cse });
  }
  events.push({ event: 'canisa.run.end', t: fixedT, payload: { ok_cases: cases.filter((x) => x.ok).length } });
  fs.writeFileSync(ndjsonPath, `${events.map((e) => JSON.stringify(e)).join('\n')}\n`);

  const okCase = cases.find((x) => x.case === 'state_hash_path');
  const failCase = cases.find((x) => x.case === 'bad_modulus_expected_failure');
  const pass = Boolean(okCase?.ok && typeof okCase.state_hash === 'string' && okCase.state_hash.startsWith('sha256:') && failCase && failCase.ok === false);

  const check = {
    schema_version: 1,
    runtime: 'canisa-mvp-c',
    pass,
    cases,
    runner_sha256: sha256File(path.join(repoRoot, 'scripts', 'canisa_mvp_vector_runner.c')),
    binary_sha256: sha256File(binPath),
    ndjson_sha256: sha256File(ndjsonPath)
  };

  const checkPath = path.join(outDir, 'canisa-check.json');
  fs.writeFileSync(checkPath, `${JSON.stringify(check, null, 2)}\n`);
  process.stdout.write(`${JSON.stringify(check)}\n`);

  if (!pass) process.exit(2);
}

main();
