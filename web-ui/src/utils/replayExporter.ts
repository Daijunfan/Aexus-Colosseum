// Generates a single-file zero-dependency interactive 60fps Apple-Daylight .pitreplay.html capsule!

import { MatchState } from '../types/pit';

export function exportStandalonePitReplayHtml(match: MatchState): void {
  const payloadJson = JSON.stringify({
    exported_at: new Date().toISOString(),
    match,
  }).replace(/</g, '\\u003c');

  const html = `<!doctype html>
<html lang="zh-CN">
<head>
<meta charset="utf-8" />
<meta name="viewport" content="width=device-width,initial-scale=1" />
<title>Aexus Colosseum Replay · ${match.title}</title>
<style>
  * { box-sizing: border-box; margin: 0; padding: 0; }
  body { background: #F4F4F7; color: #1A1A1E; font-family: -apple-system, BlinkMacSystemFont, "SF Pro Text", "PingFang SC", Inter, sans-serif; height: 100vh; display: flex; flex-direction: column; overflow: hidden; -webkit-font-smoothing: antialiased; }
  .mono { font-family: "SF Mono", "JetBrains Mono", Menlo, monospace; font-variant-numeric: tabular-nums; }
  header { padding: 12px 24px; background: rgba(255,255,255,0.88); backdrop-filter: blur(20px); border-bottom: 1px solid rgba(0,0,0,0.07); display: flex; align-items: center; justify-content: space-between; gap: 16px; }
  .badge { padding: 4px 12px; border-radius: 999px; font-size: 11px; font-weight: 700; background: rgba(0,122,255,0.10); color: #007AFF; border: 1px solid rgba(0,122,255,0.20); }
  .seats { display: grid; grid-template-columns: repeat(auto-fit, minmax(185px, 1fr)); gap: 10px; padding: 12px 24px; background: #F4F4F7; }
  .seat-card { background: #FFFFFF; border: 1px solid rgba(0,0,0,0.065); border-radius: 16px; padding: 10px 14px; box-shadow: 0 4px 12px rgba(0,0,0,0.04); }
  .mana-bar { height: 5px; background: rgba(0,0,0,0.06); border-radius: 99px; overflow: hidden; margin-top: 6px; }
  .mana-fill { height: 100%; background: #007AFF; }
  main { flex: 1; position: relative; display: flex; min-height: 0; margin: 0 24px; border-radius: 20px; overflow: hidden; background: #FFFFFF; border: 1px solid rgba(0,0,0,0.065); box-shadow: 0 6px 18px rgba(0,0,0,0.045); }
  canvas { flex: 1; width: 100%; height: 100%; display: block; }
  #xray { position: absolute; inset: 16px; background: rgba(255, 255, 255, 0.97); backdrop-filter: blur(20px); border: 1px solid rgba(0, 0, 0, 0.09); border-radius: 18px; box-shadow: 0 18px 40px rgba(0,0,0,0.12); display: none; grid-template-columns: 1fr 1fr; gap: 14px; padding: 16px; overflow: hidden; }
  #xray.open { display: grid; }
  .panel { background: #F6F7FA; border: 1px solid rgba(0,0,0,0.06); border-radius: 14px; padding: 12px; overflow: auto; font-size: 12px; color: #1A1A1E; }
  footer { padding: 12px 24px; margin-top: 12px; background: rgba(255,255,255,0.92); border-top: 1px solid rgba(0,0,0,0.07); display: flex; align-items: center; gap: 12px; }
  button { background: #FFFFFF; color: #1A1A1E; border: 1px solid rgba(0,0,0,0.09); padding: 6px 14px; border-radius: 999px; cursor: pointer !important; font-weight: 600; font-size: 12px; transition: all 0.15s; }
  button:hover { border-color: #007AFF; color: #007AFF; }
  button.primary { background: #007AFF; color: #FFFFFF; border-color: #007AFF; }
  input[type=range] { flex: 1; accent-color: #007AFF; cursor: pointer !important; }
  .diff-del { color: #B91C1C; background: rgba(220,46,51,0.12); display: block; padding: 1px 4px; border-radius: 4px; }
  .diff-add { color: #15803D; background: rgba(28,148,87,0.12); display: block; padding: 1px 4px; border-radius: 4px; }
</style>
</head>
<body>
<header>
  <div style="display:flex;align-items:center;gap:12px">
    <span class="badge">AEXUS COLOSSEUM · 60FPS REPLAY</span>
    <strong id="title" style="font-size:15px"></strong>
    <span class="mono" style="color:#61626A;font-size:12px" id="meta"></span>
  </div>
  <div style="display:flex;align-items:center;gap:8px">
    <button id="xrayBtn" class="primary">底层检视台 (Space)</button>
  </div>
</header>
<section class="seats" id="seats"></section>
<main>
  <canvas id="stage"></canvas>
  <div id="xray">
    <div class="panel mono">
      <div style="color:#007AFF;font-weight:700;margin-bottom:8px">Linux eBPF 系统调用与 OpenSSL 明文载荷</div>
      <div id="syscalls"></div>
    </div>
    <div class="panel mono">
      <div style="color:#1C9457;font-weight:700;margin-bottom:8px">Git Diff 实时源码热补丁</div>
      <div id="diffs"></div>
    </div>
  </div>
</main>
<footer>
  <button id="playBtn">暂停</button>
  <button id="speedBtn" class="mono">1x</button>
  <input type="range" id="scrub" min="0" max="100" value="0" />
  <span id="caster" style="font-size:12.5px;color:#1A1A1E;font-weight:500;max-width:42%;white-space:nowrap;overflow:hidden;text-overflow:ellipsis"></span>
</footer>
<script>
const DATA = ${payloadJson};
const M = DATA.match;
const events = (M.events || []).slice().reverse();
document.getElementById('title').textContent = M.title;
document.getElementById('meta').textContent = M.mode.toUpperCase() + ' · ' + M.map_name + ' · ' + events.length + ' 条 eBPF 事件';

const seatsEl = document.getElementById('seats');
(M.seats || []).forEach(s => {
  const d = document.createElement('div');
  d.className = 'seat-card';
  d.innerHTML = '<div style="display:flex;justify-content:space-between;align-items:center"><strong>'+(s.is_grail_king?'👑 ':'')+s.name+'</strong><span class="mono" style="font-weight:700;color:#007AFF">'+s.score+' 分</span></div>'
    + '<div class="mono" style="font-size:11px;color:#61626A;margin-top:3px">'+s.model+' · 剩余 '+s.mana_remaining_pct.toFixed(0)+'%</div>'
    + '<div class="mana-bar"><div class="mana-fill" style="width:'+s.mana_remaining_pct+'%"></div></div>';
  seatsEl.appendChild(d);
});

const syscallsEl = document.getElementById('syscalls');
events.forEach(e => {
  const row = document.createElement('div');
  row.style.padding = '6px 0';
  row.style.borderBottom = '1px solid rgba(0,0,0,0.06)';
  row.textContent = '['+e.probe+'] PID='+e.pid+' ('+e.comm+') ' + e.cmdline + (e.cleartext_payload ? '\\n  ↳ TLS: ' + e.cleartext_payload.slice(0,120) : '');
  syscallsEl.appendChild(row);
});

const diffsEl = document.getElementById('diffs');
(M.patches || []).forEach(p => {
  const pre = document.createElement('pre');
  pre.style.marginBottom = '12px';
  p.diff.split('\\n').forEach(line => {
    const sp = document.createElement('span');
    sp.className = line.startsWith('-') ? 'diff-del' : line.startsWith('+') ? 'diff-add' : '';
    sp.textContent = line + '\\n';
    pre.appendChild(sp);
  });
  diffsEl.appendChild(pre);
});

let cursor = 0, playing = true, speed = 1;
const scrub = document.getElementById('scrub');
scrub.max = String(Math.max(1, events.length - 1));
const casterEl = document.getElementById('caster');
casterEl.textContent = (M.caster_lines && M.caster_lines[0]) ? M.caster_lines[0].text : 'Aexus Colosseum 战局回放';

document.getElementById('playBtn').onclick = (ev) => {
  playing = !playing;
  ev.target.textContent = playing ? '暂停' : '播放';
};
document.getElementById('speedBtn').onclick = (ev) => {
  speed = speed === 1 ? 2 : speed === 2 ? 4 : 1;
  ev.target.textContent = speed + 'x';
};
scrub.oninput = (ev) => { cursor = Number(ev.target.value); };

const xray = document.getElementById('xray');
const toggleXray = () => xray.classList.toggle('open');
document.getElementById('xrayBtn').onclick = toggleXray;
window.addEventListener('keydown', e => { if (e.code === 'Space') { e.preventDefault(); toggleXray(); } });

const canvas = document.getElementById('stage');
const ctx = canvas.getContext('2d');
function resize() { canvas.width = canvas.clientWidth * devicePixelRatio; canvas.height = canvas.clientHeight * devicePixelRatio; }
window.addEventListener('resize', resize); resize();

function loop() {
  if (playing && events.length > 1) {
    cursor = (cursor + 0.03 * speed) % events.length;
    scrub.value = String(Math.floor(cursor));
  }
  const w = canvas.width, h = canvas.height, cx = w/2, cy = h/2, R = Math.min(w,h)*0.36;
  ctx.fillStyle = '#FAFBFE'; ctx.fillRect(0,0,w,h);
  [1, 0.74, 0.48, 0.24].forEach((k, i) => {
    ctx.beginPath(); ctx.arc(cx, cy, R*k, 0, Math.PI*2);
    ctx.strokeStyle = i===0 ? 'rgba(0,0,0,0.085)' : 'rgba(0,0,0,0.045)';
    ctx.lineWidth = 1.2 * devicePixelRatio; ctx.stroke();
  });

  ctx.beginPath(); ctx.arc(cx, cy, 34*devicePixelRatio, 0, Math.PI*2);
  ctx.fillStyle = '#FFFFFF'; ctx.fill();
  ctx.strokeStyle = '#007AFF'; ctx.lineWidth = 3 * devicePixelRatio; ctx.stroke();
  ctx.fillStyle = '#1A1A1E'; ctx.textAlign = 'center'; ctx.font = 'bold '+(11*devicePixelRatio)+'px -apple-system, sans-serif';
  ctx.fillText('中央靶机', cx, cy + 4*devicePixelRatio);

  const seats = M.seats || [];
  const activeEvt = events[Math.floor(cursor)];
  seats.forEach((s, idx) => {
    const ang = (idx / Math.max(1, seats.length)) * Math.PI * 2 - Math.PI / 2;
    const sx = cx + Math.cos(ang) * R * 0.94;
    const sy = cy + Math.sin(ang) * R * 0.94;
    if (activeEvt && activeEvt.source_seat_id === s.id) {
      ctx.beginPath(); ctx.moveTo(sx, sy); ctx.lineTo(cx, cy);
      ctx.strokeStyle = activeEvt.vfx_type === 'NANO_PATCH_WELD' ? '#007AFF' : s.team_color;
      ctx.lineWidth = 2.6 * devicePixelRatio; ctx.stroke();
    }
    ctx.beginPath(); ctx.arc(sx, sy, 18*devicePixelRatio, 0, Math.PI*2);
    ctx.fillStyle = '#FFFFFF'; ctx.fill();
    ctx.strokeStyle = s.team_color; ctx.lineWidth = 2.4 * devicePixelRatio; ctx.stroke();
    ctx.fillStyle = '#1A1A1E'; ctx.font = 'bold '+(11.5*devicePixelRatio)+'px -apple-system, sans-serif';
    ctx.fillText(s.name, sx, sy + 32*devicePixelRatio);
  });
  if (activeEvt) {
    ctx.textAlign = 'left';
    ctx.fillStyle = '#007AFF';
    ctx.font = (11.5*devicePixelRatio)+'px "SF Mono", monospace';
    ctx.fillText('['+activeEvt.vfx_type+'] ' + activeEvt.cmdline.slice(0, 84), 20*devicePixelRatio, h - 18*devicePixelRatio);
  }
  requestAnimationFrame(loop);
}
loop();
</script>
</body>
</html>`;

  const blob = new Blob([html], { type: 'text/html;charset=utf-8' });
  const url = URL.createObjectURL(blob);
  const a = document.createElement('a');
  a.href = url;
  a.download = `${match.id}-${match.mode}.pitreplay.html`;
  document.body.appendChild(a);
  a.click();
  document.body.removeChild(a);
  window.setTimeout(() => URL.revokeObjectURL(url), 3000);
}
