#!/usr/bin/env node
/**
 * Import: Logo Menauer - Ditzingen - Wartelisten 2025 + 2026
 *   nach Firestore /praxen/{DITZ_PRAXIS_ID}/patienten
 *
 * Quelle: /tmp/ditz_25.xls und /tmp/ditz_26.xls (entschluesselte Kopien).
 *
 * Spalten (Header in r6):
 *   Datum | Ang. | Th. | 1.Termin | Nachname | Vorname | Adresse |
 *   Telefon | Arzt | KK | Anmeldegrund | Termine | sonstige Angaben
 *
 *   node import_ditzingen.js          → DRY-RUN
 *   node import_ditzingen.js --import → schreiben
 */

const https = require('https');
const fs = require('fs');
const os = require('os');
const path = require('path');
const XLSX = require('xlsx');

const PROJECT_ID = 'warteliste-pro';
const PRAXIS_ID = 'UMVrBwWaWQO7DXRcunxL'; // Ditzingen
const CLI_CLIENT_ID = '563584335869-fgrhgmd47bqnekij5i8b5pr03ho849e6.apps.googleusercontent.com';
const CLI_CLIENT_SECRET = 'j9iVZfS8kkCEFUPaAeJV0sAi';
const DO_IMPORT = process.argv.includes('--import');

const FILES = ['/tmp/ditz_24.xls'];

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

const MONATE_DE = ['Januar','Februar','März','April','Mai','Juni',
                   'Juli','August','September','Oktober','November','Dezember'];

function excelDateToJs(serial) {
  if (typeof serial !== 'number') return null;
  return new Date(Math.round((serial - 25569) * 86400 * 1000));
}

function parseDate(v) {
  if (v == null || v === '') return null;
  if (v instanceof Date) return v;
  if (typeof v === 'number') {
    // Could be Excel serial or a phone number — but only call for date columns
    if (v > 30000 && v < 60000) return excelDateToJs(v);
    return null;
  }
  const s = String(v).trim();
  if (!s) return null;
  let m = s.match(/^(\d{4})-(\d{1,2})-(\d{1,2})/);
  if (m) return new Date(+m[1], +m[2]-1, +m[3]);
  m = s.match(/^(\d{1,2})\.(\d{1,2})\.(\d{2,4})/);
  if (m) {
    let y = +m[3]; if (y < 100) y += 2000;
    return new Date(y, +m[2]-1, +m[1]);
  }
  return null;
}

function normalizeVersicherung(raw) {
  const s = (raw || '').toString().trim().toLowerCase();
  if (!s) return 'KK';
  if (s.startsWith('priv')) return 'Privat';
  if (s.includes('jugendamt')) return 'Jugendamt';
  if (s.includes('aok') || s.includes('barmer') || s.includes('tk') ||
      s.includes('dak') || s.includes('ikk') || s.includes('kasse') ||
      s === 'kk' || s === 'gkv') return 'KK';
  return 'Sonstiges';
}

function germanMonth(d) { return MONATE_DE[d.getMonth()]; }

function parseAllSheets(file) {
  const wb = XLSX.readFile(file, { cellDates: false });
  const out = [];
  for (const sheetName of wb.SheetNames) {
    if (/fazit/i.test(sheetName)) continue;
    const ws = wb.Sheets[sheetName];
    const aoa = XLSX.utils.sheet_to_json(ws, { header: 1, defval: '', raw: true });

    // Header-Zeile finden (enthaelt 'datum'/'nachname'/'vorname')
    let hdrIdx = -1;
    for (let r = 0; r < Math.min(aoa.length, 15); r++) {
      const joined = aoa[r].map(c => String(c || '').toLowerCase()).join('|');
      if (joined.includes('datum') && joined.includes('nachname') && joined.includes('vorname')) { hdrIdx = r; break; }
    }
    if (hdrIdx < 0) continue;
    const header = aoa[hdrIdx].map(h => String(h || '').replace(/\s+/g,' ').trim().toLowerCase());
    const idx = {
      datum:     header.findIndex(h => h === 'datum'),
      ang:       header.findIndex(h => h === 'ang.' || h === 'ang'),
      th:        header.findIndex(h => h === 'th.' || h === 'th'),
      termin1:   header.findIndex(h => h.startsWith('1.') || h.includes('1. termin')),
      nachname:  header.findIndex(h => h === 'nachname'),
      vorname:   header.findIndex(h => h === 'vorname'),
      adresse:   header.findIndex(h => h === 'adresse'),
      telefon:   header.findIndex(h => h.startsWith('telefon')),
      arzt:      header.findIndex(h => h === 'arzt'),
      kk:        header.findIndex(h => h === 'kk'),
      grund:     header.findIndex(h => h.includes('anmelde')),
      termine:   header.findIndex(h => h === 'termine'),
      sonstige:  header.findIndex(h => h.includes('sonstige') || h.includes('angabe')),
    };

    for (let r = hdrIdx + 1; r < aoa.length; r++) {
      const row = aoa[r];
      const get = (k) => idx[k] >= 0 ? row[idx[k]] : '';
      const nachname = String(get('nachname') || '').trim();
      const vorname = String(get('vorname') || '').trim();
      if (!nachname && !vorname) continue;
      // Skip Metadaten-Zeilen mit reinen Zahlen
      const isNumeric = (s) => s && /^[\d.,\s]+$/.test(s);
      if (isNumeric(vorname) && isNumeric(nachname)) continue;
      if (!nachname && isNumeric(vorname)) continue;
      if (!vorname && isNumeric(nachname)) continue;

      const anmeldung = parseDate(get('datum')) || new Date();
      const termin1 = parseDate(get('termin1'));
      const thVal = String(get('th') || '').trim();
      const angVal = String(get('ang') || '').trim();

      // Status-Mapping
      let status = 'wartend';
      const notes = [];
      if (termin1) { status = 'inBehandlung'; notes.push('1. Termin: ' + termin1.toISOString().slice(0,10)); }
      else if (thVal) { status = 'platzGefunden'; notes.push('Therapeut: ' + thVal); }
      if (angVal && angVal !== thVal) notes.push('Angemeldet von: ' + angVal);

      const sonstigeRaw = String(get('sonstige') || '').trim();
      // Manchmal Telefon mehrere Nummern → bleibt String
      const telefonRaw = get('telefon');
      let telefon = '';
      if (typeof telefonRaw === 'number') telefon = String(telefonRaw);
      else telefon = String(telefonRaw || '').trim();

      out.push({
        anmeldung,
        name: nachname,
        vorname,
        adresse: String(get('adresse') || '').trim(),
        telefon,
        versicherung: normalizeVersicherung(get('kk')),
        arzt: String(get('arzt') || '').trim(),
        stoerungsbild: String(get('grund') || '').trim(),
        terminWunsch: String(get('termine') || '').trim(),
        weitereInfos: [notes.join(' | '), sonstigeRaw].filter(Boolean).join(' | '),
        geburtsdatum: null, // Ditzingen-Schema hat kein Geburtsdatum
        status,
        monat: germanMonth(anmeldung),
        sourceSheet: sheetName,
        sourceFile: path.basename(file),
      });
    }
  }
  return out;
}

