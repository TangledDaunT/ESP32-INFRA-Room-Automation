// =========================================
//  config.h
// =========================================

// ═══════════════════════════════════════════════════
//  WiFi & Network
// ═══════════════════════════════════════════════════
#define WIFI_SSID               "1706-2.4G"
#define WIFI_PASS               "12345678@"
#define WIFI_HOSTNAME           "shreyansh"    // http://shreyansh.local
#define WIFI_RECONNECT_MS       30000          // 30 s

// ═══════════════════════════════════════════════════
//  BLE
// ═══════════════════════════════════════════════════
#define ENABLE_BLE              true
#define BLE_DEVICE_NAME         "OpenClaw_ESP32"
#define BLE_SERVICE_UUID        "4fafc201-1fb5-459e-8fcc-c5c9c331914b"
#define BLE_CHAR_CMD_UUID       "beb5483e-36e1-4688-b7f5-ea07361b26a8"  // WRITE  (phone app writes here)
#define BLE_CHAR_STATE_UUID     "beb5483e-36e1-4688-b7f5-ea07361b26a9"  // READ+NOTIFY (phone app listens here)

// ═══════════════════════════════════════════════════
//  Pin Definitions
// ═══════════════════════════════════════════════════

// MQ-2 Smoke Sensor
#define PIN_MQ2_AO              34   // ADC1_CH6 — input-only, works with WiFi
#define PIN_MQ2_DO              35   // Digital threshold output — input-only

// 4-Channel Relay Module (Active LOW)
#define PIN_RELAY_1             26   // Main Lights
#define PIN_RELAY_2             27   // Fan
#define PIN_RELAY_3             14   // 220 V RGB Light
#define PIN_RELAY_4             25   // Charging Socket
#define RELAY_COUNT             4

// D4184 MOSFET PWM
#define PIN_MOSFET_FLASH        32   // Flashlight
#define PIN_MOSFET_STRIP        33   // LED Strip

// RCWL-0516 Microwave Radar
#define PIN_RADAR               4

// TTP223 Capacitive Touch
#define PIN_TOUCH               5

// APDS-9930 (I2C)
#define PIN_I2C_SDA             21
#define PIN_I2C_SCL             22
#define APDS9930_I2C_ADDR       0x39

// Onboard Status LED
#define PIN_STATUS_LED          2

// ═══════════════════════════════════════════════════
//  PWM (LEDC)
// ═══════════════════════════════════════════════════
#define PWM_FREQ_HZ             5000  // 5 kHz — safe for D4184 optocoupler
#define PWM_RESOLUTION_BITS     8     // 0-255
#define PWM_CHANNEL_FLASH       0
#define PWM_CHANNEL_STRIP       1

// ═══════════════════════════════════════════════════
//  Timing (milliseconds unless noted)
// ═══════════════════════════════════════════════════
#define SENSOR_READ_INTERVAL    1000   // MQ2 sample rate
#define APDS_READ_INTERVAL      500    // Lux + proximity
#define WS_BROADCAST_INTERVAL   500    // WebSocket push rate
#define RADAR_DEBOUNCE_MS       500    // Reject sub-500 ms blips
#define TOUCH_DEBOUNCE_MS       300
#define PROXIMITY_COOLDOWN_MS   1500   // Min time between prox triggers
#define NVS_PERSIST_DEBOUNCE    5000   // Batch NVS writes

// ═══════════════════════════════════════════════════
//  Automation
// ═══════════════════════════════════════════════════
#define RADAR_ABSENCE_TIMEOUT   300000 // 5 min → mark room empty
#define FADE_IN_DURATION        2000   // Premium entry fade (ms)
#define FADE_OUT_DURATION       3000   // Exit fade (ms)
#define TOUCH_FADE_DURATION     1500   // TTP223 slow PWM ramp
#define PROXIMITY_THRESHOLD     200    // 0-1023, tune empirically
#define STRIP_DIM_BRIGHTNESS    50     // Night / sleep brightness
#define STRIP_DEFAULT_BRIGHTNESS 200   // Default full brightness

// ═══════════════════════════════════════════════════
//  MQ-2 Smoke Tracker
// ═══════════════════════════════════════════════════
#define MQ2_CALIBRATION_MS      120000 // 2-minute calibration window
#define MQ2_WARMUP_MS           30000  // First 30 s discarded
#define MQ2_SAMPLE_INTERVAL     1000   // 1 Hz sampling
#define MQ2_ADC_OVERSAMPLE      32     // Samples per reading
#define MQ2_SPIKE_SIGMA         3.0f   // Threshold = baseline + 3σ
#define MQ2_SPIKE_CONFIRM_SEC   10     // Sustained spike → cigarette
#define MQ2_COOLDOWN_MS         180000 // 3 min between counts

// ═══════════════════════════════════════════════════
//  NTP (IST — UTC+5:30)
// ═══════════════════════════════════════════════════
#define NTP_SERVER              "pool.ntp.org"
#define NTP_GMT_OFFSET_SEC      19800
#define NTP_DST_OFFSET_SEC      0

// ═══════════════════════════════════════════════════
//  WebSocket
// ═══════════════════════════════════════════════════
#define WS_MAX_CLIENTS          4

// ═══════════════════════════════════════════════════
//  Watchdog
// ═══════════════════════════════════════════════════
#define WDT_TIMEOUT_SEC         30

// ═══════════════════════════════════════════════════
//  MQTT (HiveMQ Cloud — TLS on port 8883)
// ═══════════════════════════════════════════════════
#define MQTT_BROKER         "7c7d7ed342c14133aa64550393a6e17e.s1.eu.hivemq.cloud"
#define MQTT_PORT           8883
#define MQTT_USER           "shreyanshesp"
#define MQTT_PASS           "Shreyanshesp32"
#define MQTT_CLIENT_ID      "openclaw_esp32"

// MQTT Topics (matching phone app defaults)
#define MQTT_T_FAN              "openclaw/control/fan"
#define MQTT_T_LIGHT            "openclaw/control/light"
#define MQTT_T_SOCKET           "openclaw/control/socket"
#define MQTT_T_RGB              "openclaw/control/rgb"
#define MQTT_T_RGB_BRIGHT       "openclaw/control/rgb/brightness"
#define MQTT_T_BACKUP_BRIGHT    "openclaw/control/backup/brightness"
#define MQTT_T_SMOKE            "openclaw/sensors/smoke"
#define MQTT_T_LUX              "openclaw/sensors/lux"
#define MQTT_T_PRESENCE         "openclaw/sensors/presence"
#define MQTT_T_STATE            "openclaw/state"
#define MQTT_PUBLISH_MS         2000

// ═══════════════════════════════════════════════════
//  Automation — Lux daylight gate
// ═══════════════════════════════════════════════════
#define LUX_DAYLIGHT_THRESHOLD  150


// =========================================
//  dashboard.h
// =========================================

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


// =========================================
//  hardware.h
// =========================================
#include <Arduino.h>

// ═══════════════════════════════════════════════════
//  Fade animation state (non-blocking PWM ramp)
// ═══════════════════════════════════════════════════
struct FadeState {
    bool     active    = false;
    uint8_t  startVal  = 0;
    uint8_t  endVal    = 0;
    unsigned long startTime = 0;
    unsigned long duration  = 0;
};

// ═══════════════════════════════════════════════════
//  Initialisation
// ═══════════════════════════════════════════════════
void     hw_init();                       // Call once in setup()
bool     hw_apdsAvailable();              // True if APDS-9930 responded on I2C

// ═══════════════════════════════════════════════════
//  Relay control  (channel 0-3, state true=ON)
// ═══════════════════════════════════════════════════
void     hw_setRelay(uint8_t ch, bool on);
bool     hw_getRelay(uint8_t ch);
const char* hw_relayLabel(uint8_t ch);

// ═══════════════════════════════════════════════════
//  MOSFET PWM  (brightness 0-255)
// ═══════════════════════════════════════════════════
void     hw_setFlashBrightness(uint8_t val);
void     hw_setStripBrightness(uint8_t val);
uint8_t  hw_getFlashBrightness();
uint8_t  hw_getStripBrightness();

// Smooth fade (non-blocking, call hw_updateFades() in loop)
void     hw_fadeFlash(uint8_t target, unsigned long durationMs);
void     hw_fadeStrip(uint8_t target, unsigned long durationMs);
void     hw_cancelFades();    // Cancel any in-progress fade
void     hw_updateFades();    // Must be called every loop iteration
bool     hw_isFading();       // True if any fade is active

// ═══════════════════════════════════════════════════
//  MQ-2 Smoke Sensor
// ═══════════════════════════════════════════════════
uint16_t hw_readSmokeAnalog();   // 32-sample oversampled ADC (0-4095)
bool     hw_readSmokeDigital();  // DO pin state

// ═══════════════════════════════════════════════════
//  APDS-9930  (returns false if sensor unavailable)
// ═══════════════════════════════════════════════════
bool     hw_readLux(float &lux);
bool     hw_readProximity(uint16_t &prox);

// ═══════════════════════════════════════════════════
//  RCWL-0516 Radar  (debounced)
// ═══════════════════════════════════════════════════
bool     hw_readRadar();

// ═══════════════════════════════════════════════════
//  TTP223 Touch  (edge-detected: true only once per press)
// ═══════════════════════════════════════════════════
bool     hw_readTouchPressed();
uint32_t hw_getTouchHoldMs();           // Duration touch is held (0 if not held)

// ═══════════════════════════════════════════════════
//  Status LED  (GPIO 2)
// ═══════════════════════════════════════════════════
void     hw_setStatusLED(bool on);


