#!/usr/bin/env node
/**
 * Fuegt einen neuen Super-Admin zu WarteListe Pro hinzu.
 *
 * - Erstellt Firebase Auth User (oder verwendet existierenden)
 * - Schreibt /users/{uid} mit role=admin, praxisIds=[alle Menauer-Praxen]
 *
 * Auth: nutzt firebase-CLI refresh_token aus ~/.config/configstore/firebase-tools.json
 *       fuer OAuth access_token → Firestore REST (bypass rules als Project-Owner).
 *
 * Usage:
 *   node add_super_admin.js <email> <password>
 */

const https = require('https');
const fs = require('fs');
const os = require('os');
const path = require('path');

const API_KEY = 'AIzaSyDZZhjrosMl1rQGKc8cOtCLJRGxZR3VwFE';
const PROJECT_ID = 'warteliste-pro';
const CLI_CLIENT_ID = '563584335869-fgrhgmd47bqnekij5i8b5pr03ho849e6.apps.googleusercontent.com';
const CLI_CLIENT_SECRET = 'j9iVZfS8kkCEFUPaAeJV0sAi';

const email = process.argv[2];
const password = process.argv[3];
if (!email || !password) {
  console.error('Usage: node add_super_admin.js <email> <password>');
  process.exit(1);
}

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
  const refreshToken = cfg.tokens && cfg.tokens.refresh_token;
  if (!refreshToken) throw new Error('Kein refresh_token in firebase-tools.json');

  const params = new URLSearchParams({
    client_id: CLI_CLIENT_ID,
    client_secret: CLI_CLIENT_SECRET,
    refresh_token: refreshToken,
    grant_type: 'refresh_token',
  }).toString();

  const r = await req('oauth2.googleapis.com', '/token', 'POST', params,
    { 'Content-Type': 'application/x-www-form-urlencoded' });
  if (!r.body.access_token) throw new Error('Token-Exchange fehlgeschlagen: ' + JSON.stringify(r.body));
  return r.body.access_token;
}

async function signUpOrIn(email, password) {
  // Versuche signUp
  let r = await req('identitytoolkit.googleapis.com',
    `/v1/accounts:signUp?key=${API_KEY}`, 'POST',
    { email, password, returnSecureToken: true });
  if (r.body && r.body.localId) return { uid: r.body.localId, created: true };

  // Existiert schon: signIn
  r = await req('identitytoolkit.googleapis.com',
    `/v1/accounts:signInWithPassword?key=${API_KEY}`, 'POST',
    { email, password, returnSecureToken: true });
  if (r.body && r.body.localId) return { uid: r.body.localId, created: false };

  throw new Error('Auth fehlgeschlagen: ' + JSON.stringify(r.body));
}

async function listPraxen(token) {
  const r = await req('firestore.googleapis.com',
    `/v1/projects/${PROJECT_ID}/databases/(default)/documents/praxen?pageSize=50`,
    'GET', null, { 'Authorization': `Bearer ${token}` });
  if (!r.body.documents) return [];
  return r.body.documents.map(d => ({
    id: d.name.split('/').pop(),
    name: (d.fields.name && d.fields.name.stringValue) || '(ohne Name)',
  }));
}

async function writeUserDoc(token, uid, email, praxisIds) {
  // PATCH /users/{uid} mit Document-Body — ueberschreibt komplett
  const body = {
    fields: {
      email: { stringValue: email },
      displayName: { stringValue: 'Hamdi Guencavdi (Super-Admin)' },
      role: { stringValue: 'admin' },
      praxisId: { stringValue: praxisIds[0] || '' },
      praxisIds: { arrayValue: { values: praxisIds.map(p => ({ stringValue: p })) } },
      createdAt: { timestampValue: new Date().toISOString() },
    },
  };
  const r = await req('firestore.googleapis.com',
    `/v1/projects/${PROJECT_ID}/databases/(default)/documents/users/${uid}`,
    'PATCH', body, { 'Authorization': `Bearer ${token}` });
  return r;
}

(async () => {
  console.log('1) OAuth access_token holen ...');
  const token = await getAccessToken();
  console.log('   ✓ token ok');

  console.log('2) Praxen auflisten ...');
  const praxen = await listPraxen(token);
  praxen.forEach(p => console.log('   -', p.id, '|', p.name));

  console.log('3) Firebase Auth User anlegen/laden ...');
  const { uid, created } = await signUpOrIn(email, password);
  console.log(`   ${created ? '✓ neu angelegt' : '✓ existiert (signed in)'} — uid:`, uid);

  console.log('4) /users/{uid} mit role=admin schreiben ...');
  const w = await writeUserDoc(token, uid, email, praxen.map(p => p.id));
  if (w.status === 200) {
    console.log('   ✓ User-Doc geschrieben');
  } else {
    console.log('   ✗ Fehler', w.status, JSON.stringify(w.body));
    process.exit(2);
  }

  console.log('');
  console.log('FERTIG. Du kannst dich jetzt mit', email, 'einloggen.');
  console.log('Praxen-Zugriff:', praxen.length);
})().catch(e => { console.error('FEHLER:', e.message || e); process.exit(1); });
