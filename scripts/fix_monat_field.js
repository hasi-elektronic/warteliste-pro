#!/usr/bin/env node
/**
 * Korrigiert das `monat` Feld auf YYYY-MM Format (statt Deutsche Monatsnamen).
 * Liest anmeldung-Timestamp und setzt monat = "YYYY-MM".
 *
 *   node fix_monat_field.js          → DRY-RUN
 *   node fix_monat_field.js --apply → wirklich updaten
 */

const https = require('https');
const fs = require('fs');
const os = require('os');
const path = require('path');

const PROJECT_ID = 'warteliste-pro';
const CLI_CLIENT_ID = '563584335869-fgrhgmd47bqnekij5i8b5pr03ho849e6.apps.googleusercontent.com';
const CLI_CLIENT_SECRET = 'j9iVZfS8kkCEFUPaAeJV0sAi';
const APPLY = process.argv.includes('--apply');

const PRAXEN = [
  { id: 'jMlq1h7JQkdDtZo0jqTn', name: 'Weil der Stadt' },
  { id: 'UMVrBwWaWQO7DXRcunxL', name: 'Ditzingen' },
];

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

async function listAllPatients(praxisId, token) {
  const all = [];
  let pageToken = '';
  do {
    const qs = pageToken ? `?pageSize=300&pageToken=${pageToken}` : '?pageSize=300';
    const r = await req('firestore.googleapis.com',
      `/v1/projects/${PROJECT_ID}/databases/(default)/documents/praxen/${praxisId}/patienten${qs}`,
      'GET', null, { 'Authorization': `Bearer ${token}` });
    if (r.body.documents) all.push(...r.body.documents);
    pageToken = r.body.nextPageToken || '';
  } while (pageToken);
  return all;
}

function anmeldungToMonatStr(doc) {
  const ts = doc.fields && doc.fields.anmeldung && doc.fields.anmeldung.timestampValue;
  if (!ts) return null;
  const d = new Date(ts);
  return `${d.getUTCFullYear()}-${String(d.getUTCMonth() + 1).padStart(2, '0')}`;
}

async function updateMonat(praxisId, docId, monatStr, token) {
  const body = { fields: { monat: { stringValue: monatStr } } };
  const mask = 'updateMask.fieldPaths=monat';
  return req('firestore.googleapis.com',
    `/v1/projects/${PROJECT_ID}/databases/(default)/documents/praxen/${praxisId}/patienten/${docId}?${mask}`,
    'PATCH', body, { 'Authorization': `Bearer ${token}` });
}

(async () => {
  console.log(APPLY ? '🛠  APPLY' : '👀 DRY-RUN');
  console.log('');

  const token = await getAccessToken();

  for (const px of PRAXEN) {
    const docs = await listAllPatients(px.id, token);
    console.log(`📍 ${px.name}: ${docs.length} Patienten`);

    let toUpdate = 0, skipped = 0, ok = 0, fail = 0;
    const sampleBefore = [];
    const sampleAfter = [];

    for (const d of docs) {
      const id = d.name.split('/').pop();
      const currentMonat = (d.fields.monat && d.fields.monat.stringValue) || '';
      const newMonat = anmeldungToMonatStr(d);
      if (!newMonat) { skipped++; continue; }
      if (currentMonat === newMonat) { skipped++; continue; }

      if (sampleBefore.length < 5) {
        sampleBefore.push(`${currentMonat} → ${newMonat}`);
      }
      toUpdate++;

      if (APPLY) {
        const r = await updateMonat(px.id, id, newMonat, token);
        if (r.status === 200) ok++;
        else { fail++; if (fail <= 3) console.log(`  ✗ ${id}: ${r.status} ${JSON.stringify(r.body).slice(0,100)}`); }
      }
    }

    console.log(`   zu aendern: ${toUpdate} | bereits ok: ${skipped}`);
    if (sampleBefore.length) console.log('   Beispiele:', sampleBefore.slice(0, 3));
    if (APPLY) console.log(`   ✓ aktualisiert: ${ok} | Fehler: ${fail}`);
    console.log('');
  }

  if (!APPLY) console.log('Wirklich anwenden: node fix_monat_field.js --apply');
})().catch(e => { console.error('FEHLER:', e); process.exit(1); });
