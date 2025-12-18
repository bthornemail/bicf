import * as THREE from "https://unpkg.com/three@0.160.0/build/three.module.js";

const canvas = document.getElementById("c");
const statusEl = document.getElementById("status");
const logEl = document.getElementById("log");
const policyTextEl = document.getElementById("policyText");
const policyIdEl = document.getElementById("policyId");
const traceIdEl = document.getElementById("traceId");

const scene = new THREE.Scene();
scene.background = new THREE.Color(0x0b1020);

const camera = new THREE.PerspectiveCamera(55, 1, 0.1, 100);
camera.position.set(0, 2.2, 6.5);

const renderer = new THREE.WebGLRenderer({ canvas, antialias: true });
renderer.setPixelRatio(Math.min(devicePixelRatio, 2));

const light = new THREE.DirectionalLight(0xffffff, 1.0);
light.position.set(5, 5, 2);
scene.add(light);
scene.add(new THREE.AmbientLight(0xffffff, 0.35));

const nodes = {
  A: { pos: new THREE.Vector3(-2.2, 0, 0), color: 0x4cc9f0, label: "A / NRR" },
  B: { pos: new THREE.Vector3(0, 0, 0), color: 0x80ed99, label: "B / Verify" },
  C: { pos: new THREE.Vector3(2.2, 0, 0), color: 0xf72585, label: "C / Orchestrator" },
};

function makeNodeSphere({ pos, color }) {
  const g = new THREE.SphereGeometry(0.35, 32, 32);
  const m = new THREE.MeshStandardMaterial({ color, roughness: 0.35, metalness: 0.1 });
  const mesh = new THREE.Mesh(g, m);
  mesh.position.copy(pos);
  return mesh;
}

const nodeMeshes = {};
for (const k of Object.keys(nodes)) {
  const mesh = makeNodeSphere(nodes[k]);
  scene.add(mesh);
  nodeMeshes[k] = mesh;
}

const arcGroup = new THREE.Group();
scene.add(arcGroup);

function addLogLine(s) {
  const div = document.createElement("div");
  div.className = "line";
  div.textContent = s;
  logEl.prepend(div);
  const max = 120;
  while (logEl.childNodes.length > max) logEl.removeChild(logEl.lastChild);
}

function shortSha(s) {
  if (!s) return "";
  const i = s.indexOf(":");
  const h = i >= 0 ? s.slice(i + 1) : s;
  return h.slice(0, 8);
}

function pulse(mesh, color) {
  const start = performance.now();
  const base = mesh.material.color.clone();
  mesh.material.color.setHex(color);
  function tick() {
    const t = (performance.now() - start) / 250;
    if (t >= 1) {
      mesh.material.color.copy(base);
      return;
    }
    requestAnimationFrame(tick);
  }
  tick();
}

function addArc(from, to, ok) {
  const a = nodes[from]?.pos;
  const b = nodes[to]?.pos;
  if (!a || !b) return;

  const mid = a.clone().lerp(b, 0.5);
  mid.y += 0.7;
  const curve = new THREE.QuadraticBezierCurve3(a, mid, b);
  const pts = curve.getPoints(24);
  const g = new THREE.BufferGeometry().setFromPoints(pts);
  const m = new THREE.LineBasicMaterial({ color: ok ? 0x7cfc00 : 0xff6b6b, transparent: true, opacity: 0.9 });
  const line = new THREE.Line(g, m);
  arcGroup.add(line);

  const birth = performance.now();
  const ttl = 800;
  function fade() {
    const t = (performance.now() - birth) / ttl;
    if (t >= 1) {
      arcGroup.remove(line);
      g.dispose();
      m.dispose();
      return;
    }
    m.opacity = 0.9 * (1 - t);
    requestAnimationFrame(fade);
  }
  fade();
}

function handleEvent(obj) {
  const e = obj.event;
  const node = e.node;
  const type = e.type;
  const mkey = e.mkey || "";
  const ok = e.ok;

  if (nodeMeshes[node]) pulse(nodeMeshes[node], nodes[node].color);

  if (type === "rpc") {
    const to = e.to || (node === "C" ? "?" : "C");
    if (to === "A" || to === "B" || to === "C") addArc(node, to, ok !== 0);
    addLogLine(`[${obj.idx}] ${node} rpc ${mkey.split("@")[0]} ok=${ok ?? ""} state=${shortSha(e.state_id)}`);
  } else if (type === "decision") {
    const txt = e.statement_text || "decision";
    policyTextEl.textContent = txt;
    policyIdEl.textContent = e.statement_id ? `statement_id=${shortSha(e.statement_id)}…` : "";
    traceIdEl.textContent = e.trace_id ? `trace_id=${shortSha(e.trace_id)}…` : "";
    addLogLine(`[${obj.idx}] ${node} decision ok=${ok ?? ""} statement_id=${shortSha(e.statement_id)}`);
  } else {
    addLogLine(`[${obj.idx}] ${node} ${type} ${mkey.split("@")[0]} state=${shortSha(e.state_id)}`);
  }
}

function connect() {
  statusEl.textContent = "connecting…";
  const es = new EventSource("/events");
  es.onopen = () => {
    statusEl.textContent = "connected";
  };
  es.onerror = () => {
    statusEl.textContent = "disconnected";
  };
  es.onmessage = (msg) => {
    try {
      const obj = JSON.parse(msg.data);
      handleEvent(obj);
    } catch {}
  };
}

function resize() {
  const w = canvas.clientWidth;
  const h = canvas.clientHeight;
  camera.aspect = w / h;
  camera.updateProjectionMatrix();
  renderer.setSize(w, h, false);
}
window.addEventListener("resize", resize);
resize();

function animate() {
  renderer.render(scene, camera);
  requestAnimationFrame(animate);
}
animate();
connect();

