#!/usr/bin/env node
// Minimal LSP server (no deps) for CanvasL MVP.
// - Implements initialize/shutdown/exit
// - Handles textDocument/didOpen and textDocument/didChange (noop diagnostics for now)
// - Custom methods:
//   - canvasl/getScene
//   - canvasl/getTrace
//   - canvasl/getIncidence

const fs = require("fs");
const cp = require("child_process");
const net = require("net");

function readMessage(buffer) {
  const headerEnd = buffer.indexOf("\r\n\r\n");
  if (headerEnd === -1) return null;
  const header = buffer.slice(0, headerEnd).toString("utf8");
  const match = header.match(/Content-Length:\s*(\d+)/i);
  if (!match) throw new Error("Missing Content-Length");
  const len = Number(match[1]);
  const bodyStart = headerEnd + 4;
  const bodyEnd = bodyStart + len;
  if (buffer.length < bodyEnd) return null;
  const body = buffer.slice(bodyStart, bodyEnd).toString("utf8");
  const rest = buffer.slice(bodyEnd);
  return { msg: JSON.parse(body), rest };
}

function writeMessageTo(stream, obj) {
  const json = JSON.stringify(obj);
  const out = `Content-Length: ${Buffer.byteLength(json, "utf8")}\r\n\r\n${json}`;
  stream.write(out);
}

let shutdownRequested = false;

function runGuile(expr) {
  // Deterministic tooling-only bridge to the Scheme implementation.
  // Returns stdout as utf8 string (trimmed).
  const out = cp.execFileSync("guile", ["-c", expr], { encoding: "utf8" });
  return String(out).trim();
}

function tokenizeSExpr(s) {
  const toks = [];
  let i = 0;
  while (i < s.length) {
    const c = s[i];
    if (c === ";" ) { // comment until newline
      while (i < s.length && s[i] !== "\n") i++;
      continue;
    }
    if (/\s/.test(c)) { i++; continue; }
    if (c === "(" || c === ")" || c === "." || c === "'") { toks.push(c); i++; continue; }
    if (c === '"') {
      let j = i + 1;
      let out = "";
      while (j < s.length) {
        const ch = s[j];
        if (ch === "\\") { out += s[j + 1] ?? ""; j += 2; continue; }
        if (ch === '"') break;
        out += ch; j++;
      }
      toks.push({ t: "str", v: out });
      i = j + 1;
      continue;
    }
    // symbol/number
    let j = i;
    while (j < s.length && !/\s/.test(s[j]) && !"()'".includes(s[j])) j++;
    const atom = s.slice(i, j);
    if (/^-?\d+$/.test(atom)) toks.push({ t: "num", v: Number(atom) });
    else toks.push({ t: "sym", v: atom });
    i = j;
  }
  return toks;
}

function parseSExprTokens(toks) {
  let i = 0;
  function parseOne() {
    const tok = toks[i++];
    if (tok === "(") {
      const arr = [];
      while (toks[i] !== ")") {
        if (i >= toks.length) throw new Error("Unclosed list");
        arr.push(parseOne());
      }
      i++; // )
      return arr;
    }
    if (tok === "'") return parseOne(); // ignore quote marker
    if (tok && typeof tok === "object") return tok;
    throw new Error("Unexpected token: " + String(tok));
  }
  const expr = parseOne();
  return expr;
}

function sexprToJs(x) {
  if (x == null) return null;
  if (typeof x === "string") return x;
  if (x.t === "num") return x.v;
  if (x.t === "str") return x.v;
  if (x.t === "sym") {
    if (x.v === "#t") return true;
    if (x.v === "#f") return false;
    return x.v;
  }
  if (Array.isArray(x)) {
    // alist / dotted pairs often show as: [ {sym:key}, '.', value ]
    // In our emitted scenes we mostly have lists like: (ContextRoot (ClosureEnvelope . none) ...)
    // We'll try to turn any list of pairs into an object; otherwise array.
    const maybeObj = {};
    let allPairs = true;
    for (const el of x) {
      if (Array.isArray(el) && el.length === 3 && el[1] === "." && el[0]?.t === "sym") {
        maybeObj[el[0].v] = sexprToJs(el[2]);
      } else if (Array.isArray(el) && el.length >= 1 && el[0]?.t === "sym") {
        // (Key (a . b) ...) -> treat as nested object with key name
        const key = el[0].v;
        maybeObj[key] = sexprToJs(el.slice(1));
      } else {
        allPairs = false;
        break;
      }
    }
    if (allPairs) return maybeObj;
    return x.map(sexprToJs);
  }
  return x;
}

function okResponse(id, result) {
  return { jsonrpc: "2.0", id, result };
}
function errResponse(id, code, message) {
  return { jsonrpc: "2.0", id, error: { code, message } };
}

