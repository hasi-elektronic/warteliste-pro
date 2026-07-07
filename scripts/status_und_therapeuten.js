#!/usr/bin/env node
/**
 * Status-Check: Patienten + Therapeuten in allen Praxen.
 * Optional: Therapeuten loeschen (+ Backup).
 *
 *   node status_und_therapeuten.js                    → nur Status
 *   node status_und_therapeuten.js --delete-therapeuten → Therapeuten loeschen
 */

const https = require('https');
const fs = require('fs');
const os = require('os');
const path = require('path');

const PROJECT_ID = 'warteliste-pro';
const CLI_CLIENT_ID = '563584335869-fgrhgmd47bqnekij5i8b5pr03ho849e6.apps.googleusercontent.com';
const CLI_CLIENT_SECRET = 'j9iVZfS8kkCEFUPaAeJV0sAi';
const DELETE = process.argv.includes('--delete-therapeuten');

function req(host, p, method, body, headers = {}) {
  return new Promise((resolve, reject) => {
    const data = typeof body === 'string' ? body : (body ? JSON.stringify(body) : '');
    const h = { ...headers };
    if (data && !h['Content-Type']) h['Content-Type'] = 'application/json';
    if (data) h['Content-Length'] = Buffer.byteLength(data);
    const r = https.request({ hostname: host, path: p, method, headers: h }, res => {
      let buf = '';
      res.on('data', c => buf += c);
      res.on('end', () => {
        try { resolve({ status: res.statusCode, body: buf ? JSON.parse(buf) : null }); }
        catch { resolve({ status: res.statusCode, body: buf }); }
      });
    });
    r.on('error', reject);
    if (data) r.write(data);
    r.end();
  });
}

async function getAccessToken() {
  const cfg = JSON.parse(fs.readFileSync(
    path.join(os.homedir(), '.config/configstore/firebase-tools.json'), 'utf8'));
  const params = new URLSearchParams({
    client_id: CLI_CLIENT_ID,
    client_secret: CLI_CLIENT_SECRET,
    refresh_token: cfg.tokens.refresh_token,
    grant_type: 'refresh_token',
  }).toString();
  const r = await req('oauth2.googleapis.com', '/token', 'POST', params,
    { 'Content-Type': 'application/x-www-form-urlencoded' });
  return r.body.access_token;
}

async function listDocs(collectionPath, token) {
  const all = [];
  let pageToken = '';
  do {
    const qs = pageToken ? `?pageSize=300&pageToken=${pageToken}` : '?pageSize=300';
    const r = await req('firestore.googleapis.com',
      `/v1/projects/${PROJECT_ID}/databases/(default)/documents/${collectionPath}${qs}`,
      'GET', null, { 'Authorization': `Bearer ${token}` });
    if (r.body.documents) all.push(...r.body.documents);
    pageToken = r.body.nextPageToken || '';
  } while (pageToken);
  return all;
}

async function deleteDoc(docPath, token) {
  return req('firestore.googleapis.com',
    `/v1/projects/${PROJECT_ID}/databases/(default)/documents/${docPath}`,
    'DELETE', null, { 'Authorization': `Bearer ${token}` });
}

function fStr(doc, name) {
  const fld = doc.fields && doc.fields[name];
  if (!fld) return '';
  return fld.stringValue ?? '';
}

(async () => {
  const token = await getAccessToken();
  const praxen = await listDocs('praxen', token);

  const stamp = new Date().toISOString().replace(/[:.]/g, '-');
  const backupDir = path.join(__dirname, '..', 'backups');
  fs.mkdirSync(backupDir, { recursive: true });

  console.log(DELETE ? '🗑  THERAPEUTEN LOESCHEN' : '👀  STATUS-CHECK');
  console.log('');

  const backup = { project: PROJECT_ID, createdAt: new Date().toISOString(), praxen: [] };
  let totalPat = 0, totalTher = 0;

  for (const p of praxen) {
    const pid = p.name.split('/').pop();
    const pname = fStr(p, 'name') || '(ohne Name)';
    const pats = await listDocs(`praxen/${pid}/patienten`, token);
    const thers = await listDocs(`praxen/${pid}/therapeuten`, token);
    totalPat += pats.length;
    totalTher += thers.length;
    const therNames = thers.map(t => fStr(t, 'name') || fStr(t, 'vorname') + ' ' + fStr(t, 'nachname'));
    console.log(`📍 ${pname.padEnd(38)} P:${String(pats.length).padStart(3)}  T:${String(thers.length).padStart(2)}  ${therNames.join(', ')}`);
    backup.praxen.push({
      praxisId: pid, praxisName: pname,
      therapeuten: thers.map(t => ({ id: t.name.split('/').pop(), fields: t.fields })),
    });
  }

  console.log('');
  console.log(`Gesamt: ${totalPat} Patienten, ${totalTher} Therapeuten`);
  console.log('');

  if (!DELETE) {
    console.log('Therapeuten loeschen: node scripts/status_und_therapeuten.js --delete-therapeuten');
    return;
  }

  const backupFile = path.join(backupDir, `therapeuten_backup_${stamp}.json`);
  fs.writeFileSync(backupFile, JSON.stringify(backup, null, 2));
  console.log(`✓ Backup: ${backupFile}`);
  console.log('');

  let deleted = 0, failed = 0;
  for (const grp of backup.praxen) {
    for (const t of grp.therapeuten) {
      const r = await deleteDoc(`praxen/${grp.praxisId}/therapeuten/${t.id}`, token);
      if (r.status === 200 || r.status === 204) deleted++;
      else { failed++; console.log(`  ✗ ${grp.praxisId}/${t.id}`, r.status); }
    }
    if (grp.therapeuten.length) console.log(`  ✓ ${grp.praxisName}: ${grp.therapeuten.length} Therapeuten geloescht`);
  }

  console.log('');
  console.log(`Geloescht: ${deleted}  |  Fehler: ${failed}`);
})().catch(e => { console.error('FEHLER:', e); process.exit(1); });
