/**
 * WarteListe Pro — Nightly Firestore Backup Worker
 * ================================================
 * Dumpt taeglich (03:15 UTC) die komplette Firestore-Datenbank als
 * eine JSON-Datei nach R2 (warteliste-pro-docs/backups/firestore/).
 * Alte Backups aelter als RETENTION_DAYS werden geloescht.
 *
 * Auth zu Firestore: Service-Account (firebase-adminsdk) JWT → OAuth
 * Access Token → Firestore REST runQuery/list.
 *
 * Endpunkte:
 *   (cron)              → automatischer Nightly-Dump
 *   GET /run?token=XXX  → manueller Trigger (MANUAL_TRIGGER_TOKEN)
 *   GET /health         → { ok:true }
 *
 * Secrets (via `wrangler secret put`):
 *   SA_CLIENT_EMAIL, SA_PRIVATE_KEY, MANUAL_TRIGGER_TOKEN
 */

// ---- kleine PEM → ArrayBuffer Hilfe fuer RS256 JWT-Signatur ----
function pemToArrayBuffer(pem) {
  const b64 = pem
    .replace(/-----BEGIN PRIVATE KEY-----/, '')
    .replace(/-----END PRIVATE KEY-----/, '')
    .replace(/\s+/g, '');
  const bin = atob(b64);
  const buf = new Uint8Array(bin.length);
  for (let i = 0; i < bin.length; i++) buf[i] = bin.charCodeAt(i);
  return buf.buffer;
}