// =========================================
//  smoke_tracker.h
// =========================================
#include <Arduino.h>

// ═══════════════════════════════════════════════════
//  MQ-2 Cigarette Smoke Tracker
//
//  Phase 1 — WARMUP   (0–30 s):  ignore noisy startup readings
//  Phase 2 — CALIBRATE (30–120 s): build baseline mean + σ
//  Phase 3 — IDLE / COOLDOWN: detect spikes, count cigarettes
//
//  BUG-05 fix: removed unreachable SMOKE_SMOKING state
// ═══════════════════════════════════════════════════

enum SmokePhase {
    SMOKE_WARMUP,
    SMOKE_CALIBRATE,
    SMOKE_IDLE,
    SMOKE_COOLDOWN
};

void         smoke_init();
void         smoke_feed(uint16_t analogVal);   // Call at 1 Hz with oversampled value
SmokePhase   smoke_getPhase();
bool         smoke_isCalibrated();
bool         smoke_isInCooldown();             // BUG-05 fix: renamed from smoke_isSmoking()
int          smoke_getCigaretteCount();
uint16_t     smoke_getBaseline();
uint16_t     smoke_getThreshold();
void         smoke_resetDaily();               // Call at midnight
void         smoke_restoreCount(int count);    // Restore from NVS after reboot


// =========================================
//  automation.h
// =========================================
#include <Arduino.h>

// ═══════════════════════════════════════════════════
//  Room mode (global state machine)
// ═══════════════════════════════════════════════════
enum RoomMode {
    MODE_AWAKE,
    MODE_SLEEP
};

void       auto_init();                     // Call in setup()
void       auto_update();                   // Call every loop iteration
RoomMode   auto_getMode();
void       auto_setMode(RoomMode m);        // Manual mode override (from dashboard)
bool       auto_isPresent();                // Room occupancy state


// =========================================
//  network.h
// =========================================
#include <Arduino.h>

// Forward-declare the command handler type (shared with webserver.h)
typedef void (*CommandHandler)(const String &json);

void     net_init(CommandHandler cmdHandler);  // WiFi + mDNS + OTA + BLE — call in setup()
void     net_loop();              // OTA handle + WiFi reconnect — call in loop()
bool     net_isWifiConnected();
int      net_getWifiRSSI();
String   net_getIP();

// BLE sensor push — call every 2 s from main loop (GAP-3)
void     net_blePushSensors(uint16_t smoke, float lux, bool present);

// BLE state push — call after state changes for immediate phone app UI update
void     net_blePushState(const String &stateJson);

// BLE connection status
bool     net_isBleConnected();


// =========================================
//  webserver.h
// =========================================
#include <Arduino.h>

// Forward-declare the command handler type (used by BLE too)

void ws_init(CommandHandler cmdHandler);   // Call in setup() after net_init()
void ws_broadcastState();                  // Call periodically (every 500 ms)
void ws_setCommandHandler(CommandHandler h);


// =========================================
//  mqtt_client.h
// =========================================
#include <Arduino.h>

// ═══════════════════════════════════════════════════
//  MQTT Client for OpenClaw integration
//  Uses PubSubClient over WiFiClientSecure (TLS)
//  for HiveMQ Cloud on port 8883
// ═══════════════════════════════════════════════════

void mqtt_init(CommandHandler cmdHandler);  // Call after ws_init()
void mqtt_loop();                           // Call in main loop
void mqtt_publishSensors(uint16_t smoke, float lux, bool present);
void mqtt_publishState();                   // Full openclaw/state JSON
bool mqtt_isConnected();


// =========================================
//  sensors.h
// =========================================
#include <Arduino.h>

// ═══════════════════════════════════════════════════
//  Thread-safe sensor getters
//  These read from mutex-protected globals in main.cpp
//  Use these instead of calling hw_read*() directly outside
//  the sensor task to avoid I2C race conditions.
// ═══════════════════════════════════════════════════

float    sensors_getLux();         // Returns -1 if mutex timeout
uint16_t sensors_getSmoke();      // Returns 0 if mutex timeout
bool     sensors_getSmokeDO();    // Returns false if mutex timeout
uint16_t sensors_getProximity();  // Returns 0 if mutex timeout
int      sensors_getCigarettes(); // Thread-safe cigarette count


// =========================================
//  hardware.cpp
// =========================================
#include <Wire.h>

// ═══════════════════════════════════════════════════
//  APDS-9930 Register Definitions
// ═══════════════════════════════════════════════════
#define APDS_CMD            0x80   // Command bit (repeated byte)
#define APDS_CMD_AUTO       0xA0   // Command + auto-increment
#define APDS_REG_ENABLE     0x00
#define APDS_REG_ATIME      0x01
#define APDS_REG_PTIME      0x02
#define APDS_REG_WTIME      0x03
#define APDS_REG_PPULSE     0x0E
#define APDS_REG_CONTROL    0x0F
#define APDS_REG_ID         0x12
#define APDS_REG_STATUS     0x13
#define APDS_REG_CH0DATAL   0x14
#define APDS_REG_CH1DATAL   0x16
#define APDS_REG_PDATAL     0x18
// Enable register bits
#define APDS_PON            0x01
#define APDS_AEN            0x02
#define APDS_PEN            0x04
#define APDS_WEN            0x08

// ═══════════════════════════════════════════════════
//  Module-level state
// ═══════════════════════════════════════════════════
static bool     _relayState[RELAY_COUNT] = {false, false, false, false};
static uint8_t  _flashBrightness = 0;
static uint8_t  _stripBrightness = 0;
static bool     _apdsOK = false;

// Fade animations
static FadeState _flashFade;
static FadeState _stripFade;

// Debounce state
static bool          _lastRadarRaw   = false;
static bool          _radarStable    = false;
static unsigned long _radarChangeMs  = 0;

static bool          _lastTouchRaw   = false;
static bool          _touchEdge      = false;
static unsigned long _touchChangeMs  = 0;
static unsigned long _touchHoldStart = 0;   // Track hold duration for AUTO-3

// Relay GPIO lookup
static const uint8_t _relayPins[RELAY_COUNT] = {
    PIN_RELAY_1, PIN_RELAY_2, PIN_RELAY_3, PIN_RELAY_4
};
static const char* _relayLabels[RELAY_COUNT] = {
    "Main Lights", "Fan", "220V RGB", "Charging"
};

// ═══════════════════════════════════════════════════
//  APDS-9930 low-level I2C helpers
// ═══════════════════════════════════════════════════

static bool apds_write(uint8_t reg, uint8_t val) {
    Wire.beginTransmission(APDS9930_I2C_ADDR);
    Wire.write(APDS_CMD | reg);
    Wire.write(val);
    return Wire.endTransmission() == 0;
}

static uint8_t apds_read8(uint8_t reg) {
    Wire.beginTransmission(APDS9930_I2C_ADDR);
    Wire.write(APDS_CMD | reg);
    Wire.endTransmission(false);
    Wire.requestFrom((uint8_t)APDS9930_I2C_ADDR, (uint8_t)1);
    return Wire.available() ? Wire.read() : 0;
}

static uint16_t apds_read16(uint8_t reg) {
    Wire.beginTransmission(APDS9930_I2C_ADDR);
    Wire.write(APDS_CMD_AUTO | reg);  // auto-increment for 2-byte read
    Wire.endTransmission(false);
    Wire.requestFrom((uint8_t)APDS9930_I2C_ADDR, (uint8_t)2);
    if (Wire.available() < 2) return 0;
    uint16_t lo = Wire.read();
    uint16_t hi = Wire.read();
    return (hi << 8) | lo;
}

static bool apds_init() {
    // Verify device ID (should be 0x39 for APDS-9930)
    uint8_t id = apds_read8(APDS_REG_ID);
    Serial.printf("[APDS] Device ID: 0x%02X\n", id);
    if (id != 0x39 && id != 0x12) {
        Serial.println("[APDS] WARNING: unexpected ID, attempting init anyway");
    }

    // ALS integration time: ~100 ms  (256 − 0xDB) × 2.73 ms ≈ 101 ms
    apds_write(APDS_REG_ATIME, 0xDB);
    // Proximity integration time: 2.73 ms
    apds_write(APDS_REG_PTIME, 0xFF);
    // Wait time: 2.73 ms
    apds_write(APDS_REG_WTIME, 0xFF);
    // 8 proximity pulses
    apds_write(APDS_REG_PPULSE, 8);
    // Control: PDRIVE=100mA, PDIODE=CH1, PGAIN=1x, AGAIN=1x → 0x20
    apds_write(APDS_REG_CONTROL, 0x20);
    // Enable: PON + AEN + PEN + WEN
    apds_write(APDS_REG_ENABLE, APDS_PON | APDS_AEN | APDS_PEN | APDS_WEN);

    delay(12);  // Allow power-on to stabilise

    // Verify enable register was written
    uint8_t en = apds_read8(APDS_REG_ENABLE);
    return (en & (APDS_PON | APDS_AEN | APDS_PEN)) != 0;
}

// Lux calculation from APDS-9930 datasheet coefficients (open air)
static float apds_calcLux(uint16_t ch0, uint16_t ch1) {
    if (ch0 == 0) return 0.0f;
    const float B  = 1.862f;
    const float C  = 0.746f;
    const float D  = 1.291f;
    const float GA = 0.49f;   // Glass attenuation factor (no cover)
    const float DF = 52.0f;   // Device factor

    float atimeMs  = (256.0f - 0xDB) * 2.73f;  // ~101 ms
    float again    = 1.0f;

    float iac1 = (float)ch0 - B * (float)ch1;
    float iac2 = C * (float)ch0 - D * (float)ch1;
    float iac  = max(max(iac1, iac2), 0.0f);

    float lpc  = GA * DF / (atimeMs * again);
    return iac * lpc;
}

