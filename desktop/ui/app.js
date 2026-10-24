/* MoonPet — app.js
 * Pet AI offline: digambar prosedural (tanpa aset), chat LLM lokal via llama-server,
 * interaksi sayang & siksa dengan umpan balik visual. Bahasa UI: Indonesia.
 */
"use strict";
(() => {
const $ = (s) => document.querySelector(s);
const clamp = (v, a, b) => Math.max(a, Math.min(b, v));
const rand = (a, b) => a + Math.random() * (b - a);
const pick = (arr) => arr[Math.floor(Math.random() * arr.length)];
const TAU = Math.PI * 2;

/* ================== STATE ================== */
const LS = "moonpet-v1";
const defaults = {
  hits: 0, pats: 0, feeds: 0, hugs: 0, chats: 0, kos: 0, xp: 0, mood: 72,
  bruises: [], achievements: [], chatLog: [],
};
let S = load();
function load() {
  try { return Object.assign({}, defaults, JSON.parse(localStorage.getItem(LS) || "{}")); }
  catch { return { ...defaults }; }
}
function save() { localStorage.setItem(LS, JSON.stringify(S)); }

/* ================== AUDIO (sintetis, tanpa aset) ================== */
let AC = null;
function ac() {
  if (!AC) { try { AC = new (window.AudioContext || window.webkitAudioContext)(); } catch {} }
  if (AC && AC.state === "suspended") AC.resume();
  return AC;
}
function tone(freq, dur, type = "sine", vol = .18, bend = 0) {
  const a = ac(); if (!a) return;
  const o = a.createOscillator(), g = a.createGain();
  o.type = type; o.frequency.value = freq;
  if (bend) o.frequency.exponentialRampToValueAtTime(Math.max(30, freq + bend), a.currentTime + dur);
  g.gain.value = vol;
  g.gain.exponentialRampToValueAtTime(.0001, a.currentTime + dur);
  o.connect(g).connect(a.destination); o.start(); o.stop(a.currentTime + dur);
}
function noise(dur = .09, vol = .22) {
  const a = ac(); if (!a) return;
  const buf = a.createBuffer(1, a.sampleRate * dur, a.sampleRate);
  const d = buf.getChannelData(0);
  for (let i = 0; i < d.length; i++) d[i] = (Math.random() * 2 - 1) * (1 - i / d.length);
  const src = a.createBufferSource(); src.buffer = buf;
  const g = a.createGain(); g.gain.value = vol;
  const f = a.createBiquadFilter(); f.type = "lowpass"; f.frequency.value = 900;
  src.connect(f).connect(g).connect(a.destination); src.start();
}
const SFX = {
  pat: () => { tone(520, .12, "sine", .12, 260); },
  feed: () => { tone(340, .08, "triangle", .14); setTimeout(() => tone(480, .1, "triangle", .12), 90); },
  hug: () => { tone(300, .5, "sine", .08, 120); tone(450, .5, "sine", .05, 150); },
  slap: () => { noise(.07, .3); tone(120, .09, "sine", .25, -60); },
  bonk: () => { tone(180, .16, "square", .2, -120); noise(.05, .15); },
  pinch: () => { tone(700, .1, "sawtooth", .08, -350); },
  throwWoosh: () => { noise(.28, .1); },
  bounce: () => { tone(240, .18, "sine", .2, 420); },
  meow: () => { tone(620, .14, "sawtooth", .07, 180); setTimeout(() => tone(520, .18, "sawtooth", .06, -160), 120); },
  ko: () => { tone(300, .5, "sine", .2, -240); },
  revive: () => { tone(400, .3, "sine", .1, 500); setTimeout(() => tone(800, .25, "sine", .08, 200), 200); },
  achieve: () => { tone(660, .1, "triangle", .14); setTimeout(() => tone(880, .18, "triangle", .12), 110); },
};

/* ================== MOOD ================== */
const MOODS = [
  { min: 70, id: "senang", label: "senang" },
  { min: 40, id: "biasa", label: "biasa saja" },
  { min: 15, id: "sedih", label: "sedih" },
  { min: -1, id: "ngambek", label: "ngambek" },
];
function moodNow() { return MOODS.find((m) => S.mood >= m.min); }
function addMood(d) { S.mood = clamp(S.mood + d, 0, 100); save(); renderChips(); }
function bondLv() { return Math.floor(Math.sqrt(S.xp / 40)) + 1; }

/* ================== PET ENGINE ================== */
const petC = $("#pet"), pctx = petC.getContext("2d");
const skyC = $("#sky"), sctx = skyC.getContext("2d");
let W = 0, H = 0, DPR = Math.min(2, window.devicePixelRatio || 1);
function resize() {
  W = innerWidth; H = innerHeight;
  for (const c of [petC, skyC]) { c.width = W * DPR; c.height = H * DPR; }
  pctx.setTransform(DPR, 0, 0, DPR, 0, 0); sctx.setTransform(DPR, 0, 0, DPR, 0, 0);
}
addEventListener("resize", resize); resize();

const pet = {
  x: 0, y: 0, vx: 0, vy: 0, rot: 0, vrot: 0,
  sx: 1, sy: 1, targetSx: 1, targetSy: 1,
  state: "idle", stateT: 0, blink: 0, blinkT: rand(2, 5),
  ko: false, koT: 0, respawnT: 0, ghost: 0,
  facing: 1, tailPhase: 0, breathe: 0, dizzySpin: 0,
  chatBubble: null, bubbleT: 0,
};
function petBase() { return { x: W / 2, y: H * 0.62 }; }
function resetPet() { const b = petBase(); pet.x = b.x; pet.y = b.y; pet.vx = pet.vy = pet.vrot = pet.rot = 0; pet.sx = pet.sy = 1; pet.ko = false; pet.ghost = 0; }
pet.x = W / 2; pet.y = H * 0.62;

let shake = 0;
function addShake(v) { shake = Math.min(26, shake + v); }

/* partikel */
const parts = [];
function spawnParts(kind, n, x, y) {
  for (let i = 0; i < n; i++) {
    const ang = rand(0, TAU), sp = rand(60, 320);
    parts.push({
      kind, x, y, vx: Math.cos(ang) * sp, vy: Math.sin(ang) * sp - 60,
      life: rand(.5, 1.1), t: 0, size: rand(6, 16), rot: rand(0, TAU),
      hue: kind === "heart" ? rand(320, 345) : kind === "star" ? rand(45, 60) : rand(260, 285),
    });
  }
}

/* ---- gambar Momo ---- */
function drawMomo(ctx, t) {
  const R = clamp(Math.min(W, H) * 0.11, 46, 92); // radius badan
  ctx.save();
  ctx.translate(pet.x + rand(-1, 1) * shake * .3, pet.y + rand(-1, 1) * shake * .3);
  ctx.rotate(pet.rot);
  ctx.scale(pet.facing * pet.sx, pet.sy);
  if (pet.ghost > 0) ctx.globalAlpha = 0.35 + 0.3 * Math.sin(t * 6);
  if (pet.ko) { ctx.rotate(0); ctx.scale(1, 0.55); ctx.translate(0, R * .45); }

  const breathe = 1 + 0.018 * Math.sin(pet.breathe);
  const bodyGrad = ctx.createRadialGradient(-R * .3, -R * .35, R * .2, 0, 0, R * 1.15);
  bodyGrad.addColorStop(0, "#F4F0FB");
  bodyGrad.addColorStop(0.65, "#E8E3F5");
  bodyGrad.addColorStop(1, "#C9C0E4");

  /* ekor */
  ctx.save();
  ctx.strokeStyle = "#C9C0E4"; ctx.lineWidth = R * .16; ctx.lineCap = "round";
  const tx = R * 0.95, ty = R * .25, sway = Math.sin(pet.tailPhase) * R * .28;
  ctx.beginPath();
  ctx.moveTo(tx * .6, ty);
  ctx.quadraticCurveTo(tx + R * .35, ty - R * .5 + sway, tx + R * .25, ty - R * .95 + sway * .6);
  ctx.stroke();
  ctx.restore();

  /* badan */
  ctx.beginPath();
  ctx.ellipse(0, 0, R * breathe, R * .92 * breathe, 0, 0, TAU);
  ctx.fillStyle = bodyGrad; ctx.fill();
  ctx.strokeStyle = "#b9b0d8"; ctx.lineWidth = 2; ctx.stroke();

  /* telinga */
  for (const side of [-1, 1]) {
    ctx.beginPath();
    ctx.moveTo(side * R * .52, -R * .62);
    ctx.lineTo(side * R * .78, -R * 1.42);
    ctx.lineTo(side * R * .95, -R * .55);
    ctx.closePath();
    ctx.fillStyle = "#E8E3F5"; ctx.fill();
    ctx.strokeStyle = "#b9b0d8"; ctx.lineWidth = 2; ctx.stroke();
    ctx.beginPath();
    ctx.moveTo(side * R * .63, -R * .74);
    ctx.lineTo(side * R * .76, -R * 1.2);
    ctx.lineTo(side * R * .85, -R * .68);
    ctx.closePath();
    ctx.fillStyle = "#f2b8cf"; ctx.fill();
  }

  /* memar (kartun) */
  for (const b of S.bruises) {
    ctx.beginPath();
    ctx.ellipse(b.x * R, b.y * R, R * .13, R * .09, b.r, 0, TAU);
    ctx.fillStyle = "rgba(120,90,170,.45)"; ctx.fill();
    ctx.strokeStyle = "rgba(90,140,90,.35)"; ctx.lineWidth = 1.5; ctx.stroke();
  }
  /* plester setelah banyak memar */
  if (S.bruises.length >= 3) {
    ctx.save(); ctx.translate(-R * .45, -R * .78); ctx.rotate(-.5);
    ctx.fillStyle = "#f5e6c8"; ctx.fillRect(-R * .3, -R * .09, R * .6, R * .18);
    ctx.fillStyle = "#e8d5b0"; ctx.fillRect(-R * .3, -R * .09, R * .1, R * .18); ctx.fillRect(R * .2, -R * .09, R * .1, R * .18);
    ctx.restore();
  }

  /* mata */
  const eyeY = -R * .1, eyeX = R * .3;
  ctx.lineWidth = Math.max(3, R * .07); ctx.strokeStyle = "#2d2a44"; ctx.lineCap = "round";
  if (pet.ko || pet.state === "ko") {
    for (const side of [-1, 1]) {
      const ex = side * eyeX;
      ctx.beginPath();
      ctx.moveTo(ex - R * .12, eyeY - R * .12); ctx.lineTo(ex + R * .12, eyeY + R * .12);
      ctx.moveTo(ex + R * .12, eyeY - R * .12); ctx.lineTo(ex - R * .12, eyeY + R * .12);
      ctx.stroke();
    }
  } else if (pet.state === "dizzy") {
    pet.dizzySpin += 0.25;
    for (const side of [-1, 1]) {
      const ex = side * eyeX;
      ctx.beginPath();
      for (let a = 0; a < TAU * 1.8; a += .25) {
        const rr = a * R * .035;
        const px = ex + Math.cos(a + pet.dizzySpin) * rr, py = eyeY + Math.sin(a + pet.dizzySpin) * rr;
        a === 0 ? ctx.moveTo(px, py) : ctx.lineTo(px, py);
      }
      ctx.stroke();
    }
  } else if (pet.state === "happy" || pet.state === "hug" || pet.state === "eat") {
    for (const side of [-1, 1]) {
      ctx.beginPath();
      ctx.arc(side * eyeX, eyeY + R * .05, R * .14, Math.PI * 1.15, Math.PI * 1.85);
      ctx.stroke();
    }
  } else if (pet.state === "sulk") {
    for (const side of [-1, 1]) {
      const ex = side * eyeX;
      ctx.beginPath(); ctx.moveTo(ex - R * .13, eyeY - R * .16); ctx.lineTo(ex + R * .13, eyeY - R * .04); ctx.stroke();
      ctx.beginPath(); ctx.arc(ex, eyeY + R * .06, R * .1, 0, TAU); ctx.fillStyle = "#2d2a44"; ctx.fill();
    }
  } else if (pet.blink > 0) {
    for (const side of [-1, 1]) {
      ctx.beginPath(); ctx.moveTo(side * eyeX - R * .13, eyeY); ctx.lineTo(side * eyeX + R * .13, eyeY); ctx.stroke();
    }
  } else {
    for (const side of [-1, 1]) {
      const ex = side * eyeX;
      ctx.beginPath(); ctx.arc(ex, eyeY, R * .13, 0, TAU); ctx.fillStyle = "#2d2a44"; ctx.fill();
      ctx.beginPath(); ctx.arc(ex + R * .04, eyeY - R * .05, R * .035, 0, TAU); ctx.fillStyle = "#fff"; ctx.fill();
    }
  }

  /* mulut kucing :3 */
  const my = R * .22;
  ctx.strokeStyle = "#2d2a44"; ctx.lineWidth = Math.max(2, R * .05);
  if (pet.state === "happy" || pet.state === "hug") {
    ctx.beginPath(); ctx.arc(0, my - R * .06, R * .12, .15, Math.PI - .15); ctx.stroke();
  } else if (pet.state === "sulk" || pet.state === "dizzy") {
    ctx.beginPath(); ctx.arc(0, my + R * .1, R * .09, Math.PI + .2, TAU - .2); ctx.stroke();
  } else {
    ctx.beginPath();
    ctx.moveTo(-R * .1, my); ctx.quadraticCurveTo(-R * .04, my + R * .07, 0, my);
    ctx.quadraticCurveTo(R * .04, my + R * .07, R * .1, my);
    ctx.stroke();
  }

  /* rona pipi */
  for (const side of [-1, 1]) {
    ctx.beginPath(); ctx.ellipse(side * R * .52, R * .12, R * .1, R * .06, 0, 0, TAU);
    ctx.fillStyle = "rgba(242,184,207,.75)"; ctx.fill();
  }
  /* kumis */
  ctx.strokeStyle = "#b9b0d8"; ctx.lineWidth = 1.5;
  for (const side of [-1, 1]) for (let i = 0; i < 3; i++) {
    ctx.beginPath();
    ctx.moveTo(side * R * .55, -R * .05 + i * R * .09);
    ctx.lineTo(side * R * .95, -R * .12 + i * R * .13);
    ctx.stroke();
  }
  ctx.restore();

  /* gelembung ucapan singkat */
  if (pet.chatBubble && pet.bubbleT > 0) {
    const txt = pet.chatBubble;
    ctx.save();
    ctx.font = `${clamp(R * .18, 12, 18)}px "Segoe UI", sans-serif`;
    const tw = Math.min(ctx.measureText(txt).width + 24, W * .5);
    const bx = clamp(pet.x, tw / 2 + 12, W - tw / 2 - 12), by = pet.y - R * 1.9;
    ctx.fillStyle = "#1d1a30f0"; ctx.strokeStyle = "#8b5cf6";
    roundRect(ctx, bx - tw / 2, by - 16, tw, 34, 10); ctx.fill(); ctx.stroke();
    ctx.fillStyle = "#E8E3F5"; ctx.textAlign = "center"; ctx.textBaseline = "middle";
    ctx.fillText(txt, bx, by + 2, W * .48);
    ctx.restore();
  }
}
function roundRect(ctx, x, y, w, h, r) {
  ctx.beginPath();
  ctx.moveTo(x + r, y);
  ctx.arcTo(x + w, y, x + w, y + h, r); ctx.arcTo(x + w, y + h, x, y + h, r);
  ctx.arcTo(x, y + h, x, y, r); ctx.arcTo(x, y, x + w, y, r);
  ctx.closePath();
}
function drawHeart(ctx, p) {
  ctx.save(); ctx.translate(p.x, p.y); ctx.rotate(p.rot); ctx.scale(p.size / 14, p.size / 14);
  ctx.beginPath();
  ctx.moveTo(0, 4);
  ctx.bezierCurveTo(-10, -6, -4, -12, 0, -6);
  ctx.bezierCurveTo(4, -12, 10, -6, 0, 4);
  ctx.fillStyle = `hsl(${p.hue},85%,70%)`; ctx.fill();
  ctx.restore();
}
function drawStar(ctx, p) {
  ctx.save(); ctx.translate(p.x, p.y); ctx.rotate(p.rot + p.t * 3);
  ctx.beginPath();
  for (let i = 0; i < 5; i++) {
    const a = (i / 5) * TAU - Math.PI / 2;
    ctx.lineTo(Math.cos(a) * p.size, Math.sin(a) * p.size);
    const a2 = a + TAU / 10;
    ctx.lineTo(Math.cos(a2) * p.size * .45, Math.sin(a2) * p.size * .45);
  }
  ctx.closePath();
  ctx.fillStyle = `hsl(${p.hue},90%,72%)`; ctx.fill();
  ctx.restore();
}

/* langit malam lunar */
const stars = Array.from({ length: 90 }, () => ({ x: Math.random(), y: Math.random(), s: rand(.4, 1.6), tw: rand(0, TAU) }));
function drawSky(t) {
  const g = sctx.createLinearGradient(0, 0, 0, H);
  g.addColorStop(0, "#141126"); g.addColorStop(.55, "#1a1a2e"); g.addColorStop(1, "#2d2a44");
  sctx.fillStyle = g; sctx.fillRect(0, 0, W, H);
  for (const st of stars) {
    const a = .35 + .65 * Math.abs(Math.sin(st.tw + t * (0.4 + st.s * .3)));
    sctx.beginPath(); sctx.arc(st.x * W, st.y * H * .7, st.s, 0, TAU);
    sctx.fillStyle = `rgba(232,227,245,${a})`; sctx.fill();
  }
  /* bulan */
  const mx = W * .84, my = H * .16, mr = clamp(Math.min(W, H) * .05, 26, 44);
  const mg = sctx.createRadialGradient(mx - mr * .3, my - mr * .3, mr * .2, mx, my, mr);
  mg.addColorStop(0, "#fff"); mg.addColorStop(1, "#d9d0f0");
  sctx.beginPath(); sctx.arc(mx, my, mr, 0, TAU); sctx.fillStyle = mg; sctx.fill();
  sctx.beginPath(); sctx.arc(mx + mr * .34, my - mr * .18, mr * .92, 0, TAU);
  sctx.fillStyle = "#1a1a2e"; sctx.globalAlpha = .92; sctx.fill(); sctx.globalAlpha = 1;
  /* lantai */
  sctx.beginPath(); sctx.ellipse(W / 2, H * .62 + clamp(Math.min(W, H) * .11, 46, 92) * .95, W * .3, 26, 0, 0, TAU);
  sctx.fillStyle = "#232038"; sctx.fill();
}

/* ================== LOOP ================== */
let last = performance.now();
function loop(now) {
  const dt = Math.min(.05, (now - last) / 1000); last = now;
  const t = now / 1000;
  pet.breathe += dt * (pet.state === "happy" ? 9 : 3.2);
  pet.tailPhase += dt * (pet.state === "happy" ? 7 : 2.6);
  pet.stateT -= dt; pet.bubbleT -= dt;
  if (pet.stateT <= 0 && !pet.ko && pet.ghost <= 0) {
    pet.state = moodNow().id === "ngambek" ? "sulk" : "idle";
  }
  pet.blinkT -= dt;
  if (pet.blinkT <= 0) { pet.blink = .12; pet.blinkT = rand(2.2, 5.5); }
  if (pet.blink > 0) pet.blink -= dt;

  /* fisika */
  pet.x += pet.vx * dt; pet.y += pet.vy * dt;
  pet.rot += pet.vrot * dt;
  pet.vrot *= (1 - dt * 2.2);
  const floorY = H * .62;
  if (!pet.ko && pet.ghost <= 0) {
    if (pet.y > floorY) {
      if (pet.vy > 200) { SFX.bounce(); addShake(6); spawnParts("spark", 6, pet.x, pet.y + 40); }
      pet.y = floorY; pet.vy = -Math.abs(pet.vy) * .45;
      pet.vy = Math.abs(pet.vy) < 60 ? 0 : pet.vy;
    } else if (pet.y < floorY - 2 && pet.vy !== 0) pet.vy += 1500 * dt;
    else if (pet.vy === 0 && pet.y !== floorY) { pet.y = floorY; }
    if (pet.vx !== 0 && pet.y >= floorY - 1) pet.vx *= (1 - dt * 3);
    const R = clamp(Math.min(W, H) * .11, 46, 92);
    if (pet.x < R) { pet.x = R; pet.vx = Math.abs(pet.vx) * .5; }
    if (pet.x > W - R) { pet.x = W - R; pet.vx = -Math.abs(pet.vx) * .5; }
  }
  /* squash-relax */
  pet.sx += (pet.targetSx - pet.sx) * dt * 9;
  pet.sy += (pet.targetSy - pet.sy) * dt * 9;
  if (Math.abs(pet.targetSx - pet.sx) < .01) { pet.targetSx = 1; pet.targetSy = 1; }
  shake *= (1 - dt * 7);
  if (shake < .15) shake = 0;

  /* KO / respawn */
  if (pet.ko) {
    pet.koT -= dt;
    if (pet.koT <= 0) {
      pet.ko = false; pet.ghost = 2.2; pet.respawnT = 2.2;
      $("#ko-overlay").hidden = true;
      SFX.revive(); spawnParts("heart", 8, pet.x, pet.y - 60);
      pet.chatBubble = pick(["aku kembali~", "maafkan kamu…", "halo lagi! 💫", "miss me?"]); pet.bubbleT = 2.4;
    }
  }
  if (pet.ghost > 0) {
    pet.ghost -= dt;
    pet.y = floorY - Math.abs(Math.sin((2.2 - pet.ghost) * 3)) * 26;
    if (pet.ghost <= 0) { pet.state = "idle"; addMood(12); }
  }

  /* render */
  drawSky(t);
  pctx.clearRect(0, 0, W, H);
  for (let i = parts.length - 1; i >= 0; i--) {
    const p = parts[i];
    p.t += dt; p.vy += 700 * dt * .4;
    p.x += p.vx * dt; p.y += p.vy * dt;
    if (p.t > p.life) { parts.splice(i, 1); continue; }
    const alpha = 1 - p.t / p.life;
    pctx.globalAlpha = alpha;
    if (p.kind === "heart") drawHeart(pctx, p);
    else if (p.kind === "star") drawStar(pctx, p);
    else {
      pctx.save(); pctx.translate(p.x, p.y); pctx.rotate(p.rot);
      pctx.fillStyle = `hsl(${p.hue},80%,75%)`;
      pctx.fillRect(-p.size / 2, -1.5, p.size, 3);
      pctx.restore();
    }
    pctx.globalAlpha = 1;
  }
  drawMomo(pctx, t);
  requestAnimationFrame(loop);
}
requestAnimationFrame(loop);

/* ================== INTERAKSI ================== */
function impact(dir, force) {
  pet.vx += dir * force;
  pet.vy -= force * rand(.2, .55);
  pet.vrot += dir * force * .0022;
  pet.targetSx = 1.32; pet.targetSy = .68;
  addShake(force * .03);
}
function addBruise() {
  if (S.bruises.length < 9) S.bruises.push({ x: rand(-.7, .7), y: rand(-.6, .6), r: rand(0, TAU) });
  save();
}
function bubble(txt, dur = 2.2) { pet.chatBubble = txt; pet.bubbleT = dur; }

const IDLE_LINES = ["aku di sini kok~", "elus aku dong 🥺", "=(^..^)=", "mrrrrp~", "bosan… main yuk!"];
setInterval(() => {
  if (!pet.ko && pet.ghost <= 0 && !$("#chat").dataset.busy && Math.random() < .3) {
    const m = moodNow().id;
    bubble(m === "ngambek" ? pick(["hmph!", "jangan deket-deket…", "hmp! 😾"]) : pick(IDLE_LINES));
  }
}, 9000);

function hurtMomo(kind) {
  if (pet.ko || pet.ghost > 0) return;
  const R = clamp(Math.min(W, H) * .11, 46, 92);
  S.hits++; S.xp += 2;
  const dir = pet.x < W / 2 ? 1 : -1;
  $("#dmg-flash").classList.remove("on"); void $("#dmg-flash").offsetWidth; $("#dmg-flash").classList.add("on");
  let force = 260;
  if (kind === "tampar") { SFX.slap(); impact(dir, force); spawnParts("spark", 10, pet.x, pet.y); bubble(pick(["aduh!! 😖", "aaw!", "kenapa sih!!", "it hurts!!"])); }
  else if (kind === "jitak") { SFX.bonk(); pet.vy = -force * .9; pet.targetSx = .7; pet.targetSy = 1.3; addShake(10); spawnParts("star", 12, pet.x, pet.y - R); pet.state = "dizzy"; pet.stateT = 2.4; bubble(pick(["duh!! kepala…", "bonk!! 💫", "bintang…"])); }
  else if (kind === "cubit") { SFX.pinch(); pet.targetSx = 1.25; pet.targetSy = .75; pet.vx = dir * 90; spawnParts("spark", 5, pet.x + dir * R * .5, pet.y); bubble(pick(["aaw aaw!", "pinchnya sakit!!", "pipiku!!"])); }
  else if (kind === "lempar") {
    SFX.throwWoosh();
    pet.vx = dir * rand(700, 1050); pet.vy = -rand(620, 850); pet.vrot = dir * rand(9, 14);
    addShake(8); spawnParts("spark", 8, pet.x, pet.y);
    bubble(pick(["waaa—!!", "terbangggg", "AAAAAAA!"]));
  }
  addMood(kind === "lempar" ? -9 : -6);
  addBruise();
  /* makin sering dipukul makin cepat K.O. */
  const koAt = clamp(13 - Math.floor(S.hits / 40), 6, 13);
  if (S.hits % koAt === 0) knockOut();
  renderChips(); save();
}
function knockOut() {
  pet.ko = true; pet.koT = 3.2; pet.state = "ko";
  S.kos++; save();
  SFX.ko(); addShake(18);
  $("#ko-overlay").hidden = false;
  setTimeout(() => { $("#ko-overlay").hidden = true; }, 2600);
  unlock("ko_1", "K.O. pertama", "Momo pingsan… maaf ya 😔");
  if (S.kos >= 10) unlock("ko_10", "Legenda K.O. ×10", "Momo kebal sakit hati");
}
function loveMomo(kind) {
  if (pet.ko || pet.ghost > 0) return;
  if (moodNow().id === "ngambek" && Math.random() < .5) {
    bubble(pick(["hmph! belum maaf!", "…belim!"])); SFX.meow(); return;
  }
  S.xp += 4;
  if (kind === "elus") { S.pats++; SFX.pat(); pet.state = "happy"; pet.stateT = 1.8; spawnParts("heart", 5, pet.x, pet.y - 30); addMood(4); bubble(pick(["mrrrp~ 💜", "enak…", "lagi lagi!"])); if (S.pats === 1) unlock("first_pat", "Sapaan hangat", "Elusan pertama untuk Momo"); }
  else if (kind === "makan") { S.feeds++; SFX.feed(); pet.state = "eat"; pet.stateT = 2.2; spawnParts("spark", 7, pet.x, pet.y - 20); addMood(6); bubble(pick(["nom nom~", "enyak enyak!", "makasih! 🍪"])); if (S.feeds >= 10) unlock("feed_10", "Koki tercinta", "10 kali memberi makan"); }
  else if (kind === "peluk") { S.hugs++; SFX.hug(); pet.state = "hug"; pet.stateT = 2.4; spawnParts("heart", 10, pet.x, pet.y - 40); addMood(8); bubble(pick(["aku sayang kamu 🤗", "hangat…", "jangan pergi ya…"])); if (S.hugs >= 5) unlock("hug_5", "Pelukan terapi", "5 pelukan erat"); }
  renderChips(); save();
}

/* klik/tap langsung di badan Momo = elus; klik cepat beruntun = "goda" */
function petHit(x, y) {
  const R = clamp(Math.min(W, H) * .11, 46, 92);
  const dx = x - pet.x, dy = y - pet.y;
  if ((dx / (R * 1.35)) ** 2 + (dy / (R * 1.25)) ** 2 <= 1) { loveMomo("elus"); return true; }
  return false;
}
petC.addEventListener("pointerdown", (e) => { ac(); petHit(e.clientX, e.clientY); });

/* dock */
$("#dock").addEventListener("click", (e) => {
  const btn = e.target.closest(".tool"); if (!btn) return;
  ac();
  const tool = btn.dataset.tool;
  if (["tampar", "jitak", "cubit", "lempar"].includes(tool)) hurtMomo(tool);
  else loveMomo(tool);
});

/* keyboard shortcut: spasi = tampar */
addEventListener("keydown", (e) => {
  if (e.code === "Space" && document.activeElement !== $("#chat-input") && !$("#settings").open) {
    e.preventDefault(); hurtMomo("tampar");
  }
});

/* ================== CHIPS & TOAST ================== */
function renderChips() {
  $("#dmg-count").textContent = S.hits;
  $("#bond-lv").textContent = bondLv();
  $("#mood-name").textContent = moodNow().label;
  if (bondLv() >= 5) unlock("bond_5", "Ikatan Kuat Lv5", "Momo mulai akrab banget sama kamu");
  if (S.hits >= 50) unlock("hit_50", "Petinang ×50", "50 pukulan terdaftar");
  if (S.hits >= 100) unlock("hit_100", "Diktator ×100", "100 pukulan… Momo tabah");
}
function unlock(id, title, desc) {
  if (S.achievements.includes(id)) return;
  S.achievements.push(id); save();
  SFX.achieve();
  const el = document.createElement("div");
  el.className = "toast";
  el.innerHTML = `<span class="t-icon">🏆</span><span><b>${title}</b>${desc}</span>`;
  $("#toasts").appendChild(el);
  setTimeout(() => el.remove(), 4200);
}

/* ================== CHAT (LLM lokal) ================== */
let baseUrl = localStorage.getItem("moonpet-url") || "http://127.0.0.1:8199";
$("#set-url").value = baseUrl;

/* Jembatan bahasa: model 350M tidak memahami bahasa Indonesia (teruji),
 * tetapi sangat baik memahami Inggris sederhana/pecah. Kamus kata-per-kata
 * + frasa umum mengubah curhat Indonesia menjadi Inggris patah yang dipahami. */
const ID_PHRASES = [
  ["terima kasih", "thank you"], ["makasih banyak", "thank you very much"],
  ["apa kabar", "how are you"], ["gimana kabarmu", "how are you"], ["gimana kabar", "how are you"],
  ["aku sayang kamu", "i love you"], ["sayang banget", "love very much"],
  ["sudah makan", "have you eaten"], ["semangat ya", "cheer up"], ["semangatin aku", "cheer me up"],
  ["aku kesepian banget", "i feel so lonely"], ["temani aku", "stay with me"],
  ["nggak apa apa", "its okay"], ["gak apa apa", "its okay"], ["tidak apa apa", "its okay"],
  ["aku nggak apa apa", "i am okay"], ["maafin aku", "forgive me"], ["aku minta maaf", "i am sorry"],
  ["peluk aku", "hug me"], ["elus aku", "pet me"], ["jangan pergi", "dont go"],
  ["aku capek banget", "i am so tired"], ["capek banget", "so tired"], ["hari berat", "hard day"],
  ["kerjaanku berat", "my work is heavy"], ["mau curhat", "want to vent"], ["sedih banget", "very sad"],
  ["aku sedih", "i am sad"], ["aku marah", "i am angry"], ["aku takut", "i am afraid"],
  ["aku kangen", "i miss"], ["kangen kamu", "miss you"], ["rindu kamu", "miss you"],
  ["tidur sama kamu", "sleep with you"], ["selamat malam", "good night"], ["selamat pagi", "good morning"],
  ["aku gak bisa", "i cannot"], ["gak bisa", "cannot"], ["bantu aku", "help me"],
  ["dengerin aku", "listen to me"], ["dengarkan aku", "listen to me"], ["butuh kamu", "need you"],
  ["aku butuh", "i need"], ["sama kamu", "with you"], ["buat kamu", "for you"],
];
const ID_WORDS = {
  aku:"i", saya:"i", ku:"my", kamu:"you", kau:"you", mu:"your", kalian:"you all", kita:"we", kami:"we", mereka:"they",
  dia:"he/she", ia:"he/she", momo:"momo", ini:"this", itu:"that", sini:"here", sana:"there",
  kesepian:"lonely", sepi:"quiet-lonely", sendirian:"alone", sendiri:"alone", sedih:"sad", nangis:"cry",
  ngedumel:"grumble", bahagia:"happy", senang:"happy", gembira:"glad", bangga:"proud", marah:"angry",
  kesal:"upset", benci:"hate", takut:"afraid", khawatir:"worried", cemas:"anxious", capek:"tired", lelah:"tired",
  letih:"tired", pusing:"dizzy", sakit:"sick-hurt", hati:"heart", pikiran:"mind", perasaan:"feeling",
  banget:"very", sekali:"very", amat:"very", terlalu:"too", paling:"most", cukup:"enough",
  kenapa:"why", mengapa:"why", gimana:"how", bagaimana:"how", kapan:"when", dimana:"where", siapa:"who", apa:"what",
  gak:"not", nggak:"not", tidak:"not", enggak:"not", belum:"not yet", sudah:"already", udah:"already",
  akan:"will", mau:"want", pengen:"want", bisa:"can", harus:"must", jangan:"dont", tolong:"please",
  ya:"yes", iya:"yes", engga:"no", oh:"oh", sih:"", deh:"", dong:"", kok:"", lah:"", nih:"", tuh:"", kayak:"like",
  juga:"also", lagi:"still", saja:"only", doang:"only", cuma:"only", masih:"still", pernah:"ever",
  hari:"day", hariini:"today", kemarin:"yesterday", besok:"tomorrow", sekarang:"now", nanti:"later",
  pagi:"morning", siang:"afternoon", sore:"evening", malam:"night", jam:"hour", waktu:"time", tahun:"year", bulan:"month", minggu:"week",
  kerja:"work", kerjaan:"work", kantor:"office", sekolah:"school", kuliah:"college", ujian:"exam", nilai:"grade",
  teman:"friend", sahabat:"best friend", keluarga:"family", pacar:"partner", gebetan:"crush", jodoh:"soulmate",
  orang:"person", siapa2:"anyone", semua:"all", banyak:"many", sedikit:"little", beberapa:"some",
  sayang:"love", cinta:"love", kangen:"miss", rindu:"miss", peluk:"hug", cium:"kiss", elus:"pet",
  makan:"eat", minum:"drink", tidur:"sleep", bangun:"wake", istirahat:"rest", main:"play", game:"game",
  musik:"music", lagu:"song", film:"movie", buku:"book", catatan:"note", cerita:"story", curhat:"vent",
  bagus:"good", baik:"good", buruk:"bad", jelek:"bad", cantik:"pretty", ganteng:"handsome", lucu:"cute",
  besar:"big", kecil:"small", panas:"hot", dingin:"cold", hujan:"rain", bulan:"moon", bintang:"star", langit:"sky",
  rumah:"home", kamar:"room", kasur:"bed", kucing:"cat", anjing:"dog", makanan:"food", air:"water",
  makasih:"thanks", trims:"thanks", sorry:"sorry", maaf:"sorry", salam:"greetings", halo:"hello", hai:"hi",
  tunggu:"wait", dengar:"listen", lihat:"see", tahu:"know", pikir:"think", ingat:"remember", lupa:"forget",
  semangat:"spirit", sabar:"patient", kuat:"strong", lemah:"weak", nyaman:"comfortable", aman:"safe",
  hidup:"life", mati:"death", dunia:"world", tuhan:"god", doa:"prayer", rezeki:"fortune",
};
function idToEn(text) {
  let t = " " + text.toLowerCase().replace(/[!?.,]+/g, " ") + " ";
  for (const [id, en] of ID_PHRASES) {
    if (t.includes(" " + id + " ") || t.includes(" " + id + " ")) {
      t = t.split(id).join(en);
    }
  }
  const out = t.trim().split(/\s+/).map((w) => {
    const key = w.replace(/[^a-z0-9-]/g, "");
    return ID_WORDS[key] !== undefined ? ID_WORDS[key] : w;
  });
  let s = out.join(" ").replace(/\s+/g, " ").trim();
  return s || text;
}
function isIndonesian(text) {
  const words = text.toLowerCase().split(/\s+/).map((w) => w.replace(/[^a-z0-9-]/g, ""));
  let hit = 0, total = 0;
  for (const w of words) { if (w.length < 2) continue; total++; if (ID_WORDS[w] !== undefined) hit++; }
  return total > 0 && hit / total >= 0.25;
}

const FEWSHOT = [
  { role: "user", content: "momo, i lonely very today. stay with me" },
  { role: "assistant", content: "Aww dont be sad! Momo is here with you forever (=^..^=)" },
  { role: "user", content: "my work day heavy very, want vent to you" },
  { role: "assistant", content: "You did great today 💜 Momo is proud of you, rest now." },
];
function moodForPrompt() {
  const m = moodNow().id;
  const map = { senang: "happy", biasa: "relaxed", sedih: "a bit sad", ngambek: "sulking (but secretly forgiving)" };
  let p = map[m];
  if (pet.ko) p = "knocked out (reply very short and silly)";
  else if (S.bruises.length >= 3) p += ", has funny cartoon bruises and a bandage";
  return p;
}
function systemPrompt() {
  return `You are Momo the cute moon-cat pet. You love your owner. Mood: ${moodForPrompt()}. Reply in simple sweet English, max 2 short sentences, cute emoticons allowed. The owner may write in simple or broken English.`;
}
async function chatSend(text) {
  const msgsEl = $("#chat-msgs");
  const addMsg = (who, txt, cls) => {
    const el = document.createElement("div");
    el.className = `msg ${cls}`;
    if (cls === "momo") { const who2 = document.createElement("span"); who2.className = "who"; who2.textContent = "Momo"; el.appendChild(who2); }
    el.appendChild(document.createTextNode(txt));
    msgsEl.appendChild(el);
    msgsEl.scrollTop = msgsEl.scrollHeight;
    return el;
  };
  addMsg("me", text, "me");
  /* jembatan bahasa: kirim versi Inggris patah ke model (batas model 350M) */
  const sendText = isIndonesian(text) ? idToEn(text) : text;
  S.chatLog.push({ role: "user", content: sendText });
  S.chats++; S.xp += 3; addMood(2); renderChips(); save();
  if (S.chats === 1) unlock("first_chat", "Sahabat curhat", "Percakapan pertama dengan Momo");
  if (S.chats >= 50) unlock("chat_50", "50 Curhat", "Momo pendengar setia");

  const wait = addMsg("momo", "…", "momo waiting");
  $("#chat").dataset.busy = "1";
  $("#chat-send").disabled = true;
  const hist = S.chatLog.slice(-10);
  try {
    const resp = await fetch(`${baseUrl}/v1/chat/completions`, {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({
        messages: [{ role: "system", content: systemPrompt() }, ...FEWSHOT, ...hist],
        temperature: 0.6, max_tokens: 60, stream: true,
      }),
    });
    if (!resp.ok) throw new Error(`HTTP ${resp.status}`);
    wait.remove();
    const live = addMsg("momo", "", "momo");
    let acc = "", lastBubble = 0;
    const reader = resp.body.getReader();
    const dec = new TextDecoder();
    let buf = "";
    for (;;) {
      const { done, value } = await reader.read();
      if (done) break;
      buf += dec.decode(value, { stream: true });
      const lines = buf.split("\n");
      buf = lines.pop();
      for (const line of lines) {
        const s = line.trim();
        if (!s.startsWith("data:")) continue;
        const payload = s.slice(5).trim();
        if (payload === "[DONE]") continue;
        try {
          const j = JSON.parse(payload);
          const delta = j.choices?.[0]?.delta?.content || "";
          if (delta) {
            acc += delta;
            live.textContent = acc;
            msgsEl.scrollTop = msgsEl.scrollHeight;
            const now = performance.now();
            if (now - lastBubble > 350) {
              lastBubble = now;
              const words = acc.split(/\s+/).slice(-4).join(" ");
              if (words.length > 2) bubble(words, 2);
            }
          }
        } catch {}
      }
    }
    const clean = acc.trim();
    S.chatLog.push({ role: "assistant", content: clean });
    if (S.chatLog.length > 40) S.chatLog = S.chatLog.slice(-30);
    save();
    if (clean) {
      pet.state = "happy"; pet.stateT = 2.5; spawnParts("heart", 4, pet.x, pet.y - 40);
      SFX.meow();
    } else live.textContent = "(momo diam… coba lagi)";
  } catch (err) {
    wait.remove();
    addMsg("momo", `⚠ Tidak bisa menghubungi otak lokal (${err.message}). Pastikan peluncur MoonPet masih berjalan.`, "momo");
  } finally {
    $("#chat").dataset.busy = "";
    $("#chat-send").disabled = false;
  }
}
$("#chat-send").addEventListener("click", () => {
  const inp = $("#chat-input");
  const v = inp.value.trim();
  if (v) { inp.value = ""; chatSend(v); }
});
$("#chat-input").addEventListener("keydown", (e) => {
  if (e.key === "Enter") $("#chat-send").click();
});
$("#chat-clear").addEventListener("click", () => {
  S.chatLog = []; save();
  $("#chat-msgs").innerHTML = "";
});
$("#chat-toggle").addEventListener("click", () => {
  const c = $("#chat");
  c.dataset.open = c.dataset.open === "true" ? "false" : "true";
  if (c.dataset.open === "true") setTimeout(() => $("#chat-input").focus(), 80);
});

/* ================== KONEKSI ================== */
async function health() {
  try {
    const r = await fetch(`${baseUrl}/health`, { signal: AbortSignal.timeout(2500) });
    const ok = r.ok;
    $("#net-dot").classList.toggle("ok", ok);
  } catch { $("#net-dot").classList.remove("ok"); }
}
setInterval(health, 5000); health();

/* ================== SETTINGS ================== */
$("#btn-settings").addEventListener("click", () => { $("#settings").showModal(); $("#set-status").textContent = "…"; });
$("#set-close").addEventListener("click", () => $("#settings").close());
$("#set-test").addEventListener("click", async () => {
  const st = $("#set-status");
  baseUrl = $("#set-url").value.trim().replace(/\/$/, "");
  localStorage.setItem("moonpet-url", baseUrl);
  st.className = "set-hint"; st.textContent = "menguji…";
  try {
    const r = await fetch(`${baseUrl}/v1/models`, { signal: AbortSignal.timeout(3000) });
    if (r.ok) { st.className = "set-hint ok"; st.textContent = "✓ Terhubung ke otak lokal"; health(); }
    else throw new Error(String(r.status));
  } catch (e) { st.className = "set-hint err"; st.textContent = `✗ Gagal: ${e.message}`; }
});
$("#set-reset").addEventListener("click", () => {
  S = { ...defaults, chatLog: [] };
  save(); S.bruises = []; renderChips();
  $("#set-status").className = "set-hint ok";
  $("#set-status").textContent = "✓ Statistik direset";
});

/* render awal */
renderChips();
if (S.bruises === undefined) S.bruises = [];
setTimeout(() => { $("#hint").style.opacity = "0"; }, 6000);
})();
