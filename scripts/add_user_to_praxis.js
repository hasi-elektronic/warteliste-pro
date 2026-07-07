#!/usr/bin/env node
/**
 * Erstellt einen neuen User und weist ihn EINER Praxis als Mitglied zu.
 * Bypass Rules via firebase-CLI OAuth token (Project-Owner).
 *
 * Usage:
 *   node add_user_to_praxis.js <email> <password> <praxisId> <displayName>
 */

const https = require('https');
const fs = require('fs');
const os = require('os');
const path = require('path');

const API_KEY = 'AIzaSyDZZhjrosMl1rQGKc8cOtCLJRGxZR3VwFE';
const PROJECT_ID = 'warteliste-pro';
const CLI_CLIENT_ID = '563584335869-fgrhgmd47bqnekij5i8b5pr03ho849e6.apps.googleusercontent.com';
const CLI_CLIENT_SECRET = 'j9iVZfS8kkCEFUPaAeJV0sAi';

const [email, password, praxisId, displayName] = process.argv.slice(2);
if (!email || !password || !praxisId) {
  console.error('Usage: node add_user_to_praxis.js <email> <password> <praxisId> <displayName>');
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

async function signUpOrIn(email, password) {
  let r = await req('identitytoolkit.googleapis.com',
    `/v1/accounts:signUp?key=${API_KEY}`, 'POST',
    { email, password, returnSecureToken: true });
  if (r.body && r.body.localId) return { uid: r.body.localId, created: true };
  r = await req('identitytoolkit.googleapis.com',
    `/v1/accounts:signInWithPassword?key=${API_KEY}`, 'POST',
    { email, password, returnSecureToken: true });
  if (r.body && r.body.localId) return { uid: r.body.localId, created: false };
  throw new Error('Auth fehlgeschlagen: ' + JSON.stringify(r.body));
}

(async () => {
  console.log('Praxis:', praxisId);
  console.log('User:  ', email);
  console.log('');

  const token = await getAccessToken();

  // Praxis-Existenz pruefen
  const pcheck = await req('firestore.googleapis.com',
    `/v1/projects/${PROJECT_ID}/databases/(default)/documents/praxen/${praxisId}`,
    'GET', null, { 'Authorization': `Bearer ${token}` });
  if (pcheck.status !== 200) throw new Error('Praxis nicht gefunden: ' + praxisId);
  const pname = (pcheck.body.fields.name && pcheck.body.fields.name.stringValue) || '?';
  console.log('✓ Praxis:', pname);

  const { uid, created } = await signUpOrIn(email, password);
  console.log(`✓ User ${created ? 'angelegt' : 'existiert'} — uid:`, uid);

  // /users/{uid} mit user-role + dieser Praxis schreiben
  const body = {
    fields: {
      email: { stringValue: email },
      displayName: { stringValue: displayName || email.split('@')[0] },
      role: { stringValue: 'user' },
      praxisId: { stringValue: praxisId },
      praxisIds: { arrayValue: { values: [{ stringValue: praxisId }] } },
      createdAt: { timestampValue: new Date().toISOString() },
    },
  };
  const w = await req('firestore.googleapis.com',
    `/v1/projects/${PROJECT_ID}/databases/(default)/documents/users/${uid}`,
    'PATCH', body, { 'Authorization': `Bearer ${token}` });
  if (w.status !== 200) throw new Error('User-Doc-Write fehlgeschlagen: ' + JSON.stringify(w.body));
  console.log('✓ users/' + uid + ' geschrieben (role=user, praxisId=' + praxisId + ')');

  console.log('');
  console.log('FERTIG. Login:', email);
})().catch(e => { console.error('FEHLER:', e.message); process.exit(1); });