// ═══════════════════════════════════════════════════
//  Ease-in-out for premium fade animation
// ═══════════════════════════════════════════════════
static float easeInOutQuad(float t) {
    return t < 0.5f ? 2.0f * t * t : 1.0f - powf(-2.0f * t + 2.0f, 2.0f) / 2.0f;
}

static void updateFade(FadeState *f, uint8_t channel, uint8_t *storedBrightness) {
    if (!f->active) return;

    unsigned long elapsed = millis() - f->startTime;
    if (elapsed >= f->duration) {
        ledcWrite(channel, f->endVal);
        *storedBrightness = f->endVal;
        f->active = false;
    } else {
        float progress = easeInOutQuad((float)elapsed / (float)f->duration);
        uint8_t val = (uint8_t)((float)f->startVal + ((float)f->endVal - (float)f->startVal) * progress);
        ledcWrite(channel, val);
        *storedBrightness = val;
    }
}

// ═══════════════════════════════════════════════════
//  PUBLIC: Initialisation
// ═══════════════════════════════════════════════════

void hw_init() {
    // --- Relay pins (active LOW: HIGH = relay OFF) ---
    for (int i = 0; i < RELAY_COUNT; i++) {
        pinMode(_relayPins[i], OUTPUT);
        digitalWrite(_relayPins[i], HIGH);  // All relays OFF at boot
    }

    // --- MOSFET PWM ---
    ledcSetup(PWM_CHANNEL_FLASH, PWM_FREQ_HZ, PWM_RESOLUTION_BITS);
    ledcAttachPin(PIN_MOSFET_FLASH, PWM_CHANNEL_FLASH);
    ledcWrite(PWM_CHANNEL_FLASH, 0);

    ledcSetup(PWM_CHANNEL_STRIP, PWM_FREQ_HZ, PWM_RESOLUTION_BITS);
    ledcAttachPin(PIN_MOSFET_STRIP, PWM_CHANNEL_STRIP);
    ledcWrite(PWM_CHANNEL_STRIP, 0);

    // --- MQ-2 ---
    pinMode(PIN_MQ2_AO, INPUT);
    pinMode(PIN_MQ2_DO, INPUT);

    // --- Radar ---
    pinMode(PIN_RADAR, INPUT);

    // --- Touch ---
    pinMode(PIN_TOUCH, INPUT);

    // --- Status LED ---
    pinMode(PIN_STATUS_LED, OUTPUT);
    digitalWrite(PIN_STATUS_LED, LOW);

    // --- I2C for APDS-9930 ---
    Wire.begin(PIN_I2C_SDA, PIN_I2C_SCL);
    Wire.setClock(100000);  // 100 kHz standard mode
    _apdsOK = apds_init();
    Serial.printf("[HW] APDS-9930: %s\n", _apdsOK ? "OK" : "NOT FOUND");
}

bool hw_apdsAvailable() {
    return _apdsOK;
}

// ═══════════════════════════════════════════════════
//  PUBLIC: Relay control
// ═══════════════════════════════════════════════════

void hw_setRelay(uint8_t ch, bool on) {
    if (ch >= RELAY_COUNT) return;
    _relayState[ch] = on;
    // Active LOW: LOW = relay ON, HIGH = relay OFF
    digitalWrite(_relayPins[ch], on ? LOW : HIGH);
}

bool hw_getRelay(uint8_t ch) {
    if (ch >= RELAY_COUNT) return false;
    return _relayState[ch];
}

const char* hw_relayLabel(uint8_t ch) {
    if (ch >= RELAY_COUNT) return "?";
    return _relayLabels[ch];
}

// ═══════════════════════════════════════════════════
//  PUBLIC: MOSFET brightness
// ═══════════════════════════════════════════════════

void hw_setFlashBrightness(uint8_t val) {
    _flashFade.active = false;  // Cancel ongoing fade
    _flashBrightness = val;
    ledcWrite(PWM_CHANNEL_FLASH, val);
}

void hw_setStripBrightness(uint8_t val) {
    _stripFade.active = false;
    _stripBrightness = val;
    ledcWrite(PWM_CHANNEL_STRIP, val);
}

uint8_t hw_getFlashBrightness() { return _flashBrightness; }
uint8_t hw_getStripBrightness() { return _stripBrightness; }

// ═══════════════════════════════════════════════════
//  PUBLIC: Smooth fade
// ═══════════════════════════════════════════════════

void hw_fadeFlash(uint8_t target, unsigned long durationMs) {
    _flashFade.startVal  = _flashBrightness;
    _flashFade.endVal    = target;
    _flashFade.startTime = millis();
    _flashFade.duration  = durationMs;
    _flashFade.active    = true;
}

void hw_fadeStrip(uint8_t target, unsigned long durationMs) {
    _stripFade.startVal  = _stripBrightness;
    _stripFade.endVal    = target;
    _stripFade.startTime = millis();
    _stripFade.duration  = durationMs;
    _stripFade.active    = true;
}

void hw_cancelFades() {
    _flashFade.active = false;
    _stripFade.active = false;
}

void hw_updateFades() {
    updateFade(&_flashFade, PWM_CHANNEL_FLASH, &_flashBrightness);
    updateFade(&_stripFade, PWM_CHANNEL_STRIP, &_stripBrightness);
}

bool hw_isFading() {
    return _flashFade.active || _stripFade.active;
}

// ═══════════════════════════════════════════════════
//  PUBLIC: MQ-2 Smoke Sensor
// ═══════════════════════════════════════════════════

uint16_t hw_readSmokeAnalog() {
    uint32_t sum = 0;
    for (int i = 0; i < MQ2_ADC_OVERSAMPLE; i++) {
        sum += analogRead(PIN_MQ2_AO);
        delayMicroseconds(100);
    }
    return (uint16_t)(sum / MQ2_ADC_OVERSAMPLE);
}

bool hw_readSmokeDigital() {
    return digitalRead(PIN_MQ2_DO) == HIGH;
}

// ═══════════════════════════════════════════════════
//  PUBLIC: APDS-9930
// ═══════════════════════════════════════════════════

bool hw_readLux(float &lux) {
    if (!_apdsOK) return false;
    uint16_t ch0 = apds_read16(APDS_REG_CH0DATAL);
    uint16_t ch1 = apds_read16(APDS_REG_CH1DATAL);
    lux = apds_calcLux(ch0, ch1);
    return true;
}

bool hw_readProximity(uint16_t &prox) {
    if (!_apdsOK) return false;
    prox = apds_read16(APDS_REG_PDATAL);
    return true;
}

// ═══════════════════════════════════════════════════
//  PUBLIC: RCWL-0516 Radar (software debounced)
// ═══════════════════════════════════════════════════

bool hw_readRadar() {
    bool raw = digitalRead(PIN_RADAR) == HIGH;
    unsigned long now = millis();

    if (raw != _lastRadarRaw) {
        _lastRadarRaw  = raw;
        _radarChangeMs = now;
    }

    // Only update stable state after debounce period
    if ((now - _radarChangeMs) >= RADAR_DEBOUNCE_MS) {
        _radarStable = _lastRadarRaw;
    }
    return _radarStable;
}

// ═══════════════════════════════════════════════════
//  PUBLIC: TTP223 Touch (edge detection)
// ═══════════════════════════════════════════════════

bool hw_readTouchPressed() {
    bool raw = digitalRead(PIN_TOUCH) == HIGH;
    unsigned long now = millis();
    bool pressed = false;

    // Detect rising edge with debounce
    if (raw && !_lastTouchRaw && (now - _touchChangeMs) >= TOUCH_DEBOUNCE_MS) {
        pressed = true;
        _touchChangeMs = now;
    }
    _lastTouchRaw = raw;
    return pressed;
}

uint32_t hw_getTouchHoldMs() {
    bool raw = digitalRead(PIN_TOUCH) == HIGH;
    if (raw) {
        if (_touchHoldStart == 0) _touchHoldStart = millis();
        return (uint32_t)(millis() - _touchHoldStart);
    } else {
        _touchHoldStart = 0;
        return 0;
    }
}

// ═══════════════════════════════════════════════════
//  PUBLIC: Status LED
// ═══════════════════════════════════════════════════

void hw_setStatusLED(bool on) {
    digitalWrite(PIN_STATUS_LED, on ? HIGH : LOW);
}


// =========================================
//  smoke_tracker.cpp
// =========================================
#include <math.h>

// ═══════════════════════════════════════════════════
//  Internal state
// ═══════════════════════════════════════════════════
static SmokePhase _phase = SMOKE_WARMUP;
static unsigned long _startTime = 0;

// Calibration accumulators
static double   _calSum      = 0.0;
static double   _calSumSq    = 0.0;
static uint32_t _calCount    = 0;

// Detection thresholds (set after calibration)
static uint16_t _baseline    = 0;
static uint16_t _threshold   = 0;

// Spike confirmation
static uint8_t  _spikeCount  = 0;   // Consecutive readings above threshold

// Cigarette counter
static int      _cigarettes  = 0;

// Cooldown tracking
static unsigned long _cooldownStart = 0;

// ═══════════════════════════════════════════════════
//  PUBLIC
// ═══════════════════════════════════════════════════

