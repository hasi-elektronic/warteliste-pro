#!/usr/bin/env node
/**
 * Import: Logo Menauer - Weil der Stadt - Excel Wartelisten 2025 + 2026
 *   nach Firestore /praxen/{WEIL_PRAXIS_ID}/patienten
 *
 * Bypass Rules via firebase-CLI OAuth token (Project-Owner).
 *
 *   node import_weil_der_stadt.js          → DRY-RUN (zeigt parsing)
 *   node import_weil_der_stadt.js --import → wirklich schreiben
 */

const https = require('https');
const fs = require('fs');
const os = require('os');
const path = require('path');
const XLSX = require('xlsx');

const PROJECT_ID = 'warteliste-pro';
const PRAXIS_ID = 'jMlq1h7JQkdDtZo0jqTn'; // Logopaedie Menauer - Weil der Stadt
const CLI_CLIENT_ID = '563584335869-fgrhgmd47bqnekij5i8b5pr03ho849e6.apps.googleusercontent.com';
const CLI_CLIENT_SECRET = 'j9iVZfS8kkCEFUPaAeJV0sAi';
const DO_IMPORT = process.argv.includes('--import');

const FILES = [
  '/Users/hguencavdi/Library/CloudStorage/OneDrive-Hasi/03_Projekte/Warteliste/Warteliste Weil der Stadt/Warteliste 25.xlsx',
  '/Users/hguencavdi/Library/CloudStorage/OneDrive-Hasi/03_Projekte/Warteliste/Warteliste Weil der Stadt/Warteliste 26.xlsx',
];

// ─────────────── HTTP / Auth ───────────────
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

// ─────────────── Mapping-Helfer ───────────────
const MONATE_DE = ['Januar','Februar','März','April','Mai','Juni',
                   'Juli','August','September','Oktober','November','Dezember'];

const SHEET_TO_MONTH_NR = {
  'januar':0, 'februar':1, 'märz':2, 'maerz':2, 'april':3, 'mai':4, 'juni':5,
  'juli':6, 'august':7, 'september':8, 'oktober':9, 'november':10, 'dezember':11,
  '1':0,'2':1,'3':2,'4':3,'5':4,'6':5,'7':6,'8':7,'9':8,'10':9,'11':10,'12':11,
};

function excelDateToJs(serial) {
  if (typeof serial !== 'number') return null;
  // Excel serial: day count since 1899-12-30
  return new Date(Math.round((serial - 25569) * 86400 * 1000));
}

function parseDate(v) {
  if (v == null || v === '') return null;
  if (v instanceof Date) return v;
  if (typeof v === 'number') return excelDateToJs(v);
  const s = String(v).trim();
  if (!s) return null;
  // YYYY-MM-DD or YYYY-MM-DD HH:MM:SS
  let m = s.match(/^(\d{4})-(\d{1,2})-(\d{1,2})/);
  if (m) return new Date(+m[1], +m[2]-1, +m[3]);
  // DD.MM.YYYY
  m = s.match(/^(\d{1,2})\.(\d{1,2})\.(\d{2,4})/);
  if (m) {
    let y = +m[3]; if (y < 100) y += 2000;
    return new Date(y, +m[2]-1, +m[1]);
  }
  // DD.MM.YY (German)
  return null;
}

function normalizeVersicherung(raw) {
  const s = (raw || '').toString().trim().toLowerCase();
  if (!s) return 'KK';
  if (s.startsWith('priv')) return 'Privat';
  if (s.includes('jugendamt')) return 'Jugendamt';
  // AOK, Barmer, TK, KK, gkv, kasse → KK
  if (s.includes('aok') || s.includes('barmer') || s.includes('tk') ||
      s.includes('dak') || s.includes('ikk') || s.includes('kasse') ||
      s === 'kk' || s === 'gkv') return 'KK';
  return 'Sonstiges';
}