function b64url(bytes) {
  let bin = '';
  const arr = new Uint8Array(bytes);
  for (let i = 0; i < arr.length; i++) bin += String.fromCharCode(arr[i]);
  return btoa(bin).replace(/\+/g, '-').replace(/\//g, '_').replace(/=+$/, '');
}

function b64urlStr(str) {
  return b64url(new TextEncoder().encode(str));
}

// ---- Service-Account JWT → OAuth Access Token ----
async function getAccessToken(env) {
  const now = Math.floor(Date.now() / 1000);
  const header = { alg: 'RS256', typ: 'JWT' };
  const claim = {
    iss: env.SA_CLIENT_EMAIL,
    scope: 'https://www.googleapis.com/auth/datastore',
    aud: 'https://oauth2.googleapis.com/token',
    iat: now,
    exp: now + 3600,
  };
  const unsigned = `${b64urlStr(JSON.stringify(header))}.${b64urlStr(JSON.stringify(claim))}`;

  // Private Key kann mit \n-escapes im Secret liegen — normalisieren.
  const pem = (env.SA_PRIVATE_KEY || '').replace(/\\n/g, '\n');
  const key = await crypto.subtle.importKey(
    'pkcs8',
    pemToArrayBuffer(pem),
    { name: 'RSASSA-PKCS1-v1_5', hash: 'SHA-256' },
    false,
    ['sign']
  );
  const sig = await crypto.subtle.sign(
    'RSASSA-PKCS1-v1_5',
    key,
    new TextEncoder().encode(unsigned)
  );
  const jwt = `${unsigned}.${b64url(sig)}`;

  const res = await fetch('https://oauth2.googleapis.com/token', {
    method: 'POST',
    headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
    body: new URLSearchParams({
      grant_type: 'urn:ietf:params:oauth:grant-type:jwt-bearer',
      assertion: jwt,
    }),
  });
  const data = await res.json();
  if (!data.access_token) throw new Error('Token exchange failed: ' + JSON.stringify(data).slice(0, 200));
  return data.access_token;
}

// ---- Firestore REST Helpers ----
const FS_HOST = 'https://firestore.googleapis.com';

async function listDocuments(env, token, collectionPath) {
  const base = `${FS_HOST}/v1/projects/${env.FIREBASE_PROJECT_ID}/databases/(default)/documents/${collectionPath}`;
  const all = [];
  let pageToken = '';
  do {
    const url = `${base}?pageSize=300${pageToken ? `&pageToken=${encodeURIComponent(pageToken)}` : ''}`;
    const r = await fetch(url, { headers: { Authorization: `Bearer ${token}` } });
    if (!r.ok) {
      if (r.status === 404) break; // Collection existiert nicht (leer)
      throw new Error(`Firestore list ${collectionPath}: ${r.status}`);
    }
    const data = await r.json();
    if (data.documents) all.push(...data.documents);
    pageToken = data.nextPageToken || '';
  } while (pageToken);
  return all;
}

// ---- Kompletter Dump ----
async function buildDump(env, token) {
  const dump = {
    project: env.FIREBASE_PROJECT_ID,
    createdAt: new Date().toISOString(),
    collections: {},
  };

  // Top-level
  dump.collections.users = await listDocuments(env, token, 'users');
  dump.collections.invites = await listDocuments(env, token, 'invites');

  // Praxen + alle Subcollections
  const praxen = await listDocuments(env, token, 'praxen');
  dump.collections.praxen = [];

  const SUBS = ['patienten', 'therapeuten', 'termine', 'berichte', 'tokens'];
  const PATIENT_SUBS = ['notizen', 'dokumente'];

  for (const p of praxen) {
    const pid = p.name.split('/').pop();
    const entry = { id: pid, fields: p.fields, sub: {} };

    for (const sub of SUBS) {
      entry.sub[sub] = await listDocuments(env, token, `praxen/${pid}/${sub}`);
    }
    // Patienten-Subcollections (Notizen, Dokumente)
    for (const pat of entry.sub.patienten) {
      const patId = pat.name.split('/').pop();
      pat._sub = {};
      for (const ps of PATIENT_SUBS) {
        pat._sub[ps] = await listDocuments(env, token, `praxen/${pid}/patienten/${patId}/${ps}`);
      }
    }
    dump.collections.praxen.push(entry);
  }

  // Kurz-Statistik in den Dump schreiben
  dump.stats = {
    users: dump.collections.users.length,
    invites: dump.collections.invites.length,
    praxen: dump.collections.praxen.length,
    patienten: dump.collections.praxen.reduce((n, x) => n + (x.sub.patienten?.length || 0), 0),
    berichte: dump.collections.praxen.reduce((n, x) => n + (x.sub.berichte?.length || 0), 0),
  };
  return dump;
}

// ---- Alte Backups aufraeumen ----
async function pruneOld(env) {
  const retentionMs = parseInt(env.RETENTION_DAYS || '30', 10) * 86400 * 1000;
  const cutoff = Date.now() - retentionMs;
  const listed = await env.BUCKET.list({ prefix: env.BACKUP_PREFIX + '/' });
  let deleted = 0;
  for (const obj of listed.objects || []) {
    // Dateiname: backups/firestore/2026-07-08T03-15-00.json — uploaded-Zeit nutzen
    if (obj.uploaded && obj.uploaded.getTime() < cutoff) {
      await env.BUCKET.delete(obj.key);
      deleted++;
    }
  }
  return deleted;
}

async function runBackup(env) {
  const started = Date.now();
  const token = await getAccessToken(env);
  const dump = await buildDump(env, token);
  const stamp = new Date().toISOString().replace(/[:.]/g, '-').replace('Z', '');
  const key = `${env.BACKUP_PREFIX}/${stamp}.json`;
  const body = JSON.stringify(dump);

  await env.BUCKET.put(key, body, {
    httpMetadata: { contentType: 'application/json' },
    customMetadata: {
      users: String(dump.stats.users),
      praxen: String(dump.stats.praxen),
      patienten: String(dump.stats.patienten),
    },
  });
  const pruned = await pruneOld(env);

  return {
    ok: true,
    key,
    sizeBytes: body.length,
    stats: dump.stats,
    prunedOld: pruned,
    tookMs: Date.now() - started,
  };
}

export default {
  // Automatischer naechtlicher Lauf
  async scheduled(_event, env, ctx) {
    ctx.waitUntil(
      runBackup(env).then(
        (res) => console.log('Backup OK:', JSON.stringify(res)),
        (err) => console.error('Backup FAILED:', err && err.message)
      )
    );
  },

  // Manueller Trigger + Health
  async fetch(request, env) {
    const url = new URL(request.url);

    if (url.pathname === '/health') {
      return Response.json({ ok: true, service: 'warteliste-pro-backup' });
    }

    if (url.pathname === '/run') {
      const token = url.searchParams.get('token');
      if (!env.MANUAL_TRIGGER_TOKEN || token !== env.MANUAL_TRIGGER_TOKEN) {
        return new Response('Unauthorized', { status: 401 });
      }
      try {
        const res = await runBackup(env);
        return Response.json(res);
      } catch (e) {
        return Response.json({ ok: false, error: e.message }, { status: 500 });
      }
    }

    return new Response('WarteListe Pro Backup Worker', { status: 200 });
  },
};