void smoke_init() {
    _phase        = SMOKE_WARMUP;
    _startTime    = millis();
    _calSum       = 0.0;
    _calSumSq     = 0.0;
    _calCount     = 0;
    _baseline     = 0;
    _threshold    = 0;
    _spikeCount   = 0;
    _cigarettes   = 0;
    _cooldownStart = 0;
    Serial.println("[SMOKE] Warmup started — 30 s sensor stabilisation");
}

void smoke_feed(uint16_t val) {
    unsigned long elapsed = millis() - _startTime;

    switch (_phase) {

    // ── WARMUP: discard first 30 s of noisy readings ──
    case SMOKE_WARMUP:
        if (elapsed >= MQ2_WARMUP_MS) {
            _phase = SMOKE_CALIBRATE;
            Serial.println("[SMOKE] Calibration started — collecting baseline");
        }
        break;

    // ── CALIBRATE: accumulate readings for mean + σ ──
    case SMOKE_CALIBRATE:
        _calSum   += (double)val;
        _calSumSq += (double)val * (double)val;
        _calCount++;

        if (elapsed >= MQ2_CALIBRATION_MS) {
            // Compute baseline and noise floor
            double mean   = _calSum / _calCount;
            double var    = (_calSumSq / _calCount) - (mean * mean);
            double sigma  = sqrt(max(var, 0.0));

            _baseline  = (uint16_t)mean;
            _threshold = (uint16_t)(mean + MQ2_SPIKE_SIGMA * sigma);

            // Safety floor: threshold must be at least baseline + 20
            if (_threshold < _baseline + 20) {
                _threshold = _baseline + 20;
            }

            _phase = SMOKE_IDLE;
            Serial.printf("[SMOKE] Calibrated — baseline: %u, σ: %.1f, threshold: %u  (%u samples)\n",
                          _baseline, (float)sigma, _threshold, _calCount);
        }
        break;

    // ── IDLE: watch for sustained spike ──
    case SMOKE_IDLE:
        if (val > _threshold) {
            _spikeCount++;
            if (_spikeCount >= MQ2_SPIKE_CONFIRM_SEC) {
                _cigarettes++;
                _phase = SMOKE_COOLDOWN;
                _cooldownStart = millis();
                _spikeCount = 0;
                Serial.printf("[SMOKE] Cigarette #%d detected (spike held %d s)\n",
                              _cigarettes, MQ2_SPIKE_CONFIRM_SEC);
            }
        } else {
            _spikeCount = 0;  // Reset counter if reading drops below threshold
        }
        break;

    // ── COOLDOWN: ignore spikes for 3 minutes to prevent double-counting ──
    case SMOKE_COOLDOWN:
        if ((millis() - _cooldownStart) >= MQ2_COOLDOWN_MS) {
            _spikeCount = 0;
            _phase = SMOKE_IDLE;
            Serial.println("[SMOKE] Cooldown complete — monitoring resumed");
        }
        break;
    }
}

SmokePhase smoke_getPhase()          { return _phase; }
bool       smoke_isCalibrated()      { return _phase >= SMOKE_IDLE; }
bool       smoke_isInCooldown()      { return _phase == SMOKE_COOLDOWN; }
int        smoke_getCigaretteCount() { return _cigarettes; }
uint16_t   smoke_getBaseline()       { return _baseline; }
uint16_t   smoke_getThreshold()      { return _threshold; }

void smoke_resetDaily() {
    _cigarettes = 0;
    Serial.println("[SMOKE] Daily counter reset to 0");
}

void smoke_restoreCount(int count) {
    _cigarettes = count;
    Serial.printf("[SMOKE] Restored count from NVS: %d\n", count);
}


// =========================================
//  automation.cpp
// =========================================

// ═══════════════════════════════════════════════════
//  Internal state
// ═══════════════════════════════════════════════════
static RoomMode _mode = MODE_AWAKE;

// Presence tracking
static bool          _present         = false;
static unsigned long _lastMotionMs    = 0;     // Last time radar saw motion
static bool          _wasPresent      = false;  // For entry edge detection

// Proximity trigger state
static bool          _proxTriggered   = false;
static unsigned long _lastProxMs      = 0;

// Sleep-mode strip toggle (proximity toggles strip on/off in sleep)
static bool          _sleepStripOn    = false;

// Touch state
static bool          _stripOnByTouch  = false;

// AUTO-2: Smoke-triggered fan state
static bool          _smokeFanActive  = false;
static SmokePhase    _lastSmokePhase  = SMOKE_WARMUP;

// AUTO-5: Absence all-off tracking
static bool          _absenceAllOff   = false;

// AUTO-3: Touch long-press tracking
static bool          _longPressTriggered = false;

// AUTO-4: BLE wake tracking
static bool          _lastBleConnected = false;

// ═══════════════════════════════════════════════════
//  Helpers
// ═══════════════════════════════════════════════════

static void enterSleep() {
    _mode = MODE_SLEEP;
    _sleepStripOn = false;
    Serial.println("[AUTO] → SLEEP mode");

    // Turn off lights
    hw_setRelay(0, false);  // Main lights OFF
    hw_setRelay(2, false);  // 220V RGB OFF
    // Fan (ch 1) and Charging (ch 3) stay as-is

    // Fade out strip and flash
    hw_fadeStrip(0, FADE_OUT_DURATION);
    hw_fadeFlash(0, FADE_OUT_DURATION);
}

static void enterAwake() {
    _mode = MODE_AWAKE;
    _sleepStripOn = false;
    _absenceAllOff = false;
    Serial.println("[AUTO] → AWAKE mode");
}

// ═══════════════════════════════════════════════════
//  PUBLIC
// ═══════════════════════════════════════════════════

void auto_init() {
    _mode         = MODE_AWAKE;
    _present      = false;
    _wasPresent   = false;
    _lastMotionMs = millis();
    _sleepStripOn = false;
    _stripOnByTouch = false;
    _smokeFanActive = false;
    _lastSmokePhase = SMOKE_WARMUP;
    _absenceAllOff  = false;
    _longPressTriggered = false;
    _lastBleConnected = false;
}