// Maps therapeut-cell content to status + note
function parseTherapeutCol(raw) {
  const s = (raw || '').toString().trim();
  if (!s) return { status: 'wartend', note: '' };
  const l = s.toLowerCase();
  if (l.includes('platz gefunden')) return { status: 'platzGefunden', note: s };
  if (l.includes('erledigt') || l.includes('abgeschlossen')) return { status: 'abgeschlossen', note: s };
  if (l.includes('angerufen') || l.includes('kontakt')) return { status: 'wartend', note: s };
  // Initialen (MR, AR, MA, ...) → therapy assigned
  if (s.length <= 4 && /^[A-ZÄÖÜ.\s]+$/i.test(s)) return { status: 'inBehandlung', note: 'Therapeut: ' + s };
  return { status: 'wartend', note: s };
}

function germanMonth(d) {
  return MONATE_DE[d.getMonth()];
}

// "Weitere Infos" oft = Geburtsdatum.  Wenn ja → in geburtsdatum,
// sonst als Text.  Datum-Strings + Excel-Serials erkennen.
function splitWeitereInfos(raw) {
  if (raw == null || raw === '') return { geburtsdatum: null, text: '' };
  if (raw instanceof Date) return { geburtsdatum: raw, text: '' };
  if (typeof raw === 'number') {
    const d = excelDateToJs(raw);
    if (d && d.getFullYear() > 1900 && d.getFullYear() < 2030) return { geburtsdatum: d, text: '' };
  }
  const s = String(raw).trim();
  const d = parseDate(s);
  if (d && d.getFullYear() > 1900 && d.getFullYear() < 2030) return { geburtsdatum: d, text: '' };
  return { geburtsdatum: null, text: s };
}

// ─────────────── Excel-Lesen ───────────────
function parseAllSheets(file) {
  const wb = XLSX.readFile(file, { cellDates: false });
  const out = [];
  for (const sheetName of wb.SheetNames) {
    const ws = wb.Sheets[sheetName];
    const rows = XLSX.utils.sheet_to_json(ws, { header: 1, defval: '', raw: true });
    if (rows.length < 2) continue;
    const header = rows[0].map(h => String(h || '').trim().toLowerCase());
    // Spalten-Index ermitteln
    const idx = {
      anmeldung: header.findIndex(h => h.startsWith('anmeldung')),
      therapeut: header.findIndex(h => h.startsWith('therapeut')),
      name:      header.findIndex(h => h === 'name'),
      vorname:   header.findIndex(h => h === 'vorname'),
      adresse:   header.findIndex(h => h === 'adresse'),
      telefon:   header.findIndex(h => h.startsWith('telefon')),
      kkpriv:    header.findIndex(h => h.startsWith('kk') || h.includes('privat')),
      arzt:      header.findIndex(h => h === 'arzt'),
      stoerung:  header.findIndex(h => h.includes('störung') || h.includes('stoerung')),
      termine:   header.findIndex(h => h === 'termine'),
      infos:     header.findIndex(h => h.includes('weitere')),
    };
    for (let r = 1; r < rows.length; r++) {
      const row = rows[r];
      const get = (k) => (idx[k] >= 0 ? row[idx[k]] : '');
      const name = String(get('name') || '').trim();
      const vorname = String(get('vorname') || '').trim();
      // Skip leere Zeilen
      if (!name && !vorname) continue;
      const anmeldung = parseDate(get('anmeldung')) || new Date();
      const { geburtsdatum, text: infoText } = splitWeitereInfos(get('infos'));
      const therapy = parseTherapeutCol(get('therapeut'));
      const monat = germanMonth(anmeldung);
      out.push({
        anmeldung,
        name,
        vorname,
        adresse: String(get('adresse') || '').trim(),
        telefon: String(get('telefon') || '').trim(),
        versicherung: normalizeVersicherung(get('kkpriv')),
        arzt: String(get('arzt') || '').trim(),
        stoerungsbild: String(get('stoerung') || '').trim(),
        terminWunsch: String(get('termine') || '').trim(),
        weitereInfos: [therapy.note, infoText].filter(Boolean).join(' | '),
        geburtsdatum,
        status: therapy.status,
        monat,
        sourceSheet: sheetName,
        sourceFile: path.basename(file),
      });
    }
  }
  return out;
}

