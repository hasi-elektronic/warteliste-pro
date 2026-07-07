#!/usr/bin/env node
/**
 * Aufraeumen nach Invite-Bug (Pre-v1.5.13 Registrierungen):
 *  1. Loescht leere Rogue-/Test-Praxen inkl. aller Subcollections
 *  2. Setzt Staff-User auf role=user und entfernt Rogue-praxisIds
 *
 * Bewusst NICHT angefasst:
 *  - Die 4 echten Menauer-Praxen
 *  - "Enes" Praxis + enes.sivrikaya61 (Play-Store-Tester, eigene Sandbox)
 *  - h.guencavdi + admin@logo-menauer.de (echte Admins)
 *
 *   node cleanup_rogue_praxen.js          → DRY-RUN
 *   node cleanup_rogue_praxen.js --apply  → Backup + ausfuehren
 */

const https = require('https');
const fs = require('fs');
const os = require('os');
const path = require('path');

const PROJECT_ID = 'warteliste-pro';
const CLI_CLIENT_ID = '563584335869-fgrhgmd47bqnekij5i8b5pr03ho849e6.apps.googleusercontent.com';
const CLI_CLIENT_SECRET = 'j9iVZfS8kkCEFUPaAeJV0sAi';
const APPLY = process.argv.includes('--apply');

// Echte Praxen — werden NIE geloescht
const REAL_PRAXEN = new Set([
  'jMlq1h7JQkdDtZo0jqTn', // Weil der Stadt
  'UMVrBwWaWQO7DXRcunxL', // Ditzingen
  'i8UAnl7ZbVVM6MWI38ff', // Vaihingen/Enz
  'NjbKmNjLjj8zASsfKJJt', // Lerntherapie
]);
// Tester-Sandbox — bleibt
const KEEP_PRAXEN = new Set(['2ue1U8Pf5AV3KgHluVBd']); // "Enes"

// User, deren Rolle NICHT angefasst wird
const KEEP_ROLE = new Set([
  'h.guencavdi@hasi-elektronic.de',
  'admin@logo-menauer.de',
  'enes.sivrikaya61@web.de',
]);

const SUBCOLLECTIONS = ['patienten', 'therapeuten', 'termine', 'berichte', 'tokens'];

function req(h, p, m, b, hd = {}) {
  return new Promise((resolve, reject) => {
    const d = typeof b === 'string' ? b : (b ? JSON.stringify(b) : '');
    const hh = { ...hd };
    if (d && !hh['Content-Type']) hh['Content-Type'] = 'application/json';
    if (d) hh['Content-Length'] = Buffer.byteLength(d);
    const r = https.request({ hostname: h, path: p, method: m, headers: hh }, rs => {
      let buf = '';
      rs.on('data', c => buf += c);
      rs.on('end', () => {
        try { resolve({ status: rs.statusCode, body: buf ? JSON.parse(buf) : null }); }
        catch { resolve({ status: rs.statusCode, body: buf }); }
      });
    });
    r.on('error', reject);
    if (d) r.write(d);
    r.end();
  });
}

async function getToken() {
  const cfg = JSON.parse(fs.readFileSync(
    path.join(os.homedir(), '.config/configstore/firebase-tools.json'), 'utf8'));
  const r = await req('oauth2.googleapis.com', '/token', 'POST',
    new URLSearchParams({
      client_id: CLI_CLIENT_ID, client_secret: CLI_CLIENT_SECRET,
      refresh_token: cfg.tokens.refresh_token, grant_type: 'refresh_token',
    }).toString(), { 'Content-Type': 'application/x-www-form-urlencoded' });
  return r.body.access_token;
}

const BASE = `/v1/projects/${PROJECT_ID}/databases/(default)/documents`;

async function listDocs(tok, collPath) {
  const all = [];
  let pageToken = '';
  do {
    const qs = pageToken ? `?pageSize=300&pageToken=${pageToken}` : '?pageSize=300';
    const r = await req('firestore.googleapis.com', `${BASE}/${collPath}${qs}`,
      'GET', null, { Authorization: `Bearer ${tok}` });
    if (r.body.documents) all.push(...r.body.documents);
    pageToken = r.body.nextPageToken || '';
  } while (pageToken);
  return all;
}

async function deleteDoc(tok, docPath) {
  return req('firestore.googleapis.com', `${BASE}/${docPath}`,
    'DELETE', null, { Authorization: `Bearer ${tok}` });
}

function fStr(doc, name) {
  const f = doc.fields && doc.fields[name];
  return (f && f.stringValue) || '';
}