void auto_update() {
    unsigned long now = millis();

    // ──────────────────────────────────────────────
    //  1. Radar presence tracking
    // ──────────────────────────────────────────────
    bool radarNow = hw_readRadar();
    if (radarNow) {
        _lastMotionMs = now;
    }

    // Present if motion was seen within the absence timeout window
    _present = (now - _lastMotionMs) < RADAR_ABSENCE_TIMEOUT;

    // ──────────────────────────────────────────────
    //  2. Proximity sensor (hand wave detection)
    //     BUG-06 fix: use cached sensor value instead
    //     of hw_readProximity() to avoid I2C race
    // ──────────────────────────────────────────────
    uint16_t prox = sensors_getProximity();
    bool proxTrigger = false;
    bool nearNow = prox > PROXIMITY_THRESHOLD;
    // Detect rising edge with cooldown
    if (nearNow && !_proxTriggered && (now - _lastProxMs) >= PROXIMITY_COOLDOWN_MS) {
        proxTrigger    = true;
        _lastProxMs    = now;
    }
    _proxTriggered = nearNow;

    // ──────────────────────────────────────────────
    //  3. TTP223 touch (works in both modes, offline)
    // ──────────────────────────────────────────────
    bool touchPressed = hw_readTouchPressed();

    // ──────────────────────────────────────────────
    //  3b. AUTO-3: Touch long-press (>2s) → all lights full
    // ──────────────────────────────────────────────
    uint32_t holdMs = hw_getTouchHoldMs();
    if (holdMs >= 2000 && !_longPressTriggered) {
        // Long press detected — turn everything ON full
        hw_setRelay(0, true);   // Main lights
        hw_setRelay(1, true);   // Fan
        hw_setRelay(2, true);   // 220V RGB
        hw_setRelay(3, true);   // Charging socket
        hw_setStripBrightness(255);
        hw_setFlashBrightness(255);
        if (_mode == MODE_SLEEP) enterAwake();
        _longPressTriggered = true;
        Serial.println("[AUTO] Long-press → ALL ON full brightness");
    }
    if (holdMs == 0) {
        _longPressTriggered = false;  // Reset when released
    }

    // ──────────────────────────────────────────────
    //  3c. AUTO-4: BLE connect → auto-wake from sleep
    // ──────────────────────────────────────────────
    bool bleNow = net_isBleConnected();
    if (bleNow && !_lastBleConnected && _mode == MODE_SLEEP) {
        // Phone just connected via BLE while in sleep → wake up
        enterAwake();
        Serial.println("[AUTO] BLE connect → auto-wake from sleep");
    }
    _lastBleConnected = bleNow;

    // ──────────────────────────────────────────────
    //  4. AUTO-2: Smoke alarm fan trigger
    //     When cigarette detected (transition to COOLDOWN),
    //     turn fan ON. Turn fan OFF when cooldown completes.
    // ──────────────────────────────────────────────
    SmokePhase curPhase = smoke_getPhase();
    if (curPhase == SMOKE_COOLDOWN && _lastSmokePhase != SMOKE_COOLDOWN) {
        // Transition into cooldown — cigarette just detected
        if (!hw_getRelay(1)) {  // Fan is relay ch1
            hw_setRelay(1, true);
            _smokeFanActive = true;
            Serial.println("[AUTO] Smoke detected — fan ON");
        }
    }
    if (_smokeFanActive && curPhase == SMOKE_IDLE && _lastSmokePhase == SMOKE_COOLDOWN) {
        // Cooldown just completed — turn fan off if we turned it on
        hw_setRelay(1, false);
        _smokeFanActive = false;
        Serial.println("[AUTO] Smoke cooldown done — fan OFF");
    }
    _lastSmokePhase = curPhase;

    // ──────────────────────────────────────────────
    //  5. Mode-specific automation
    // ──────────────────────────────────────────────

    if (_mode == MODE_AWAKE) {
        // ── Radar: entry fade-in ──
        if (_present && !_wasPresent) {
            // Someone just entered the room — premium fade-in
            // AUTO-1: gate by lux — don't turn on lights in bright room
            float lux = sensors_getLux();
            if (lux < 0 || lux < LUX_DAYLIGHT_THRESHOLD) {
                Serial.println("[AUTO] Presence detected — LED strip fade in");
                uint8_t target = (hw_getStripBrightness() > 0) ? hw_getStripBrightness() : STRIP_DEFAULT_BRIGHTNESS;
                hw_fadeStrip(target, FADE_IN_DURATION);
            } else {
                Serial.printf("[AUTO] Presence detected — lux %.0f ≥ %d, skip fade-in\n", lux, LUX_DAYLIGHT_THRESHOLD);
            }
            _absenceAllOff = false;  // Reset absence flag on re-entry
        }

        // ── Radar: absence fade-out ──
        if (!_present && _wasPresent) {
            Serial.println("[AUTO] Room empty — LED strip fade out");
            hw_fadeStrip(0, FADE_OUT_DURATION);
        }

        // ── AUTO-5: Extended absence all-off ──
        // If radar absence exceeds timeout AND mode is AWAKE,
        // turn off all relays in addition to faded strip
        if (!_present && !_absenceAllOff) {
            // Check if absence has persisted long enough
            // (RADAR_ABSENCE_TIMEOUT already defines the threshold)
            // At this point _present is false, meaning absence > 5 min
            hw_setRelay(0, false);  // Main lights
            hw_setRelay(1, false);  // Fan
            hw_setRelay(2, false);  // 220V RGB
            // Keep charging socket (ch3) as-is — intentional
            _absenceAllOff = true;
            Serial.println("[AUTO] Extended absence — all relays OFF");
        }

        // ── TTP223: toggle LED strip with slow fade ──
        if (touchPressed) {
            if (hw_getStripBrightness() > 0 || hw_isFading()) {
                // Strip is ON or fading in → fade out
                hw_fadeStrip(0, TOUCH_FADE_DURATION);
                _stripOnByTouch = false;
                Serial.println("[AUTO] Touch → strip fade out");
            } else {
                // Strip is OFF → fade in
                hw_fadeStrip(STRIP_DEFAULT_BRIGHTNESS, TOUCH_FADE_DURATION);
                _stripOnByTouch = true;
                Serial.println("[AUTO] Touch → strip fade in");
            }
        }

        // ── Proximity: enter sleep ──
        if (proxTrigger) {
            enterSleep();
        }

    } else {
        // ═══ MODE_SLEEP ═══

        // ── Proximity: toggle dim LED strip for nighttime ──
        if (proxTrigger) {
            if (_sleepStripOn) {
                hw_fadeStrip(0, TOUCH_FADE_DURATION);
                _sleepStripOn = false;
                Serial.println("[AUTO] Sleep prox → strip OFF");
            } else {
                hw_fadeStrip(STRIP_DIM_BRIGHTNESS, TOUCH_FADE_DURATION);
                _sleepStripOn = true;
                Serial.println("[AUTO] Sleep prox → strip dim ON");
            }
        }

        // ── Radar: if presence after long absence, wake up ──
        // (If you were sleeping and someone walks in, assume waking up)
        if (_present && !_wasPresent) {
            // Don't auto-wake immediately — only proximity wakes.
            // But we do update _wasPresent below.
        }

        // ── TTP223 still works in sleep: toggle strip ──
        if (touchPressed) {
            if (_sleepStripOn || hw_getStripBrightness() > 0) {
                hw_fadeStrip(0, TOUCH_FADE_DURATION);
                _sleepStripOn = false;
            } else {
                hw_fadeStrip(STRIP_DIM_BRIGHTNESS, TOUCH_FADE_DURATION);
                _sleepStripOn = true;
            }
        }
    }

    _wasPresent = _present;
}

RoomMode auto_getMode() {
    return _mode;
}

void auto_setMode(RoomMode m) {
    if (m == MODE_SLEEP && _mode != MODE_SLEEP) {
        enterSleep();
    } else if (m == MODE_AWAKE && _mode != MODE_AWAKE) {
        enterAwake();
    }
}

bool auto_isPresent() {
    return _present;
}


// =========================================
//  network.cpp
// =========================================

#include <WiFi.h>
#include <ESPmDNS.h>
#include <ArduinoOTA.h>
#include <esp_task_wdt.h>
#include <ArduinoJson.h>

#if ENABLE_BLE
#include <BLEDevice.h>
#include <BLEServer.h>
#include <BLEUtils.h>
#include <BLE2902.h>
#endif

// ═══════════════════════════════════════════════════
//  Internal state
// ═══════════════════════════════════════════════════
static unsigned long _lastReconnectAttempt = 0;
static bool          _wifiWasConnected     = false;

#if ENABLE_BLE
static BLEServer         *_bleServer    = nullptr;
static BLECharacteristic *_charState    = nullptr;
static BLECharacteristic *_charCmd      = nullptr;
static bool               _bleDeviceConnected = false;

// BLE command callback — wired via net_init(cmdHandler) (BUG-10 fix)
static CommandHandler _bleCmdCb = nullptr;

class ServerCallbacks : public BLEServerCallbacks {
    void onConnect(BLEServer *s)    override { _bleDeviceConnected = true;  Serial.println("[BLE] Client connected"); }
    void onDisconnect(BLEServer *s) override { _bleDeviceConnected = false; Serial.println("[BLE] Client disconnected"); s->startAdvertising(); }
};

class CmdCallbacks : public BLECharacteristicCallbacks {
    void onWrite(BLECharacteristic *c) override {
        std::string val = c->getValue();
        if (val.length() > 0 && _bleCmdCb) {
            _bleCmdCb(String(val.c_str()));
        }
    }
};
#endif

// ═══════════════════════════════════════════════════
//  WiFi connection (non-blocking)
// ═══════════════════════════════════════════════════

static void wifi_connect() {
    Serial.printf("[NET] Connecting to WiFi: %s\n", WIFI_SSID);
    WiFi.mode(WIFI_STA);
    WiFi.setHostname(WIFI_HOSTNAME);
    WiFi.setAutoReconnect(true);
    WiFi.begin(WIFI_SSID, WIFI_PASS);
}

// ═══════════════════════════════════════════════════
//  PUBLIC
// ═══════════════════════════════════════════════════

void net_init(CommandHandler cmdHandler) {
    // ── WiFi ──
    wifi_connect();

    // Wait up to 10 s for initial connection (non-blocking afterwards)
    unsigned long start = millis();
    while (WiFi.status() != WL_CONNECTED && (millis() - start) < 10000) {
        delay(250);
        Serial.print(".");
        hw_setStatusLED((millis() / 250) % 2);  // Blink while connecting
    }
    Serial.println();

    if (WiFi.status() == WL_CONNECTED) {
        _wifiWasConnected = true;
        hw_setStatusLED(true);
        Serial.printf("[NET] WiFi connected — IP: %s\n", WiFi.localIP().toString().c_str());
    } else {
        Serial.println("[NET] WiFi connection timed out — will retry in background");
    }

    // ── mDNS ──
    if (MDNS.begin(WIFI_HOSTNAME)) {
        MDNS.addService("http", "tcp", 80);
        Serial.printf("[NET] mDNS started: http://%s.local\n", WIFI_HOSTNAME);
    }

    // ── OTA ──
    ArduinoOTA.setHostname(WIFI_HOSTNAME);
    ArduinoOTA.onStart([]() {
        String type = (ArduinoOTA.getCommand() == U_FLASH) ? "firmware" : "filesystem";
        Serial.printf("[OTA] Updating %s...\n", type.c_str());
    });
    ArduinoOTA.onEnd([]() {
        Serial.println("\n[OTA] Update complete — rebooting");
    });
    ArduinoOTA.onProgress([](unsigned int progress, unsigned int total) {
        Serial.printf("[OTA] %u%%\r", progress * 100 / total);
        esp_task_wdt_reset();
    });
    ArduinoOTA.onError([](ota_error_t error) {
        Serial.printf("[OTA] Error[%u]: ", error);
        if      (error == OTA_AUTH_ERROR)    Serial.println("Auth failed");
        else if (error == OTA_BEGIN_ERROR)   Serial.println("Begin failed");
        else if (error == OTA_CONNECT_ERROR) Serial.println("Connect failed");
        else if (error == OTA_RECEIVE_ERROR) Serial.println("Receive failed");
        else if (error == OTA_END_ERROR)     Serial.println("End failed");
    });
    ArduinoOTA.begin();

    // ── BLE ──
#if ENABLE_BLE
    // Wire the command callback (BUG-10 fix)
    _bleCmdCb = cmdHandler;

    BLEDevice::init(BLE_DEVICE_NAME);
    _bleServer = BLEDevice::createServer();
    _bleServer->setCallbacks(new ServerCallbacks());

    BLEService *service = _bleServer->createService(BLE_SERVICE_UUID);

    // State characteristic (read + notify)
    _charState = service->createCharacteristic(
        BLE_CHAR_STATE_UUID,
        BLECharacteristic::PROPERTY_READ | BLECharacteristic::PROPERTY_NOTIFY
    );
    _charState->addDescriptor(new BLE2902());

    // Command characteristic (write)
    _charCmd = service->createCharacteristic(
        BLE_CHAR_CMD_UUID,
        BLECharacteristic::PROPERTY_WRITE | BLECharacteristic::PROPERTY_WRITE_NR
    );
    _charCmd->setCallbacks(new CmdCallbacks());

    service->start();

    BLEAdvertising *adv = BLEDevice::getAdvertising();
    adv->addServiceUUID(BLE_SERVICE_UUID);
    adv->setScanResponse(true);
    adv->setMinPreferred(0x06);   // 7.5ms min connection interval (BUG-08 fix)
    adv->setMaxPreferred(0x12);   // 22.5ms max connection interval (BUG-08 fix)
    BLEDevice::startAdvertising();
    Serial.println("[BLE] Advertising started");
#else
    (void)cmdHandler;  // Suppress unused parameter warning when BLE disabled
#endif
}