// ─────────────── Firestore-Write ───────────────
function tsField(d) { return { timestampValue: d.toISOString() }; }
function strField(s) { return { stringValue: s || '' }; }
function nullField() { return { nullValue: null }; }

function patientToFirestoreDoc(p) {
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
      geburtsdatum: p.geburtsdatum ? tsField(p.geburtsdatum) : nullField(),
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
      hausbesuch: { booleanValue: /hausbesuch|^hb\b|^hb!/.test((p.weitereInfos || '').toLowerCase()) },
      kkSonstiges: strField(p.versicherung === 'Sonstiges' ? (p.weitereInfos.includes('Sonstiges') ? '' : '') : ''),
    },
  };
}

async function writePatient(token, doc) {
  // POST mit auto-ID
  const r = await req('firestore.googleapis.com',
    `/v1/projects/${PROJECT_ID}/databases/(default)/documents/praxen/${PRAXIS_ID}/patienten`,
    'POST', doc, { 'Authorization': `Bearer ${token}` });
  return r;
}

// ─────────────── Main ───────────────
(async () => {
  console.log(DO_IMPORT ? '📥 IMPORT-MODUS' : '👀 DRY-RUN');
  console.log('Ziel: Weil der Stadt  [' + PRAXIS_ID + ']');
  console.log('');

  // Alle Dateien parsen
  let all = [];
  for (const f of FILES) {
    const rows = parseAllSheets(f);
    console.log(`📄 ${path.basename(f)}: ${rows.length} Eintraege`);
    all = all.concat(rows);
  }
  console.log('');
  console.log(`Gesamt: ${all.length} Patienten`);
  console.log('');

  // Stichprobe ausgeben
  console.log('Stichproben (10 zufaellige):');
  const sample = [];
  for (let i = 0; i < Math.min(10, all.length); i++) {
    sample.push(all[Math.floor(i * all.length / 10)]);
  }
  for (const p of sample) {
    const geb = p.geburtsdatum ? p.geburtsdatum.toISOString().slice(0,10) : '?';
    console.log(`  ${p.anmeldung.toISOString().slice(0,10)} | ${p.vorname} ${p.name} | ${p.versicherung} | ${p.stoerungsbild} | geb:${geb} | ${p.status}`);
  }
  console.log('');

  // Status-Statistik
  const stats = { wartend:0, platzGefunden:0, inBehandlung:0, abgeschlossen:0 };
  const versStats = { KK:0, Privat:0, Jugendamt:0, Sonstiges:0 };
  for (const p of all) { stats[p.status]++; versStats[p.versicherung]++; }
  console.log('Status :', stats);
  console.log('Vers.  :', versStats);
  console.log('');

  if (!DO_IMPORT) {
    console.log('Import ausfuehren: node import_weil_der_stadt.js --import');
    return;
  }

  // Backup
  const stamp = new Date().toISOString().replace(/[:.]/g, '-');
  const bdir = path.join(__dirname, '..', 'backups');
  fs.mkdirSync(bdir, { recursive: true });
  const bfile = path.join(bdir, `import_weil_${stamp}.json`);
  fs.writeFileSync(bfile, JSON.stringify(all, null, 2));
  console.log(`✓ Parse-Backup: ${bfile}`);
  console.log('');

  // Firestore-Write
  const token = await getAccessToken();
  console.log('Schreibe nach Firestore ...');
  let ok = 0, fail = 0;
  for (let i = 0; i < all.length; i++) {
    const p = all[i];
    const doc = patientToFirestoreDoc(p);
    const r = await writePatient(token, doc);
    if (r.status === 200) ok++;
    else { fail++; console.log(`  ✗ row ${i}: ${p.vorname} ${p.name} — ${r.status} ${JSON.stringify(r.body).slice(0,150)}`); }
    if ((i+1) % 25 === 0) console.log(`  ... ${i+1}/${all.length}`);
  }

  console.log('');
  console.log('═══════════════════════════════════════');
  console.log(`Geschrieben: ${ok}  |  Fehler: ${fail}`);
})().catch(e => { console.error('FEHLER:', e); process.exit(1); });