(async () => {
  console.log(APPLY ? '🛠  APPLY-MODUS' : '👀 DRY-RUN');
  console.log('');
  const tok = await getToken();

  // ══ Backup ══
  const praxen = await listDocs(tok, 'praxen');
  const users = await listDocs(tok, 'users');
  if (APPLY) {
    const stamp = new Date().toISOString().replace(/[:.]/g, '-');
    const bdir = path.join(__dirname, '..', 'backups');
    fs.mkdirSync(bdir, { recursive: true });
    const bfile = path.join(bdir, `cleanup_backup_${stamp}.json`);
    fs.writeFileSync(bfile, JSON.stringify({ praxen, users }, null, 2));
    console.log(`✓ Backup: ${bfile}`);
    console.log('');
  }

  // ══ 1) Rogue-Praxen loeschen ══
  console.log('═══ 1) Praxen ═══');
  let deletedPraxen = 0;
  const deletedIds = new Set();
  for (const p of praxen) {
    const id = p.name.split('/').pop();
    if (REAL_PRAXEN.has(id) || KEEP_PRAXEN.has(id)) {
      console.log(`  ✓ behalten: ${fStr(p, 'name')} [${id.slice(0, 8)}…]`);
      continue;
    }
    // Sicherheitscheck: hat sie Patienten? Dann NICHT loeschen.
    const pats = await listDocs(tok, `praxen/${id}/patienten`);
    if (pats.length > 0) {
      console.log(`  ⚠️  UEBERSPRUNGEN (hat ${pats.length} Patienten!): ${fStr(p, 'name')} [${id}]`);
      continue;
    }
    console.log(`  🗑  loeschen: ${fStr(p, 'name')} [${id.slice(0, 8)}…]`);
    deletedIds.add(id);
    if (!APPLY) continue;
    // Subcollections zuerst
    for (const sub of SUBCOLLECTIONS) {
      const docs = await listDocs(tok, `praxen/${id}/${sub}`);
      for (const d of docs) {
        const did = d.name.split('/').pop();
        await deleteDoc(tok, `praxen/${id}/${sub}/${did}`);
      }
      if (docs.length) console.log(`      ${sub}: ${docs.length} Sub-Docs geloescht`);
    }
    const r = await deleteDoc(tok, `praxen/${id}`);
    if (r.status === 200 || r.status === 204) deletedPraxen++;
    else console.log(`      ✗ Fehler ${r.status}`);
  }
  console.log('');

  // ══ 2) User bereinigen ══
  console.log('═══ 2) Users ═══');
  let fixedUsers = 0;
  for (const u of users) {
    const uid = u.name.split('/').pop();
    const email = fStr(u, 'email');
    const role = fStr(u, 'role');
    const primary = fStr(u, 'praxisId');
    const pids = ((u.fields.praxisIds || {}).arrayValue?.values || [])
      .map(v => v.stringValue);

    if (KEEP_ROLE.has(email)) {
      console.log(`  ✓ unveraendert: ${email}`);
      continue;
    }

    // Bereinigte Praxen-Liste: nur echte Menauer-Praxen
    const cleaned = pids.filter(p => REAL_PRAXEN.has(p));
    const newPrimary = REAL_PRAXEN.has(primary) ? primary : (cleaned[0] || '');
    const needsRole = role !== 'user';
    const needsPids = cleaned.length !== pids.length;
    const needsPrimary = newPrimary !== primary;

    if (!needsRole && !needsPids && !needsPrimary) {
      console.log(`  ✓ ok: ${email}`);
      continue;
    }
    if (cleaned.length === 0) {
      console.log(`  ⚠️  ${email}: KEINE echte Praxis uebrig — nicht angefasst (manuell klaeren)`);
      continue;
    }

    console.log(`  🛠  ${email}: role ${role}→user | praxen ${pids.length}→${cleaned.length}${needsPrimary ? ' | primary→' + newPrimary.slice(0, 8) + '…' : ''}`);
    fixedUsers++;
    if (!APPLY) continue;

    const body = {
      fields: {
        role: { stringValue: 'user' },
        praxisId: { stringValue: newPrimary },
        praxisIds: { arrayValue: { values: cleaned.map(p => ({ stringValue: p })) } },
      },
    };
    const mask = 'updateMask.fieldPaths=role&updateMask.fieldPaths=praxisId&updateMask.fieldPaths=praxisIds';
    const r = await req('firestore.googleapis.com', `${BASE}/users/${uid}?${mask}`,
      'PATCH', body, { Authorization: `Bearer ${tok}` });
    if (r.status !== 200) console.log(`      ✗ Fehler ${r.status}: ${JSON.stringify(r.body).slice(0, 120)}`);
  }

  console.log('');
  console.log('═══════════════════════════════');
  console.log(`Praxen ${APPLY ? 'geloescht' : 'zu loeschen'}: ${APPLY ? deletedPraxen : deletedIds.size}`);
  console.log(`Users ${APPLY ? 'korrigiert' : 'zu korrigieren'}:  ${fixedUsers}`);
  if (!APPLY) console.log('\nAusfuehren: node cleanup_rogue_praxen.js --apply');
})().catch(e => { console.error('FEHLER:', e); process.exit(1); });
