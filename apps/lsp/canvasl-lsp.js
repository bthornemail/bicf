#!/usr/bin/env node
// Minimal LSP server (no deps) for CanvasL MVP.
// - Implements initialize/shutdown/exit
// - Handles textDocument/didOpen and textDocument/didChange (noop diagnostics for now)
// - Custom methods:
//   - canvasl/getScene
//   - canvasl/getTrace
//   - canvasl/getIncidence

const fs = require("fs");

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

function writeMessage(obj) {
  const json = JSON.stringify(obj);
  const out = `Content-Length: ${Buffer.byteLength(json, "utf8")}\r\n\r\n${json}`;
  process.stdout.write(out);
}

let buf = Buffer.alloc(0);
let shutdownRequested = false;

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
    // MVP: return a deterministic placeholder scene; actual engine wiring comes later.
    return okResponse(id, {
      ContextRoot: {
        ClosureEnvelope: "none",
        StructureProxy: "triangle",
        IncidenceOverlay: { type: "fano", points: [0,1,2,3,4,5,6], lines: [[0,1,3],[0,2,6],[0,4,5],[1,2,4],[1,5,6],[2,3,5],[3,4,6]] },
        TraceLayer: "none",
      },
    });
  }

  if (method === "canvasl/getTrace") {
    return okResponse(id, { transcriptHash: "nrr:0", events: 0 });
  }

  if (method === "canvasl/getIncidence") {
    return okResponse(id, { type: "fano", points: [0,1,2,3,4,5,6], lines: [[0,1,3],[0,2,6],[0,4,5],[1,2,4],[1,5,6],[2,3,5],[3,4,6]] });
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

process.stdin.on("data", (chunk) => {
  buf = Buffer.concat([buf, chunk]);
  while (true) {
    const parsed = readMessage(buf);
    if (!parsed) break;
    buf = parsed.rest;
    const msg = parsed.msg;
    try {
      if (msg && typeof msg.id !== "undefined") {
        const resp = handleRequest(msg);
        writeMessage(resp);
      } else {
        handleNotification(msg);
      }
    } catch (e) {
      if (msg && typeof msg.id !== "undefined") {
        writeMessage(errResponse(msg.id, -32603, String(e && e.message ? e.message : e)));
      }
    }
  }
});


