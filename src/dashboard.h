#pragma once

// ═══════════════════════════════════════════════════
//  Embedded Web Dashboard — PROGMEM
//  Clean minimal black design — FEATURE-7
//  BUG-04 fix: removed broken Object.defineProperty
// ═══════════════════════════════════════════════════

const char DASHBOARD_HTML[] PROGMEM = R"rawliteral(
<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="UTF-8">
<meta name="viewport" content="width=device-width, initial-scale=1.0, user-scalable=no">
<meta name="description" content="Smart Room Dashboard — Control lights, fans, sensors, and automations">
<title>Room Control — shreyansh.local</title>
<link rel="preconnect" href="https://fonts.googleapis.com">
<link href="https://fonts.googleapis.com/css2?family=Inter:wght@300;400;500;600;700&display=swap" rel="stylesheet">
<style>
*{margin:0;padding:0;box-sizing:border-box}
:root{
  --bg:#000;
  --card:rgba(255,255,255,0.04);
  --card-border:rgba(255,255,255,0.06);
  --text:#fff;
  --text2:rgba(255,255,255,0.4);
  --text3:rgba(255,255,255,0.2);
}
body{
  font-family:'Inter',-apple-system,BlinkMacSystemFont,'Segoe UI',sans-serif;
  background:var(--bg);color:var(--text);min-height:100vh;
  -webkit-font-smoothing:antialiased;-moz-osx-font-smoothing:grayscale;
}
.container{max-width:680px;margin:0 auto;padding:20px 16px}

/* ── Header ── */
.header{display:flex;align-items:center;justify-content:space-between;padding:24px 0 28px;border-bottom:1px solid var(--card-border);margin-bottom:24px}
.header h1{font-size:1.25rem;font-weight:600;letter-spacing:-0.03em;color:var(--text)}
.conn-status{display:flex;align-items:center;gap:8px;font-size:0.75rem;color:var(--text2)}
.dot{width:6px;height:6px;border-radius:50%;background:var(--text3);flex-shrink:0;transition:background .3s}
.dot.on{background:var(--text)}

/* ── Section ── */
.section{margin-bottom:24px}
.section-title{font-size:0.65rem;text-transform:uppercase;letter-spacing:0.14em;color:var(--text2);margin-bottom:14px;font-weight:500}

/* ── Sensor Cards ── */
.card-grid{display:grid;grid-template-columns:1fr 1fr;gap:12px}
.card{background:var(--card);border:1px solid var(--card-border);border-radius:12px;padding:20px 18px;transition:border-color .2s}
.card:hover{border-color:rgba(255,255,255,0.1)}
.card-value{font-size:1.8rem;font-weight:700;line-height:1;margin-bottom:6px;color:var(--text);letter-spacing:-0.02em}
.card-label{font-size:0.68rem;color:var(--text2);font-weight:400;letter-spacing:0.02em}

/* ── Relay Switches ── */
.relay-grid{display:grid;gap:8px}
.relay-row{display:flex;align-items:center;justify-content:space-between;background:var(--card);border:1px solid var(--card-border);border-radius:12px;padding:14px 18px}
.relay-label{font-size:0.85rem;font-weight:500;color:var(--text)}

