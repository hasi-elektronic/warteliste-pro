#!/usr/bin/env node
/**
 * Vollstaendiges Firestore-Backup.
 *
 * Sichert:
 *   - /users
 *   - /invites
 *   - /praxen + Subcollections (patienten, therapeuten, termine, berichte, tokens)
 *     - /praxen/.../patienten + Subcollections (notizen, dokumente)
 *
 * Output: backups/full_backup_<timestamp>.json
 */

const https = require('https');
const fs = require('fs');
const os = require('os');
const path = require('path');

const PROJECT_ID = 'warteliste-pro';
const CLI_CLIENT_ID = '563584335869-fgrhgmd47bqnekij5i8b5pr03ho849e6.apps.googleusercontent.com';
const CLI_CLIENT_SECRET = 'j9iVZfS8kkCEFUPaAeJV0sAi';

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

function fStr(doc, name) {
  const fld = doc.fields && doc.fields[name];
  return (fld && fld.stringValue) || '';
}

function shortDoc(d) {
  return { id: d.name.split('/').pop(), fields: d.fields };
}

(async () => {
  console.log('📦 Full Firestore Backup');
  console.log('');

  const token = await getAccessToken();

  // Top-level
  const users = await listDocs('users', token);
  const invites = await listDocs('invites', token);
  console.log(`✓ users:    ${users.length}`);
  console.log(`✓ invites:  ${invites.length}`);

  const backup = {
    project: PROJECT_ID,
    createdAt: new Date().toISOString(),
    counts: { users: users.length, invites: invites.length },
    users: users.map(shortDoc),
    invites: invites.map(shortDoc),
    praxen: [],
  };

  const praxen = await listDocs('praxen', token);
  console.log(`✓ praxen:   ${praxen.length}`);
  console.log('');

  let totPat = 0, totNotizen = 0, totDok = 0, totTher = 0, totTerm = 0, totBer = 0, totTok = 0;

  for (const p of praxen) {
    const pid = p.name.split('/').pop();
    const pname = fStr(p, 'name') || '(ohne Name)';

    const [patienten, therapeuten, termine, berichte, tokens] = await Promise.all([
      listDocs(`praxen/${pid}/patienten`, token),
      listDocs(`praxen/${pid}/therapeuten`, token),
      listDocs(`praxen/${pid}/termine`, token),
      listDocs(`praxen/${pid}/berichte`, token),
      listDocs(`praxen/${pid}/tokens`, token),
    ]);

    // Subcollections der Patienten
    const patientenWithSubs = [];
    for (const pat of patienten) {
      const patId = pat.name.split('/').pop();
      const [notizen, dokumente] = await Promise.all([
        listDocs(`praxen/${pid}/patienten/${patId}/notizen`, token),
        listDocs(`praxen/${pid}/patienten/${patId}/dokumente`, token),
      ]);
      totNotizen += notizen.length;
      totDok += dokumente.length;
      patientenWithSubs.push({
        ...shortDoc(pat),
        notizen: notizen.map(shortDoc),
        dokumente: dokumente.map(shortDoc),
      });
    }

    totPat += patienten.length;
    totTher += therapeuten.length;
    totTerm += termine.length;
    totBer += berichte.length;
    totTok += tokens.length;

    console.log(`  📍 ${pname.padEnd(40)} P:${patienten.length}  T:${therapeuten.length}  Trm:${termine.length}  B:${berichte.length}`);

    backup.praxen.push({
      id: pid,
      fields: p.fields,
      patienten: patientenWithSubs,
      therapeuten: therapeuten.map(shortDoc),
      termine: termine.map(shortDoc),
      berichte: berichte.map(shortDoc),
      tokens: tokens.map(shortDoc),
    });
  }

  backup.counts = {
    ...backup.counts,
    praxen: praxen.length,
    patienten: totPat,
    notizen: totNotizen,
    dokumente: totDok,
    therapeuten: totTher,
    termine: totTerm,
    berichte: totBer,
    tokens: totTok,
  };

  const stamp = new Date().toISOString().replace(/[:.]/g, '-');
  const backupDir = path.join(__dirname, '..', 'backups');
  fs.mkdirSync(backupDir, { recursive: true });
  const file = path.join(backupDir, `full_backup_${stamp}.json`);
  fs.writeFileSync(file, JSON.stringify(backup, null, 2));

  const stat = fs.statSync(file);

  console.log('');
  console.log('═══════════════════════════════════════');
  console.log('Backup erstellt:');
  console.log('  ' + file);
  console.log('  Groesse: ' + (stat.size / 1024).toFixed(1) + ' KB');
  console.log('');
  console.log('Inhalte:');
  for (const [k, v] of Object.entries(backup.counts)) {
    console.log(`  ${k.padEnd(12)} ${v}`);
  }
})().catch(e => { console.error('FEHLER:', e); process.exit(1); });
