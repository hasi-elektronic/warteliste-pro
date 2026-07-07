#!/usr/bin/env node
/**
 * Cleanup: Test-Patienten in allen Praxen finden + loeschen.
 *
 * Match: vorname ODER nachname enthaelt "hamdi" oder "test" (case-insensitive).
 *
 * Auth: OAuth via firebase-CLI refresh_token (Project-Owner → bypass rules).
 *
 *   node cleanup_test_patients.js          → DRY-RUN
 *   node cleanup_test_patients.js --delete → wirklich loeschen
 */

const https = require('https');
const fs = require('fs');
const os = require('os');
const path = require('path');

const PROJECT_ID = 'warteliste-pro';
const CLI_CLIENT_ID = '563584335869-fgrhgmd47bqnekij5i8b5pr03ho849e6.apps.googleusercontent.com';
const CLI_CLIENT_SECRET = 'j9iVZfS8kkCEFUPaAeJV0sAi';
const DELETE = process.argv.includes('--delete');

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
  const refreshToken = cfg.tokens.refresh_token;
  const params = new URLSearchParams({
    client_id: CLI_CLIENT_ID,
    client_secret: CLI_CLIENT_SECRET,
    refresh_token: refreshToken,
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

function f(doc, name) {
  const fld = doc.fields && doc.fields[name];
  if (!fld) return '';
  return fld.stringValue ?? fld.integerValue ?? fld.booleanValue ?? '';
}

function matches(name) {
  const n = (name || '').toLowerCase();
  return n.includes('hamdi') || n.includes('test');
}

(async () => {
  console.log(DELETE ? '🗑  DELETE-MODUS' : '👀  DRY-RUN');
  console.log('');

  const token = await getAccessToken();
  const praxen = await listDocs('praxen', token);
  console.log(`Praxen: ${praxen.length}`);
  console.log('');

  let totalMatches = 0, totalDeleted = 0;

  for (const p of praxen) {
    const pid = p.name.split('/').pop();
    const pname = f(p, 'name') || '(ohne Name)';
    const pats = await listDocs(`praxen/${pid}/patienten`, token);
    const hits = pats.filter(pat => matches(f(pat, 'vorname')) || matches(f(pat, 'nachname')));

    console.log(`📍 ${pname}  [${pid}]`);
    console.log(`   Gesamt: ${pats.length} | Treffer: ${hits.length}`);

    for (const h of hits) {
      const id = h.name.split('/').pop();
      const v = f(h, 'vorname'), n = f(h, 'nachname');
      console.log(`   - "${v} ${n}"  ${id}`);
      totalMatches++;
      if (DELETE) {
        const r = await deleteDoc(`praxen/${pid}/patienten/${id}`, token);
        if (r.status === 200 || r.status === 204) { totalDeleted++; console.log('     ✓ geloescht'); }
        else console.log('     ✗', r.status, JSON.stringify(r.body));
      }
    }
    console.log('');
  }

  console.log('═══════════════════════════════════════');
  console.log(`Treffer:    ${totalMatches}`);
  if (DELETE) console.log(`Geloescht:  ${totalDeleted}`);
  else console.log(`Loeschen mit: node cleanup_test_patients.js --delete`);
})().catch(e => { console.error('FEHLER:', e); process.exit(1); });