/* Minimal pill toggle */
.toggle{position:relative;width:44px;height:24px;cursor:pointer;flex-shrink:0}
.toggle input{display:none}
.toggle .slider{position:absolute;inset:0;background:rgba(255,255,255,0.08);border-radius:12px;transition:background .25s}
.toggle .slider::after{content:'';position:absolute;left:3px;top:3px;width:18px;height:18px;background:rgba(255,255,255,0.25);border-radius:50%;transition:transform .25s,background .25s}
.toggle input:checked+.slider{background:rgba(255,255,255,0.2)}
.toggle input:checked+.slider::after{transform:translateX(20px);background:#fff}

/* ── Brightness Sliders ── */
.slider-row{background:var(--card);border:1px solid var(--card-border);border-radius:12px;padding:16px 18px;margin-bottom:8px}
.slider-header{display:flex;justify-content:space-between;align-items:center;margin-bottom:14px}
.slider-name{font-size:0.85rem;font-weight:500}
.slider-val{font-size:0.8rem;font-weight:600;color:var(--text);min-width:36px;text-align:right;font-variant-numeric:tabular-nums}
input[type=range]{-webkit-appearance:none;appearance:none;width:100%;height:4px;border-radius:2px;outline:none;background:rgba(255,255,255,0.08)}
input[type=range]::-webkit-slider-thumb{-webkit-appearance:none;width:18px;height:18px;border-radius:50%;background:#fff;cursor:pointer;transition:transform .15s}
input[type=range]::-webkit-slider-thumb:active{transform:scale(1.15)}
input[type=range]::-moz-range-thumb{width:18px;height:18px;border:none;border-radius:50%;background:#fff;cursor:pointer}

/* ── Mode Toggle ── */
.mode-row{display:flex;align-items:center;justify-content:center;gap:20px;background:var(--card);border:1px solid var(--card-border);border-radius:12px;padding:18px}
.mode-label{font-size:0.85rem;font-weight:500;color:var(--text3);transition:color .3s;cursor:default}
.mode-label.active{color:var(--text)}
.mode-switch{position:relative;width:48px;height:26px;cursor:pointer}
.mode-switch input{display:none}
.mode-switch .ms{position:absolute;inset:0;background:rgba(255,255,255,0.08);border-radius:13px;transition:background .3s}
.mode-switch .ms::after{content:'';position:absolute;left:3px;top:3px;width:20px;height:20px;background:rgba(255,255,255,0.3);border-radius:50%;transition:transform .3s,background .3s}
.mode-switch input:checked+.ms{background:rgba(255,255,255,0.12)}
.mode-switch input:checked+.ms::after{transform:translateX(22px);background:#fff}

/* ── System Info ── */
.sys-grid{display:grid;grid-template-columns:1fr 1fr;gap:6px 20px}
.sys-item{display:flex;justify-content:space-between;font-size:0.72rem;color:var(--text2);padding:4px 0}
.sys-item span:last-child{color:rgba(255,255,255,0.6);font-weight:500;font-family:'SF Mono','Fira Code',monospace}
.ota-note{text-align:center;margin-top:14px;font-size:0.65rem;color:var(--text3)}

/* ── Responsive ── */
@media(max-width:480px){
  .container{padding:14px 12px}
  .card-grid{gap:8px}
  .header h1{font-size:1.1rem}
  .card-value{font-size:1.5rem}
}
</style>
</head>
<body>
<div class="container">
  <!-- Header -->
  <div class="header">
    <h1>Room Control</h1>
    <div class="conn-status"><div class="dot" id="wsDot"></div><span id="wsLabel">Connecting…</span></div>
  </div>

  <!-- Sensor Cards -->
  <div class="section">
    <div class="section-title">Sensors</div>
    <div class="card-grid">
      <div class="card">
        <div class="card-value" id="vLux">--</div>
        <div class="card-label">Ambient Lux</div>
      </div>
      <div class="card">
        <div class="card-value" id="vSmoke">--</div>
        <div class="card-label">Smoke Level</div>
      </div>
      <div class="card">
        <div class="card-value" id="vPresence">--</div>
        <div class="card-label">Room Presence</div>
      </div>
      <div class="card">
        <div class="card-value" id="vCigs">--</div>
        <div class="card-label">Cigarettes Today</div>
      </div>
    </div>
  </div>

  <!-- Relay Switches -->
  <div class="section">
    <div class="section-title">Switches</div>
    <div class="relay-grid">
      <div class="relay-row">
        <span class="relay-label">Main Lights</span>
        <label class="toggle"><input type="checkbox" id="r0" onchange="sendRelay(0,this.checked)"><span class="slider"></span></label>
      </div>
      <div class="relay-row">
        <span class="relay-label">Fan</span>
        <label class="toggle"><input type="checkbox" id="r1" onchange="sendRelay(1,this.checked)"><span class="slider"></span></label>
      </div>
      <div class="relay-row">
        <span class="relay-label">220V RGB Light</span>
        <label class="toggle"><input type="checkbox" id="r2" onchange="sendRelay(2,this.checked)"><span class="slider"></span></label>
      </div>
      <div class="relay-row">
        <span class="relay-label">Charging Socket</span>
        <label class="toggle"><input type="checkbox" id="r3" onchange="sendRelay(3,this.checked)"><span class="slider"></span></label>
      </div>
    </div>
  </div>

  <!-- Brightness -->
  <div class="section">
    <div class="section-title">Brightness</div>
    <div class="slider-row">
      <div class="slider-header">
        <span class="slider-name">Flashlight</span>
        <span class="slider-val" id="vFlash">0%</span>
      </div>
      <input type="range" id="sFlash" min="0" max="255" value="0" oninput="sendFlash(this.value)">
    </div>
    <div class="slider-row">
      <div class="slider-header">
        <span class="slider-name">LED Strip</span>
        <span class="slider-val" id="vStrip">0%</span>
      </div>
      <input type="range" id="sStrip" min="0" max="255" value="0" oninput="sendStrip(this.value)">
    </div>
  </div>

  <!-- Mode -->
  <div class="section">
    <div class="section-title">Mode</div>
    <div class="mode-row">
      <span class="mode-label active" id="mAwake">AWAKE</span>
      <label class="mode-switch"><input type="checkbox" id="mToggle" onchange="sendMode(this.checked)"><span class="ms"></span></label>
      <span class="mode-label" id="mSleep">SLEEP</span>
    </div>
  </div>

  <!-- System Info -->
  <div class="section">
    <div class="section-title">System</div>
    <div class="card" style="padding:16px 18px">
      <div class="sys-grid">
        <div class="sys-item"><span>WiFi Signal</span><span id="vRssi">--</span></div>
        <div class="sys-item"><span>IP Address</span><span id="vIp">--</span></div>
        <div class="sys-item"><span>Uptime</span><span id="vUptime">--</span></div>
        <div class="sys-item"><span>Free Heap</span><span id="vHeap">--</span></div>
        <div class="sys-item"><span>Proximity</span><span id="vProx">--</span></div>
        <div class="sys-item"><span>Smoke Cal</span><span id="vCal">--</span></div>
      </div>
    </div>
    <p class="ota-note">OTA updates via Arduino IDE / PlatformIO on port 3232</p>
  </div>
</div>

<script>
/* ═══ WebSocket ═══ */
let ws,retryN=0;
const RETRY_MAX=30000;

function connect(){
  ws=new WebSocket('ws://'+location.host+'/ws');
  ws.onopen=()=>{retryN=0;setConn(true)};
  ws.onclose=()=>{setConn(false);let d=Math.min(1000*Math.pow(2,retryN),RETRY_MAX);retryN++;setTimeout(connect,d)};
  ws.onerror=()=>{ws.close()};
  ws.onmessage=e=>{try{update(JSON.parse(e.data))}catch(x){}};
}

function setConn(ok){
  document.getElementById('wsDot').className='dot'+(ok?' on':'');
  document.getElementById('wsLabel').textContent=ok?'Connected':'Reconnecting…';
}

/* ═══ UI Update ═══ */
function update(d){
  // Sensors
  setText('vLux',d.lux!=null&&d.lux>=0?d.lux.toFixed(1)+' lx':'N/A');
  setText('vSmoke',d.smoke!=null?d.smoke:'N/A');
  let pEl=document.getElementById('vPresence');
  if(pEl)pEl.textContent=d.present?'Present':'Empty';
  setText('vCigs',d.cigs!=null?d.cigs:'--');

  // Relays (don't update while user is interacting)
  for(let i=0;i<4;i++){let cb=document.getElementById('r'+i);if(cb&&document.activeElement!==cb)cb.checked=d.relays[i]}

  // Brightness (don't fight user drag)
  let sf=document.getElementById('sFlash'),ss=document.getElementById('sStrip');
  if(sf&&document.activeElement!==sf){sf.value=d.flash;setText('vFlash',Math.round(d.flash/2.55)+'%')}
  if(ss&&document.activeElement!==ss){ss.value=d.strip;setText('vStrip',Math.round(d.strip/2.55)+'%')}

  // Mode
  let mt=document.getElementById('mToggle');
  if(mt)mt.checked=(d.mode==='sleep');
  document.getElementById('mAwake').className='mode-label'+(d.mode==='awake'?' active':'');
  document.getElementById('mSleep').className='mode-label'+(d.mode==='sleep'?' active':'');

  // System
  setText('vRssi',d.rssi!=null?d.rssi+' dBm':'--');
  setText('vIp',d.ip||'--');
  setText('vUptime',fmtUp(d.uptime));
  setText('vHeap',d.heap!=null?Math.round(d.heap/1024)+' KB':'--');
  setText('vProx',d.prox!=null?d.prox:'--');
  setText('vCal',d.calibrated?('B:'+d.baseline+' T:'+d.threshold):'Calibrating…');
}

function setText(id,v){let e=document.getElementById(id);if(e)e.textContent=v}

function fmtUp(s){
  if(s==null)return'--';
  let h=Math.floor(s/3600),m=Math.floor((s%3600)/60);
  return h>0?h+'h '+m+'m':m+'m';
}

/* ═══ Controls ═══ */
function send(o){if(ws&&ws.readyState===1)ws.send(JSON.stringify(o))}
function sendRelay(ch,v){send({cmd:'relay',ch:ch,val:v})}
function sendFlash(v){v=parseInt(v);setText('vFlash',Math.round(v/2.55)+'%');send({cmd:'flash',val:v})}
function sendStrip(v){v=parseInt(v);setText('vStrip',Math.round(v/2.55)+'%');send({cmd:'strip',val:v})}
function sendMode(sleep){send({cmd:'mode',val:sleep?'sleep':'awake'})}

/* ═══ Slider track gradient (white fill, no colored glow) ═══ */
/* BUG-04 fix: removed broken Object.defineProperty, rely on setInterval only */
setInterval(()=>{
  document.querySelectorAll('input[type=range]').forEach(s=>{
    let p=(s.value-s.min)/(s.max-s.min)*100;
    s.style.background='linear-gradient(to right,rgba(255,255,255,0.5) 0%,rgba(255,255,255,0.5) '+p+'%,rgba(255,255,255,0.08) '+p+'%,rgba(255,255,255,0.08) 100%)';
  });
},300);

/* Also update on direct input */
document.querySelectorAll('input[type=range]').forEach(s=>{
  function up(){let p=(s.value-s.min)/(s.max-s.min)*100;s.style.background='linear-gradient(to right,rgba(255,255,255,0.5) 0%,rgba(255,255,255,0.5) '+p+'%,rgba(255,255,255,0.08) '+p+'%,rgba(255,255,255,0.08) 100%)'}
  s.addEventListener('input',up);up();
});

connect();
</script>
</body>
</html>
)rawliteral";