void net_loop() {
    // ── OTA ──
    ArduinoOTA.handle();

    // ── WiFi reconnect ──
    unsigned long now = millis();
    if (WiFi.status() != WL_CONNECTED) {
        if ((now - _lastReconnectAttempt) >= WIFI_RECONNECT_MS) {
            _lastReconnectAttempt = now;
            Serial.println("[NET] WiFi lost — reconnecting...");
            WiFi.disconnect();
            WiFi.begin(WIFI_SSID, WIFI_PASS);
        }
        if (_wifiWasConnected) {
            hw_setStatusLED((now / 250) % 2);  // Blink when disconnected
        }
    } else {
        if (!_wifiWasConnected) {
            _wifiWasConnected = true;
            hw_setStatusLED(true);
            Serial.printf("[NET] WiFi reconnected — IP: %s\n", WiFi.localIP().toString().c_str());
        }
    }
}

bool   net_isWifiConnected() { return WiFi.status() == WL_CONNECTED; }
int    net_getWifiRSSI()     { return WiFi.RSSI(); }
String net_getIP()           { return WiFi.localIP().toString(); }

// ═══════════════════════════════════════════════════
//  BLE sensor push (GAP-3 fix)
//  Called from main loop every 2 s to notify phone app
// ═══════════════════════════════════════════════════
void net_blePushSensors(uint16_t smoke, float lux, bool present) {
#if ENABLE_BLE
    if (!_bleDeviceConnected || !_charState) return;

    StaticJsonDocument<128> doc;
    doc["smoke"]    = smoke;
    doc["lux"]      = (double)lux;
    doc["presence"] = present;

    char buf[128];
    serializeJson(doc, buf, sizeof(buf));
    _charState->setValue(buf);
    _charState->notify();
#else
    (void)smoke; (void)lux; (void)present;
#endif
}

// ═══════════════════════════════════════════════════
//  BLE state push — for immediate relay/brightness
//  change feedback to phone app
// ═══════════════════════════════════════════════════
void net_blePushState(const String &stateJson) {
#if ENABLE_BLE
    if (!_bleDeviceConnected || !_charState) return;
    _charState->setValue(stateJson.c_str());
    _charState->notify();
#else
    (void)stateJson;
#endif
}

bool net_isBleConnected() {
#if ENABLE_BLE
    return _bleDeviceConnected;
#else
    return false;
#endif
}


// =========================================
//  webserver.cpp
// =========================================

#include <ESPAsyncWebServer.h>
#include <ArduinoJson.h>

// ═══════════════════════════════════════════════════
//  Server & socket instances
// ═══════════════════════════════════════════════════
static AsyncWebServer  _server(80);
static AsyncWebSocket  _ws("/ws");
static CommandHandler  _cmdHandler = nullptr;

// ═══════════════════════════════════════════════════
//  Build current state JSON into a String
//  BUG-01/02/03 fix: uses thread-safe sensor getters
//  instead of calling hw_read*() directly
// ═══════════════════════════════════════════════════
static String buildStateJson() {
    StaticJsonDocument<512> doc;

    // Sensors — read from mutex-protected cache (no I2C race)
    float lux = sensors_getLux();
    bool luxOK = (lux >= 0);

    doc["lux"]       = luxOK ? (double)lux : (double)-1;
    doc["smoke"]     = sensors_getSmoke();
    doc["smokeDO"]   = sensors_getSmokeDO();
    doc["present"]   = auto_isPresent();
    doc["prox"]      = sensors_getProximity();
    doc["cigs"]      = sensors_getCigarettes();
    doc["calibrated"]= smoke_isCalibrated();
    doc["baseline"]  = smoke_getBaseline();
    doc["threshold"] = smoke_getThreshold();
    doc["smoking"]   = smoke_isInCooldown();

    // Relays
    JsonArray relays = doc.createNestedArray("relays");
    for (int i = 0; i < RELAY_COUNT; i++) relays.add(hw_getRelay(i));

    // Brightness
    doc["flash"] = hw_getFlashBrightness();
    doc["strip"] = hw_getStripBrightness();

    // Mode
    doc["mode"] = (auto_getMode() == MODE_SLEEP) ? "sleep" : "awake";

    // System
    doc["rssi"]   = net_getWifiRSSI();
    doc["ip"]     = net_getIP();
    doc["uptime"] = (unsigned long)(millis() / 1000);
    doc["heap"]   = ESP.getFreeHeap();

    String out;
    serializeJson(doc, out);
    return out;
}

// ═══════════════════════════════════════════════════
//  WebSocket event handler
// ═══════════════════════════════════════════════════
static void onWsEvent(AsyncWebSocket *server, AsyncWebSocketClient *client,
                      AwsEventType type, void *arg, uint8_t *data, size_t len) {
    switch (type) {
    case WS_EVT_CONNECT:
        Serial.printf("[WS] Client #%u connected from %s\n", client->id(),
                      client->remoteIP().toString().c_str());
        // Send initial state immediately
        client->text(buildStateJson());
        break;

    case WS_EVT_DISCONNECT:
        Serial.printf("[WS] Client #%u disconnected\n", client->id());
        break;

    case WS_EVT_DATA: {
        AwsFrameInfo *info = (AwsFrameInfo *)arg;
        if (info->final && info->index == 0 && info->len == len && info->opcode == WS_TEXT) {
            String msg;
            msg.reserve(len);
            for (size_t i = 0; i < len; ++i) {
                msg += (char)data[i];
            }
            if (_cmdHandler) _cmdHandler(msg);
        }
        break;
    }

    case WS_EVT_ERROR:
        Serial.printf("[WS] Client #%u error\n", client->id());
        break;

    case WS_EVT_PONG:
        break;
    }
}

// ═══════════════════════════════════════════════════
//  PUBLIC
// ═══════════════════════════════════════════════════

void ws_init(CommandHandler cmdHandler) {
    _cmdHandler = cmdHandler;

    // WebSocket
    _ws.onEvent(onWsEvent);
    _server.addHandler(&_ws);

    // Dashboard (serve embedded HTML)
    _server.on("/", HTTP_GET, [](AsyncWebServerRequest *request) {
        request->send_P(200, "text/html", DASHBOARD_HTML);
    });

    // REST API: full state
    _server.on("/api/state", HTTP_GET, [](AsyncWebServerRequest *request) {
        request->send(200, "application/json", buildStateJson());
    });

    // 404
    _server.onNotFound([](AsyncWebServerRequest *request) {
        request->send(404, "text/plain", "Not Found");
    });

    _server.begin();
    Serial.println("[WEB] HTTP server started on port 80");
}

void ws_broadcastState() {
    // Clean up stale connections
    _ws.cleanupClients(WS_MAX_CLIENTS);

    if (_ws.count() > 0) {
        String state = buildStateJson();
        _ws.textAll(state);
    }
}

void ws_setCommandHandler(CommandHandler h) {
    _cmdHandler = h;
}


// =========================================
//  mqtt_client.cpp
// =========================================

#include <WiFi.h>
#include <WiFiClientSecure.h>
#include <PubSubClient.h>
#include <ArduinoJson.h>
#include <esp_task_wdt.h>

// ═══════════════════════════════════════════════════
//  Internal state
// ═══════════════════════════════════════════════════
static WiFiClientSecure _tlsClient;
static PubSubClient     _mqtt(_tlsClient);
static CommandHandler   _mqttCmdHandler = nullptr;
static unsigned long    _lastReconnectAttempt = 0;
static const unsigned long RECONNECT_INTERVAL = 5000;  // 5 s backoff

// ═══════════════════════════════════════════════════
//  MQTT message callback
//  Translates phone app topic-based commands into
//  the JSON format handleCommand() understands
// ═══════════════════════════════════════════════════
static void mqttCallback(char *topic, byte *payload, unsigned int length) {
    // Null-terminate payload
    char msg[256];
    unsigned int copyLen = min(length, (unsigned int)(sizeof(msg) - 1));
    memcpy(msg, payload, copyLen);
    msg[copyLen] = '\0';

    Serial.printf("[MQTT] Received %s: %s\n", topic, msg);

    if (!_mqttCmdHandler) return;

    // Build a command JSON in phone app format that handleCommand() understands
    StaticJsonDocument<256> doc;

    // Translation: topic → device/state
    if (strcmp(topic, MQTT_T_FAN) == 0) {
        doc["device"] = "fan";
        doc["state"]  = msg;  // "ON" or "OFF"
    } else if (strcmp(topic, MQTT_T_LIGHT) == 0) {
        doc["device"] = "light";
        doc["state"]  = msg;
    } else if (strcmp(topic, MQTT_T_SOCKET) == 0) {
        doc["device"] = "socket";
        doc["state"]  = msg;
    } else if (strcmp(topic, MQTT_T_RGB) == 0) {
        doc["device"] = "rgb";
        doc["state"]  = msg;
    } else if (strcmp(topic, MQTT_T_RGB_BRIGHT) == 0) {
        doc["device"] = "rgb";
        doc["brightness"] = atoi(msg);
    } else if (strcmp(topic, MQTT_T_BACKUP_BRIGHT) == 0) {
        doc["device"] = "backup";
        doc["brightness"] = atoi(msg);
    } else {
        // Unknown topic — try passing raw payload as JSON command
        _mqttCmdHandler(String(msg));
        return;
    }

    String cmdJson;
    serializeJson(doc, cmdJson);
    _mqttCmdHandler(cmdJson);
}