function tsField(d) { return { timestampValue: d.toISOString() }; }
function strField(s) { return { stringValue: s || '' }; }
function nullField() { return { nullValue: null }; }

function patientToFirestoreDoc(p) {
  const lowerInfo = (p.weitereInfos || '').toLowerCase();
  return {
    fields: {
      anmeldung: tsField(p.anmeldung),
      name: strField(p.name),
      vorname: strField(p.vorname),
      adresse: strField(p.adresse),
      telefon: strField(p.telefon),
      versicherung: strField(p.versicherung),
      arzt: strField(p.arzt),
      stoerungsbild: strField(p.stoerungsbild),
      terminWunsch: strField(p.terminWunsch),
      weitereInfos: strField(p.weitereInfos),
      geburtsdatum: nullField(),
      status: strField(p.status),
      therapeutId: nullField(),
      platzGefundenAm: nullField(),
      monat: strField(p.monat),
      praxisId: strField(PRAXIS_ID),
      rezeptDatum: nullField(),
      rezeptGueltigBis: nullField(),
      verordnungsMenge: nullField(),
      letzterKontakt: nullField(),
      prioritaet: strField('normal'),
      hausbesuch: { booleanValue: /hausbesuch|\bhb\b/.test(lowerInfo) },
      kkSonstiges: strField(''),
    },
  };
}

async function writePatient(token, doc) {
  return req('firestore.googleapis.com',
    `/v1/projects/${PROJECT_ID}/databases/(default)/documents/praxen/${PRAXIS_ID}/patienten`,
    'POST', doc, { 'Authorization': `Bearer ${token}` });
}

(async () => {
  console.log(DO_IMPORT ? '📥 IMPORT' : '👀 DRY-RUN');
  console.log('Ziel: Ditzingen  [' + PRAXIS_ID + ']');
  console.log('');

  let all = [];
  for (const f of FILES) {
    const rows = parseAllSheets(f);
    console.log(`📄 ${path.basename(f)}: ${rows.length} Eintraege`);
    all = all.concat(rows);
  }
  console.log('');
  console.log(`Gesamt: ${all.length}`);
  console.log('');

  console.log('Stichproben:');
  for (let i = 0; i < Math.min(10, all.length); i++) {
    const p = all[Math.floor(i * all.length / 10)];
    console.log(`  ${p.anmeldung.toISOString().slice(0,10)} | ${p.vorname} ${p.name} | ${p.versicherung} | ${p.stoerungsbild} | ${p.status}`);
  }
  console.log('');

  const stats = { wartend:0, platzGefunden:0, inBehandlung:0, abgeschlossen:0 };
  const vers = { KK:0, Privat:0, Jugendamt:0, Sonstiges:0 };
  for (const p of all) { stats[p.status]++; vers[p.versicherung]++; }
  console.log('Status :', stats);
  console.log('Vers.  :', vers);
  console.log('');

  if (!DO_IMPORT) {
    console.log('Import ausfuehren: node import_ditzingen.js --import');
    return;
  }

  const stamp = new Date().toISOString().replace(/[:.]/g, '-');
  const bdir = path.join(__dirname, '..', 'backups');
  fs.mkdirSync(bdir, { recursive: true });
  const bfile = path.join(bdir, `import_ditz_${stamp}.json`);
  fs.writeFileSync(bfile, JSON.stringify(all, null, 2));
  console.log(`✓ Parse-Backup: ${bfile}`);

  const token = await getAccessToken();
  console.log('Schreibe ...');
  let ok = 0, fail = 0;
  for (let i = 0; i < all.length; i++) {
    const r = await writePatient(token, patientToFirestoreDoc(all[i]));
    if (r.status === 200) ok++;
    else { fail++; console.log(`  ✗ ${i}: ${all[i].vorname} ${all[i].name} — ${r.status}`); }
    if ((i+1) % 25 === 0) console.log(`  ... ${i+1}/${all.length}`);
  }
  console.log('');
  console.log(`Geschrieben: ${ok}  |  Fehler: ${fail}`);
})().catch(e => { console.error('FEHLER:', e); process.exit(1); });
