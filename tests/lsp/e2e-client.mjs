import net from "node:net";

function send(socket, msg) {
  const json = JSON.stringify(msg);
  const payload = `Content-Length: ${Buffer.byteLength(json, "utf8")}\r\n\r\n${json}`;
  socket.write(payload);
}

function readOne(buffer) {
  const headerEnd = buffer.indexOf("\r\n\r\n");
  if (headerEnd === -1) return null;
  const header = buffer.slice(0, headerEnd).toString("utf8");
  const m = header.match(/Content-Length:\s*(\d+)/i);
  if (!m) throw new Error("Missing Content-Length");
  const len = Number(m[1]);
  const bodyStart = headerEnd + 4;
  const bodyEnd = bodyStart + len;
  if (buffer.length < bodyEnd) return null;
  const body = buffer.slice(bodyStart, bodyEnd).toString("utf8");
  const rest = buffer.slice(bodyEnd);
  return { msg: JSON.parse(body), rest };
}

async function main() {
  const host = process.env.CANVASL_LSP_HOST ?? "127.0.0.1";
  const port = Number(process.env.CANVASL_LSP_PORT ?? "7000");
  const jsonlPath = process.env.CANVASL_JSONL_PATH ?? "/app/tests/canvasl/matrix.base.jsonl";

  const socket = net.createConnection({ host, port });
  let buf = Buffer.alloc(0);

  const pending = new Map();
  socket.on("data", (chunk) => {
    buf = Buffer.concat([buf, chunk]);
    while (true) {
      const parsed = readOne(buf);
      if (!parsed) break;
      buf = parsed.rest;
      const msg = parsed.msg;
      if (typeof msg?.id !== "undefined") {
        const p = pending.get(msg.id);
        if (p) {
          pending.delete(msg.id);
          p.resolve(msg);
        }
      }
    }
  });

  const call = (method, params) =>
    new Promise((resolve, reject) => {
      const id = Math.floor(Math.random() * 1e9);
      pending.set(id, { resolve, reject });
      send(socket, { jsonrpc: "2.0", id, method, params });
      setTimeout(() => reject(new Error(`timeout: ${method}`)), 5000);
    });

  await new Promise((r) => socket.once("connect", r));

  await call("initialize", { processId: null, rootUri: null, capabilities: {} });

  const r1 = await call("canvasl/getCanonicalDigest", { jsonlPath });
  const r2 = await call("canvasl/getCanonicalDigest", { jsonlPath });

  const a = r1.result;
  const b = r2.result;

  for (const k of ["trace_id", "clbc_size", "clbc_first64_hex"]) {
    if (!(k in a) || !(k in b)) throw new Error(`missing key ${k}`);
    if (a[k] !== b[k]) throw new Error(`non-deterministic ${k}: ${a[k]} vs ${b[k]}`);
  }

  socket.end();
}

main().catch((e) => {
  console.error(String(e?.stack ?? e));
  process.exit(1);
});