// ═══════════════════════════════════════════════════
//  Subscribe to all control topics
// ═══════════════════════════════════════════════════
static void mqttSubscribe() {
    _mqtt.subscribe(MQTT_T_FAN);
    _mqtt.subscribe(MQTT_T_LIGHT);
    _mqtt.subscribe(MQTT_T_SOCKET);
    _mqtt.subscribe(MQTT_T_RGB);
    _mqtt.subscribe(MQTT_T_RGB_BRIGHT);
    _mqtt.subscribe(MQTT_T_BACKUP_BRIGHT);
    Serial.println("[MQTT] Subscribed to control topics");
}

// ═══════════════════════════════════════════════════
//  Non-blocking reconnect
// ═══════════════════════════════════════════════════
static bool mqttReconnect() {
    if (WiFi.status() != WL_CONNECTED) return false;

    Serial.println("[MQTT] Connecting to broker...");
    esp_task_wdt_reset();  // Feed watchdog during reconnect

    bool connected = false;
    if (strlen(MQTT_USER) > 0) {
        connected = _mqtt.connect(MQTT_CLIENT_ID, MQTT_USER, MQTT_PASS);
    } else {
        connected = _mqtt.connect(MQTT_CLIENT_ID);
    }

    if (connected) {
        Serial.println("[MQTT] Connected!");
        mqttSubscribe();
        return true;
    } else {
        Serial.printf("[MQTT] Connect failed, rc=%d — will retry\n", _mqtt.state());
        return false;
    }
}

// ═══════════════════════════════════════════════════
//  PUBLIC
// ═══════════════════════════════════════════════════

void mqtt_init(CommandHandler cmdHandler) {
    _mqttCmdHandler = cmdHandler;

    // TLS: skip certificate verification for simplicity
    // (HiveMQ Cloud uses Let's Encrypt; for production, pin the CA cert)
    _tlsClient.setInsecure();

    _mqtt.setServer(MQTT_BROKER, MQTT_PORT);
    _mqtt.setCallback(mqttCallback);
    _mqtt.setBufferSize(512);  // Larger buffer for state JSON

    Serial.printf("[MQTT] Configured for %s:%d\n", MQTT_BROKER, MQTT_PORT);
}

void mqtt_loop() {
    if (!_mqtt.connected()) {
        unsigned long now = millis();
        if ((now - _lastReconnectAttempt) >= RECONNECT_INTERVAL) {
            _lastReconnectAttempt = now;
            mqttReconnect();
        }
        return;
    }
    _mqtt.loop();
}

void mqtt_publishSensors(uint16_t smoke, float lux, bool present) {
    if (!_mqtt.connected()) return;

    char buf[16];

    snprintf(buf, sizeof(buf), "%u", smoke);
    _mqtt.publish(MQTT_T_SMOKE, buf);

    snprintf(buf, sizeof(buf), "%.1f", lux);
    _mqtt.publish(MQTT_T_LUX, buf);

    _mqtt.publish(MQTT_T_PRESENCE, present ? "true" : "false");
}

void mqtt_publishState() {
    if (!_mqtt.connected()) return;

    // Build state JSON matching phone app _parseFullState() expectations:
    // Keys: fan, light, socket, rgb, rgb_brightness, backup_brightness,
    //       smoke, lux, presence, mode
    StaticJsonDocument<384> doc;

    doc["fan"]              = hw_getRelay(1) ? "ON" : "OFF";
    doc["light"]            = hw_getRelay(0) ? "ON" : "OFF";
    doc["socket"]           = hw_getRelay(3) ? "ON" : "OFF";
    doc["rgb"]              = hw_getRelay(2) ? "ON" : "OFF";
    doc["rgb_brightness"]   = hw_getStripBrightness();
    doc["backup_brightness"]= hw_getFlashBrightness();
    doc["smoke"]            = sensors_getSmoke();
    doc["lux"]              = (double)sensors_getLux();
    doc["presence"]         = auto_isPresent();
    doc["mode"]             = (auto_getMode() == MODE_SLEEP) ? "sleep" : "awake";
    doc["cigs"]             = sensors_getCigarettes();
    doc["smoking"]          = smoke_isInCooldown();

    char buf[384];
    serializeJson(doc, buf, sizeof(buf));
    _mqtt.publish(MQTT_T_STATE, buf);
}

bool mqtt_isConnected() {
    return _mqtt.connected();
}


// =========================================
//  main.cpp
// =========================================
#include <Arduino.h>
#include <Preferences.h>
#include <ArduinoJson.h>
#include <esp_task_wdt.h>
#include <time.h>


// ═══════════════════════════════════════════════════
//  NVS persistent storage
// ═══════════════════════════════════════════════════
static Preferences prefs;
static bool        nvsDirty       = false;
static unsigned long lastNvsWrite = 0;

static void persistState() {
    prefs.putBool("r0", hw_getRelay(0));
    prefs.putBool("r1", hw_getRelay(1));
    prefs.putBool("r2", hw_getRelay(2));
    prefs.putBool("r3", hw_getRelay(3));
    prefs.putUChar("flash", hw_getFlashBrightness());
    prefs.putUChar("strip", hw_getStripBrightness());
    prefs.putInt("cigs", smoke_getCigaretteCount());
    prefs.putUChar("mode", (uint8_t)auto_getMode());
    Serial.println("[NVS] State persisted");
}

static void restoreState() {
    // Relays
    for (int i = 0; i < RELAY_COUNT; i++) {
        char key[4];
        snprintf(key, sizeof(key), "r%d", i);
        bool val = prefs.getBool(key, false);
        hw_setRelay(i, val);
    }
    // Brightness
    hw_setFlashBrightness(prefs.getUChar("flash", 0));
    hw_setStripBrightness(prefs.getUChar("strip", 0));
    // Cigarette count
    smoke_restoreCount(prefs.getInt("cigs", 0));
    // Mode
    uint8_t m = prefs.getUChar("mode", 0);
    if (m == MODE_SLEEP) auto_setMode(MODE_SLEEP);
    Serial.println("[NVS] State restored");
}

static void markDirty() {
    nvsDirty = true;
}

// ═══════════════════════════════════════════════════
//  Command handler (shared by WebSocket + BLE + MQTT)
// ═══════════════════════════════════════════════════
static void handleCommand(const String &json) {
    StaticJsonDocument<256> doc;
    DeserializationError err = deserializeJson(doc, json);
    if (err) {
        Serial.printf("[CMD] JSON parse error: %s\n", err.c_str());
        return;
    }

    // ── Original firmware format: {"cmd":"relay","ch":0,"val":true} ──
    const char *cmd = doc["cmd"];
    if (cmd) {
        if (strcmp(cmd, "relay") == 0) {
            int ch = doc["ch"] | -1;
            if (ch >= 0 && ch < RELAY_COUNT) {
                bool val = doc["val"] | false;
                hw_setRelay(ch, val);
                markDirty();
                Serial.printf("[CMD] Relay %d → %s\n", ch, val ? "ON" : "OFF");
            }
        } else if (strcmp(cmd, "flash") == 0) {
            int val = doc["val"] | 0;
            hw_setFlashBrightness(constrain(val, 0, 255));
            markDirty();
        } else if (strcmp(cmd, "strip") == 0) {
            int val = doc["val"] | 0;
            hw_setStripBrightness(constrain(val, 0, 255));
            markDirty();
        } else if (strcmp(cmd, "mode") == 0) {
            const char *m = doc["val"];
            if (m) {
                if (strcmp(m, "sleep") == 0)      auto_setMode(MODE_SLEEP);
                else if (strcmp(m, "awake") == 0)  auto_setMode(MODE_AWAKE);
                markDirty();
            }
        }
        return;  // Handled firmware format
    }

    // ── Phone app format (GAP-2): {"device":"fan","state":"ON"} ──
    //    or: {"device":"rgb","brightness":128}
    const char *device = doc["device"];
    if (device) {
        // Device → channel mapping:
        //   fan    → relay ch1
        //   light  → relay ch0
        //   socket → relay ch3
        //   rgb    → strip PWM (relay ch2 for 220V RGB power)
        //   backup → flash PWM

        if (strcmp(device, "fan") == 0) {
            const char *state = doc["state"];
            if (state) {
                hw_setRelay(1, strcmp(state, "ON") == 0);
                markDirty();
                Serial.printf("[CMD] Phone: fan → %s\n", state);
            }
        } else if (strcmp(device, "light") == 0) {
            const char *state = doc["state"];
            if (state) {
                hw_setRelay(0, strcmp(state, "ON") == 0);
                markDirty();
                Serial.printf("[CMD] Phone: light → %s\n", state);
            }
        } else if (strcmp(device, "socket") == 0) {
            const char *state = doc["state"];
            if (state) {
                hw_setRelay(3, strcmp(state, "ON") == 0);
                markDirty();
                Serial.printf("[CMD] Phone: socket → %s\n", state);
            }
        } else if (strcmp(device, "rgb") == 0) {
            // Can be state ON/OFF (relay ch2) or brightness
            if (doc.containsKey("brightness")) {
                int val = doc["brightness"] | 0;
                hw_setStripBrightness(constrain(val, 0, 255));
                markDirty();
                Serial.printf("[CMD] Phone: rgb brightness → %d\n", val);
            }
            if (doc.containsKey("state")) {
                const char *state = doc["state"];
                if (state) {
                    hw_setRelay(2, strcmp(state, "ON") == 0);
                    markDirty();
                    Serial.printf("[CMD] Phone: rgb relay → %s\n", state);
                }
            }
        } else if (strcmp(device, "backup") == 0) {
            if (doc.containsKey("brightness")) {
                int val = doc["brightness"] | 0;
                hw_setFlashBrightness(constrain(val, 0, 255));
                markDirty();
                Serial.printf("[CMD] Phone: backup brightness → %d\n", val);
            }
        } else if (strcmp(device, "mode") == 0) {
            const char *state = doc["state"];
            if (state) {
                if (strcmp(state, "sleep") == 0 || strcmp(state, "SLEEP") == 0)
                    auto_setMode(MODE_SLEEP);
                else if (strcmp(state, "awake") == 0 || strcmp(state, "AWAKE") == 0)
                    auto_setMode(MODE_AWAKE);
                markDirty();
            }
        }
        return;  // Handled phone app format
    }

    Serial.println("[CMD] Unknown command format");
}