function handleRequest(req) {
  const { id, method, params } = req;

  if (method === "initialize") {
    return okResponse(id, {
      capabilities: {
        textDocumentSync: 2, // Incremental
      },
      serverInfo: { name: "canvasl-lsp-mvp", version: "0.1.0" },
    });
  }

  if (method === "shutdown") {
    shutdownRequested = true;
    return okResponse(id, null);
  }

  if (method === "canvasl/getScene") {
    const k = Number(params?.k ?? 3);
    const globalDecision = Boolean(params?.globalDecision ?? false);
    const includeFano = Boolean(params?.includeFano ?? true);
    const expr =
      `(load "${process.cwd()}/src/viz/scene.scm") ` +
      `(write (viz-make-scene ${Number.isFinite(k) ? k : 0} ${globalDecision ? "#t" : "#f"} ${includeFano ? "#t" : "#f"} ` +
      `'(${[0,1,2,3,4,5,6].join(" ")}) ` +
      `'((0 1 3) (0 2 6) (0 4 5) (1 2 4) (1 5 6) (2 3 5) (3 4 6))))`;
    const out = runGuile(expr);
    const sexpr = parseSExprTokens(tokenizeSExpr(out));
    return okResponse(id, sexprToJs(sexpr));
  }

  if (method === "canvasl/getTrace") {
    const clbcPath = params?.clbcPath;
    if (!clbcPath || typeof clbcPath !== "string") {
      return okResponse(id, { ok: false, error: "missing params.clbcPath" });
    }
    // Use the Scheme VM to produce the transcript hash deterministically.
    const expr =
      `(load "${process.cwd()}/tools/clbc-run.scm") ` +
      `(let* ((bytes (read-file-bytes "${clbcPath}")) (res (vm-run-clbc-bytes bytes))) ` +
      `(write res))`;
    const out = runGuile(expr);
    const sexpr = parseSExprTokens(tokenizeSExpr(out));
    const js = sexprToJs(sexpr);
    return okResponse(id, js);
  }

  if (method === "canvasl/getIncidence") {
    return okResponse(id, { type: "fano", points: [0,1,2,3,4,5,6], lines: [[0,1,3],[0,2,6],[0,4,5],[1,2,4],[1,5,6],[2,3,5],[3,4,6]] });
  }

  if (method === "canvasl/getCanonicalDigest") {
    const jsonlPath = params?.jsonlPath;
    if (!jsonlPath || typeof jsonlPath !== "string") {
      return errResponse(id, -32602, "Invalid params: expected { jsonlPath: string }");
    }
    if (!fs.existsSync(jsonlPath)) {
      return errResponse(id, -32602, `Invalid params: jsonlPath not found: ${jsonlPath}`);
    }

    // Canonical bytes identity: trace_id = sha256(CLBC_container_bytes)
    // Return a small witness so E2E can verify byte stability without shipping the full blob.
    const expr = `
      (load "${process.cwd()}/src/canvasl/canvasl1-jsonl.scm")
      (load "${process.cwd()}/src/nrr/hash.scm")
      (define (read-lines p)
        (call-with-input-file p
          (lambda (port)
            (let loop ((out (quote ())))
              (let ((line (read-line port)))
                (if (eof-object? line)
                    (reverse out)
                    (let ((t (string-trim-both line)))
                      (if (or (string=? t "") (char=? (string-ref t 0) #\\#))
                          (loop out)
                          (loop (cons (normalize-record (parse-json-line t)) out))))))))))
      (define recs (read-lines "${jsonlPath.replace(/\\/g, "\\\\").replace(/"/g, '\\"')}"))
      (define clbc-recs (map canvasl1-record->clbc-record recs))
      (define enc (canvasl-records->clbc clbc-recs))
      (define bs (cdr enc))
      (define hex (hash-content bs))
      (define (take n xs) (if (or (<= n 0) (null? xs)) (quote ()) (cons (car xs) (take (- n 1) (cdr xs)))))
      (define first (take 64 bs))
      (define (hex2 n)
        (let* ((h "0123456789abcdef") (hi (quotient n 16)) (lo (modulo n 16)))
          (string (string-ref h hi) (string-ref h lo))))
      (define (bytes->hex bs)
        (let loop ((xs bs) (out (quote ())))
          (if (null? xs)
              (apply string-append (reverse out))
              (loop (cdr xs) (cons (hex2 (car xs)) out)))))
      (write (list
        (cons (quote trace_id) (string-append "sha256:" hex))
        (cons (quote clbc_size) (length bs))
        (cons (quote clbc_first64_hex) (bytes->hex first))
      ))
    `;

    const out = runGuile(expr);
    const sexpr = parseSExprTokens(tokenizeSExpr(out));
    const js = sexprToJs(sexpr);
    return okResponse(id, js);
  }

  return errResponse(id ?? null, -32601, `Method not found: ${method}`);
}

function handleNotification(req) {
  const { method } = req;

  if (method === "exit") {
    process.exit(shutdownRequested ? 0 : 1);
  }
  // didOpen/didChange: ignore in MVP
}

function serveOnStream(stream) {
  let buf = Buffer.alloc(0);
  stream.on("data", (chunk) => {
    buf = Buffer.concat([buf, chunk]);
    while (true) {
      const parsed = readMessage(buf);
      if (!parsed) break;
      buf = parsed.rest;
      const msg = parsed.msg;
      try {
        if (msg && typeof msg.id !== "undefined") {
          const resp = handleRequest(msg);
          writeMessageTo(stream, resp);
        } else {
          handleNotification(msg);
        }
      } catch (e) {
        if (msg && typeof msg.id !== "undefined") {
          writeMessageTo(stream, errResponse(msg.id, -32603, String(e && e.message ? e.message : e)));
        }
      }
    }
  });
}

const port = process.env.CANVASL_LSP_PORT ? Number(process.env.CANVASL_LSP_PORT) : 0;
if (Number.isFinite(port) && port > 0) {
  const server = net.createServer((socket) => {
    // Single client per socket; deterministic, no shared mutable state beyond NRR/files.
    serveOnStream(socket);
  });
  server.listen(port, "0.0.0.0", () => {
    // eslint-disable-next-line no-console
    console.error(`canvasl-lsp listening on tcp:${port}`);
  });
} else {
  serveOnStream(process.stdin);
}


