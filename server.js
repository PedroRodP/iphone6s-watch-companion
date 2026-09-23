const express = require('express');
const http = require('http');
const WebSocket = require('ws');
const Database = require('better-sqlite3');
const path = require('path');
const os = require('os');
const fs = require('fs');

const PORT = 3001;
const POLL_INTERVAL_MS = 1000;
const NOTIF_DB = path.join(
  os.homedir(),
  'AppData', 'Local', 'Microsoft', 'Windows', 'Notifications', 'wpndatabase.db'
);

const app = express();
const server = http.createServer(app);
const wss = new WebSocket.Server({ server });
app.use(express.static(path.join(__dirname, 'public')));

// ── State ─────────────────────────────────────────────────────────────────────
let lastSeenId = 0;
let db = null;
let dbAccessError = false;

// ── DB ────────────────────────────────────────────────────────────────────────

function openDB() {
  try {
    return new Database(NOTIF_DB, { readonly: true, fileMustExist: true });
  } catch (_) {
    // Fallback: copy to temp and open the copy (handles exclusive lock scenarios)
    const tmp = path.join(os.tmpdir(), 'wa_notif_tmp.db');
    fs.copyFileSync(NOTIF_DB, tmp);
    return new Database(tmp, { readonly: true });
  }
}

function initDB() {
  try {
    db = openDB();

    // AGENT NOTE: if no WhatsApp notifications are detected, run the debug
    // query below to find the correct PrimaryId filter for this machine:
    //   SELECT DISTINCT h.PrimaryId FROM NotificationHandler h
    //   JOIN Notification n ON n.HandlerId = h.RecordId LIMIT 50;
    const row = db.prepare(
      `SELECT MAX(n.Id) as maxId FROM Notification n
       JOIN NotificationHandler h ON n.HandlerId = h.RecordId
       WHERE h.PrimaryId LIKE '%WhatsApp%' OR h.PrimaryId LIKE '%5319275A%'`
    ).get();

    lastSeenId = row?.maxId ?? 0;
    dbAccessError = false;
    console.log(`[notif] DB opened. Starting from Id > ${lastSeenId}`);
  } catch (err) {
    dbAccessError = true;
    console.error('[notif] Cannot open notification DB:', err.message);
    console.error('        Path:', NOTIF_DB);
    console.error('        Make sure WhatsApp Desktop has been opened at least once.');
  }
}

// ── Parsers ───────────────────────────────────────────────────────────────────

// Windows FILETIME: 100ns intervals since 1601-01-01
function windowsTimeToUnixMs(wt) {
  try {
    return Number(BigInt(wt) / 10000n) - 11644473600000;
  } catch (_) {
    return Date.now();
  }
}

// WhatsApp Desktop draws its own popup and never calls the native Windows toast
// API — it only pushes badge count updates (<badge value="N"/>), so the message
// sender/text is never available to us. We just track the unread count.
function parseBadgeCount(xml) {
  if (!xml) return null;
  const match = /<badge\s+value="(\d+)"/.exec(xml);
  return match ? parseInt(match[1], 10) : null;
}

// ── Polling ───────────────────────────────────────────────────────────────────

function pollNotifications() {
  if (!db || dbAccessError) return;
  try {
    const rows = db.prepare(
      `SELECT n.Id, n.ArrivalTime, n.Payload
       FROM Notification n
       JOIN NotificationHandler h ON n.HandlerId = h.RecordId
       WHERE (h.PrimaryId LIKE '%WhatsApp%' OR h.PrimaryId LIKE '%5319275A%')
         AND n.Id > ?
       ORDER BY n.Id ASC
       LIMIT 20`
    ).all(lastSeenId);

    for (const row of rows) {
      if (row.Id > lastSeenId) lastSeenId = row.Id;
      const count = parseBadgeCount(row.Payload);
      if (!count) continue; // badge cleared (value=0) or unparseable — not a new message
      const timestamp = windowsTimeToUnixMs(row.ArrivalTime);
      console.log(`[notif] WhatsApp unread count → ${count}`);
      broadcastNotification({ count, timestamp });
    }
  } catch (err) {
    console.error('[notif] Poll error:', err.message);
  }
}

