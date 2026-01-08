import * as THREE from "https://unpkg.com/three@0.160.0/build/three.module.js";

const canvas = document.getElementById("c");
const statusEl = document.getElementById("status");
const devicesEl = document.getElementById("devices");
const logEl = document.getElementById("log");

const scene = new THREE.Scene();
scene.background = new THREE.Color(0x0b1020);

const camera = new THREE.PerspectiveCamera(55, 1, 0.1, 100);
camera.position.set(0, 3.0, 7.5);

const renderer = new THREE.WebGLRenderer({ canvas, antialias: true });
renderer.setPixelRatio(Math.min(devicePixelRatio, 2));

scene.add(new THREE.AmbientLight(0xffffff, 0.45));
const light = new THREE.DirectionalLight(0xffffff, 1.0);
light.position.set(6, 8, 3);
scene.add(light);

const nodeGroup = new THREE.Group();
scene.add(nodeGroup);

function addLogLine(s) {
  const div = document.createElement("div");
  div.className = "line";
  div.textContent = s;
  logEl.prepend(div);
  const max = 140;
  while (logEl.childNodes.length > max) logEl.removeChild(logEl.lastChild);
}

function shortSha(s) {
  if (!s) return "";
  const i = s.indexOf(":");
  const h = i >= 0 ? s.slice(i + 1) : s;
  return h.slice(0, 10);
}

function hashColor(id) {
  let h = 2166136261;
  for (let i = 0; i < id.length; i++) {
    h ^= id.charCodeAt(i);
    h = Math.imul(h, 16777619);
  }
  const hue = (h >>> 0) % 360;
  const c = new THREE.Color();
  c.setHSL(hue / 360, 0.72, 0.55);
  return c;
}

function pulse(mesh) {
  const birth = performance.now();
  const ttl = 260;
  const base = mesh.material.emissiveIntensity ?? 0.0;
  mesh.material.emissiveIntensity = 0.9;
  function fade() {
    const t = (performance.now() - birth) / ttl;
    if (t >= 1) {
      mesh.material.emissiveIntensity = base;
      return;
    }
    mesh.material.emissiveIntensity = base + (1 - t) * 0.9;
    requestAnimationFrame(fade);
  }
  fade();
}

const devices = new Map(); // id -> {mesh, color, last}

function layoutNodes() {
  const ids = [...devices.keys()].sort();
  const r = 2.4;
  const n = ids.length;
  ids.forEach((id, idx) => {
    const a = (idx / Math.max(1, n)) * Math.PI * 2;
    const x = Math.cos(a) * r;
    const z = Math.sin(a) * r;
    const mesh = devices.get(id).mesh;
    mesh.position.set(x, 0, z);
  });
}

function ensureDevice(id) {
  if (devices.has(id)) return devices.get(id);
  const color = hashColor(id);
  const g = new THREE.SphereGeometry(0.38, 32, 32);
  const m = new THREE.MeshStandardMaterial({
    color,
    roughness: 0.35,
    metalness: 0.15,
    emissive: color.clone().multiplyScalar(0.15),
    emissiveIntensity: 0.0,
  });
  const mesh = new THREE.Mesh(g, m);
  nodeGroup.add(mesh);
  const entry = { mesh, color, last: {} };
  devices.set(id, entry);
  layoutNodes();
  renderDeviceCards();
  return entry;
}

function renderDeviceCards() {
  devicesEl.innerHTML = "";
  const ids = [...devices.keys()].sort();
  for (const id of ids) {
    const d = devices.get(id);
    const div = document.createElement("div");
    div.className = "dev";
    const ok = d.last.ok;
    const okTxt = ok === true ? "ok" : ok === false ? "fail" : "—";
    const ev = d.last.events ?? "—";
    const exec = d.last.exec_ms ?? "—";
    const state = d.last.transcript_hash ? shortSha(d.last.transcript_hash) : "—";
    const fano = d.last.fano_hash ? shortSha(d.last.fano_hash) : "—";
    const ip = d.last.ip ?? "—";

    div.innerHTML = `
      <div class="id">${id}</div>
      <div class="meta">
        ip=${ip}<br/>
        ok=${okTxt} events=${ev} exec_ms=${exec}<br/>
        state=${state} fano=${fano}
      </div>
    `;
    devicesEl.appendChild(div);
  }
}

function handleEvent(ev) {
  if (ev.type === "announce" && ev.id) {
    const d = ensureDevice(ev.id);
    d.last.ip = ev.ip || d.last.ip;
    renderDeviceCards();
    addLogLine(`[${ev.idx}] announce ${ev.id} ip=${ev.ip || ""}`);
    return;
  }

  if ((ev.type === "events" || ev.type === "status") && ev.device) {
    const d = ensureDevice(ev.device);
    d.last = { ...d.last, ...ev };
    pulse(d.mesh);
    renderDeviceCards();
    if (ev.type === "events") {
      addLogLine(
        `[${ev.idx}] ${ev.device} events ok=${ev.ok} events=${ev.events} exec_ms=${ev.exec_ms ?? ""} state=${shortSha(ev.transcript_hash)} fano=${shortSha(ev.fano_hash)}`
      );
    } else {
      addLogLine(`[${ev.idx}] ${ev.device} status ${ev.status || ""} size=${ev.size ?? ""}`);
    }
  }
}

function connect() {
  statusEl.textContent = "connecting…";
  const es = new EventSource("/events");
  es.onopen = () => (statusEl.textContent = "connected");
  es.onerror = () => (statusEl.textContent = "disconnected");
  es.onmessage = (msg) => {
    try {
      const ev = JSON.parse(msg.data);
      handleEvent(ev);
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
  nodeGroup.rotation.y += 0.002;
  renderer.render(scene, camera);
  requestAnimationFrame(animate);
}
animate();
connect();