// ═══════════════════════════════════════════════════
//  FreeRTOS sensor task (runs on Core 0)
// ═══════════════════════════════════════════════════
static SemaphoreHandle_t sensorMutex;

// Shared sensor cache (written by sensor task, read by main loop / webserver)
static volatile uint16_t g_smokeAnalog   = 0;
static volatile bool     g_smokeDigital  = false;
static volatile float    g_lux           = 0;
static volatile uint16_t g_proximity     = 0;
// BUG-09: cigarette count cached here under mutex for thread safety
static volatile int      g_cigaretteCount = 0;

// ═══════════════════════════════════════════════════
//  Thread-safe sensor getters (BUG-01/02/03/06 fix)
//  Used by webserver.cpp, automation.cpp, mqtt_client.cpp
// ═══════════════════════════════════════════════════
float sensors_getLux() {
    float v = -1;
    if (xSemaphoreTake(sensorMutex, pdMS_TO_TICKS(5))) {
        v = g_lux;
        xSemaphoreGive(sensorMutex);
    }
    return v;
}

uint16_t sensors_getSmoke() {
    uint16_t v = 0;
    if (xSemaphoreTake(sensorMutex, pdMS_TO_TICKS(5))) {
        v = g_smokeAnalog;
        xSemaphoreGive(sensorMutex);
    }
    return v;
}

bool sensors_getSmokeDO() {
    bool v = false;
    if (xSemaphoreTake(sensorMutex, pdMS_TO_TICKS(5))) {
        v = g_smokeDigital;
        xSemaphoreGive(sensorMutex);
    }
    return v;
}

uint16_t sensors_getProximity() {
    uint16_t v = 0;
    if (xSemaphoreTake(sensorMutex, pdMS_TO_TICKS(5))) {
        v = g_proximity;
        xSemaphoreGive(sensorMutex);
    }
    return v;
}

int sensors_getCigarettes() {
    int v = 0;
    if (xSemaphoreTake(sensorMutex, pdMS_TO_TICKS(5))) {
        v = g_cigaretteCount;
        xSemaphoreGive(sensorMutex);
    }
    return v;
}

// ═══════════════════════════════════════════════════
//  Sensor task function (Core 0)
// ═══════════════════════════════════════════════════
static void sensorTaskFn(void *param) {
    unsigned long lastMq2   = 0;
    unsigned long lastApds  = 0;

    for (;;) {
        unsigned long now = millis();

        // ── MQ2 at 1 Hz ──
        if (now - lastMq2 >= SENSOR_READ_INTERVAL) {
            uint16_t smoke = hw_readSmokeAnalog();
            bool     smokeDO = hw_readSmokeDigital();

            if (xSemaphoreTake(sensorMutex, pdMS_TO_TICKS(10))) {
                g_smokeAnalog  = smoke;
                g_smokeDigital = smokeDO;
                xSemaphoreGive(sensorMutex);
            }

            // Feed the smoke tracker
            smoke_feed(smoke);

            // Update cached cigarette count under mutex (BUG-09 fix)
            if (xSemaphoreTake(sensorMutex, pdMS_TO_TICKS(10))) {
                g_cigaretteCount = smoke_getCigaretteCount();
                xSemaphoreGive(sensorMutex);
            }

            lastMq2 = now;
        }

        // ── APDS-9930 at 2 Hz ──
        if (now - lastApds >= APDS_READ_INTERVAL) {
            float lux = 0;
            uint16_t prox = 0;
            hw_readLux(lux);
            hw_readProximity(prox);

            if (xSemaphoreTake(sensorMutex, pdMS_TO_TICKS(10))) {
                g_lux       = lux;
                g_proximity = prox;
                xSemaphoreGive(sensorMutex);
            }

            lastApds = now;
        }

        vTaskDelay(pdMS_TO_TICKS(50));  // Yield to system tasks
    }
}

// ═══════════════════════════════════════════════════
//  NTP midnight reset for cigarette counter
// ═══════════════════════════════════════════════════
static int _lastResetDay = -1;

static void checkMidnightReset() {
    struct tm ti;
    if (!getLocalTime(&ti, 0)) return;  // NTP not synced yet

    if (_lastResetDay < 0) {
        _lastResetDay = ti.tm_yday;  // First sync — record current day
        return;
    }

    if (ti.tm_yday != _lastResetDay) {
        smoke_resetDaily();
        _lastResetDay = ti.tm_yday;
        markDirty();
        Serial.println("[NTP] Midnight — daily counter reset");
    }
}

// ═══════════════════════════════════════════════════
//  Arduino entry points
// ═══════════════════════════════════════════════════

void setup() {
    Serial.begin(115200);
    delay(500);
    Serial.println("\n═══════════════════════════════════════");
    Serial.println("  Room Control — ESP32 Firmware v2.0");
    Serial.println("═══════════════════════════════════════");

    // ── NVS ──
    prefs.begin("room", false);

    // ── Hardware ──
    hw_init();

    // ── Smoke tracker ──
    smoke_init();

    // ── Restore saved state ──
    restoreState();

    // ── Automation ──
    auto_init();

    // ── Network (WiFi + mDNS + OTA + BLE) ──
    // BUG-10 fix: pass handleCommand so BLE commands are routed
    net_init(handleCommand);

    // ── NTP ──
    configTime(NTP_GMT_OFFSET_SEC, NTP_DST_OFFSET_SEC, NTP_SERVER);
    Serial.println("[NTP] Time sync started");

    // ── Web server + WebSocket ──
    ws_init(handleCommand);

    // ── MQTT ──
    mqtt_init(handleCommand);

    // ── Sensor task on Core 0 ──
    sensorMutex = xSemaphoreCreateMutex();
    xTaskCreatePinnedToCore(
        sensorTaskFn,
        "sensors",
        4096,       // Stack size (bytes)
        NULL,       // Parameter
        1,          // Priority
        NULL,       // Task handle
        0           // Core 0 (network stack also here but OK at low priority)
    );

    // ── Watchdog ──
    esp_task_wdt_init(WDT_TIMEOUT_SEC, true);
    esp_task_wdt_add(NULL);

    // BUG-07 fix: initialise lastNvsWrite to current time to prevent
    // spurious NVS write in the first 5 seconds of boot
    lastNvsWrite = millis();

    Serial.println("[BOOT] Setup complete\n");
}

void loop() {
    unsigned long now = millis();

    // ── Feed watchdog ──
    esp_task_wdt_reset();

    // ── Fade animations (must run every iteration for smoothness) ──
    hw_updateFades();

    // ── Automation engine ──
    auto_update();

    // ── Network housekeeping (OTA + WiFi reconnect) ──
    net_loop();

    // ── MQTT loop ──
    mqtt_loop();

    // ── WebSocket broadcast (every 500 ms) ──
    static unsigned long lastBroadcast = 0;
    if (now - lastBroadcast >= WS_BROADCAST_INTERVAL) {
        ws_broadcastState();
        lastBroadcast = now;
    }

    // ── BLE sensor push (every 2 s — GAP-3) ──
    static unsigned long lastBlePush = 0;
    if (now - lastBlePush >= 2000) {
        if (net_isBleConnected()) {
            net_blePushSensors(sensors_getSmoke(), sensors_getLux(), auto_isPresent());
        }
        lastBlePush = now;
    }

    // ── MQTT sensor + state publish (every 2 s) ──
    static unsigned long lastMqttPub = 0;
    if (now - lastMqttPub >= MQTT_PUBLISH_MS) {
        if (mqtt_isConnected()) {
            mqtt_publishSensors(sensors_getSmoke(), sensors_getLux(), auto_isPresent());
            mqtt_publishState();
        }
        lastMqttPub = now;
    }

    // ── NVS persist (debounced — only after 5 s of no changes) ──
    if (nvsDirty && (now - lastNvsWrite) >= NVS_PERSIST_DEBOUNCE) {
        persistState();
        nvsDirty     = false;
        lastNvsWrite = now;
    }

    // ── Midnight cigarette counter reset ──
    static unsigned long lastMidnightCheck = 0;
    if (now - lastMidnightCheck >= 60000) {  // Check every minute
        checkMidnightReset();
        lastMidnightCheck = now;
    }

    // ── Yield to RTOS (1 ms tick — keeps fade smooth at ~1000 fps) ──
    delay(1);
}