function broadcastNotification(notif) {
  const payload = JSON.stringify({ type: 'whatsapp_notification', ...notif });
  wss.clients.forEach(c => { if (c.readyState === WebSocket.OPEN) c.send(payload); });
}

function broadcastShutdown() {
  const payload = JSON.stringify({ type: 'server_shutdown' });
  wss.clients.forEach(c => { if (c.readyState === WebSocket.OPEN) c.send(payload); });
}

// ── HTTP endpoints ────────────────────────────────────────────────────────────

// Fire a test notification to verify the client is working
app.get('/test', (_req, res) => {
  broadcastNotification({
    count:     1,
    timestamp: Date.now(),
  });
  res.json({ ok: true });
});

// Diagnostic info — useful when the DB filter needs to be adjusted
app.get('/status', (_req, res) => {
  res.json({
    dbPath:           NOTIF_DB,
    dbExists:         fs.existsSync(NOTIF_DB),
    dbAccessError,
    lastSeenId,
    connectedClients: wss.clients.size,
  });
});

// ── WebSocket ─────────────────────────────────────────────────────────────────

wss.on('connection', ws => {
  console.log('[ws] client connected  — total:', wss.clients.size);
  ws.on('close', () => console.log('[ws] client disconnected — total:', wss.clients.size));
});

setInterval(pollNotifications, POLL_INTERVAL_MS);

// ── Start ─────────────────────────────────────────────────────────────────────

function getLocalIP() {
  const ifaces = os.networkInterfaces();
  for (const name of Object.keys(ifaces)) {
    for (const iface of ifaces[name]) {
      if (iface.family === 'IPv4' && !iface.internal) return iface.address;
    }
  }
  return 'localhost';
}

initDB();

server.listen(PORT, '0.0.0.0', () => {
  const ip = getLocalIP();
  console.log('');
  console.log('  WHATSAPP WATCH COMPANION');
  console.log('  ──────────────────────────────────────────');
  console.log(`  Local   → http://localhost:${PORT}`);
  console.log(`  Network → http://${ip}:${PORT}   ← abrir en iPhone`);
  console.log('  ──────────────────────────────────────────');
  console.log('');
  console.log('  Test:   curl http://localhost:' + PORT + '/test');
  console.log('  Status: curl http://localhost:' + PORT + '/status');
  console.log('');
  console.log('  Watching for WhatsApp notifications...');
  console.log('');
});

// ── Graceful shutdown ────────────────────────────────────────────────────────
// Lets connected iPhones know the server is going away on purpose, so they can
// release NoSleep and let the screen lock instead of staying awake forever on
// a dead connection. A plain WebSocket disconnect (wifi hiccup, screen lock)
// must NOT trigger this — only an explicit server shutdown does.
let shuttingDown = false;

function shutdown(signal) {
  if (shuttingDown) return;
  shuttingDown = true;
  console.log(`\n[server] ${signal} received — notifying clients and shutting down...`);
  broadcastShutdown();

  // Give the WebSocket frame a moment to actually reach the client before we
  // tear down the sockets that would carry it.
  setTimeout(() => {
    wss.close();
    if (db) db.close();
    server.close(() => process.exit(0));
    setTimeout(() => process.exit(0), 1000); // fallback if close() hangs
  }, 200);
}

process.on('SIGINT', () => shutdown('SIGINT'));
process.on('SIGTERM', () => shutdown('SIGTERM'));
process.on('SIGBREAK', () => shutdown('SIGBREAK')); // Windows Ctrl+Break
process.on('SIGHUP', () => shutdown('SIGHUP'));      // Windows console closed
