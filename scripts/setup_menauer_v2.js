#!/usr/bin/env node
/**
 * Logo Menauer Demo-Daten Setup via Firebase REST API
 */

const https = require('https');

const API_KEY = 'AIzaSyDZZhjrosMl1rQGKc8cOtCLJRGxZR3VwFE';
const PROJECT_ID = 'warteliste-pro';

// ═══ HTTP Helper ═══
function post(hostname, path, body) {
  return new Promise((resolve, reject) => {
    const data = JSON.stringify(body);
    const req = https.request({ hostname, path, method: 'POST', headers: { 'Content-Type': 'application/json', 'Content-Length': data.length } }, res => {
      let buf = '';
      res.on('data', c => buf += c);
      res.on('end', () => { try { resolve(JSON.parse(buf)); } catch { resolve(buf); } });
    });
    req.on('error', reject);
    req.write(data);
    req.end();
  });
}

function firestore(method, path, body, token) {
  return new Promise((resolve, reject) => {
    const data = body ? JSON.stringify(body) : '';
    const headers = { 'Content-Type': 'application/json', 'Authorization': `Bearer ${token}` };
    if (data) headers['Content-Length'] = Buffer.byteLength(data);
    const req = https.request({
      hostname: 'firestore.googleapis.com',
      path: `/v1/projects/${PROJECT_ID}/databases/(default)/documents/${path}`,
      method, headers,
    }, res => {
      let buf = '';
      res.on('data', c => buf += c);
      res.on('end', () => { try { resolve(JSON.parse(buf)); } catch { resolve(buf); } });
    });
    req.on('error', reject);
    if (data) req.write(data);
    req.end();
  });
}

// ═══ Auth ═══
async function signUpOrIn(email, password) {
  // Try sign up
  let r = await post('identitytoolkit.googleapis.com', `/v1/accounts:signUp?key=${API_KEY}`, { email, password, returnSecureToken: true });
  if (r.localId) return { uid: r.localId, token: r.idToken, isNew: true };
  // Sign in
  r = await post('identitytoolkit.googleapis.com', `/v1/accounts:signInWithPassword?key=${API_KEY}`, { email, password, returnSecureToken: true });
  if (r.localId) return { uid: r.localId, token: r.idToken, isNew: false };
  throw new Error(`Auth failed for ${email}: ${JSON.stringify(r.error || r)}`);
}

// ═══ Firestore Value Helpers ═══
const sv = v => ({ stringValue: v });
const bv = v => ({ booleanValue: v });
const iv = v => ({ integerValue: String(v) });
const tv = v => ({ timestampValue: v instanceof Date ? v.toISOString() : v });
const av = arr => ({ arrayValue: { values: arr.map(v => ({ stringValue: v })) } });

// ═══ Random Data ═══
const pick = a => a[Math.floor(Math.random() * a.length)];
const randDate = days => new Date(Date.now() - Math.floor(Math.random() * days) * 864e5);
const monat = d => d.toISOString().slice(0, 7);
const randPhone = () => pick(['0711','07033','07156','07042']) + '/' + Math.floor(1e6 + Math.random() * 9e6);

const STOER = ['Dysphagie','Dyslalie','SES','Aphasie','Dysphonie','Stottern','Myofunktionelle Stoerung','Lispeln','LRS','Sprachentwicklungsverzoegerung','Late Talker','Poltern'];
const VN = ['Anna','Ben','Clara','David','Emma','Felix','Greta','Hans','Ida','Jan','Klara','Leon','Mia','Noah','Olivia','Paul','Rita','Sophie','Tom','Ute','Lena','Max','Nina','Oskar','Paula','Robin','Sara','Tim','Vera','Lina'];
const NN = ['Mueller','Schmidt','Schneider','Fischer','Weber','Meyer','Wagner','Becker','Schulz','Hoffmann','Koch','Richter','Klein','Wolf','Neumann','Schwarz','Braun','Zimmermann','Krueger','Hartmann','Lange','Werner','Lehmann','Schmitt','Frank','Berger','Kaiser','Fuchs','Scholz','Vogel'];
const AERZTE = ['Dr. Mueller','Dr. Schmidt','Dr. Weber','Dr. Fischer','Dr. Hoffmann','Dr. Becker','Dr. Klein','Dr. Braun'];
const STR = ['Hauptstr.','Bahnhofstr.','Gartenstr.','Schulstr.','Kirchstr.','Marktplatz','Lindenstr.','Rosenweg'];
const STAT = ['wartend','wartend','wartend','wartend','platzGefunden','inBehandlung','inBehandlung','inBehandlung','abgeschlossen','abgeschlossen'];
const PRIO = ['normal','normal','normal','normal','normal','normal','normal','hoch','hoch','dringend'];

const STANDORTE = [
  { name:'Logopaedie Menauer - Weil der Stadt', inhaber:'Susanne Menauer', adresse:'Stuttgarter Str. 51, 71263 Weil der Stadt', telefon:'07033/137724', email:'praxisweil@logo-menauer.de',
    userEmail:'weil@logo-menauer.de', userPw:'WeilDerStadt2026!',
    therapeuten:[{name:'Milena Roehrborn',fg:'Logopaedie'},{name:'Petra Rodamer',fg:'Lerntherapie'},{name:'Claudia Ehrler',fg:'Lerntherapie'}] },
  { name:'Logopaedie Menauer - Ditzingen', inhaber:'Susanne Menauer', adresse:'Marktstr. 6/1, 71254 Ditzingen', telefon:'07156/1773574', email:'praxisditz@logo-menauer.de',
    userEmail:'ditzingen@logo-menauer.de', userPw:'Ditzingen2026!',
    therapeuten:[{name:'Rita Vittorio',fg:'Logopaedie'},{name:'Aynur Aktag',fg:'Logopaedie'},{name:'Lejla Pehlivan',fg:'Logopaedie'},{name:'Stephanie Eisele',fg:'Logopaedie'},{name:'Laura Zotti',fg:'Logopaedie'},{name:'Michelle Schmidgall',fg:'Logopaedie'},{name:'Vanessa Burghart',fg:'Logopaedie'}] },
  { name:'Logopaedie Menauer - Vaihingen/Enz', inhaber:'Susanne Menauer', adresse:'Andreaestr. 16/1, 71665 Vaihingen/Enz', telefon:'07042/8187767', email:'praxisvaih@logo-menauer.de',
    userEmail:'vaihingen@logo-menauer.de', userPw:'Vaihingen2026!',
    therapeuten:[{name:'Susanne Menauer',fg:'Logopaedie/Lerntherapie'},{name:'Saskia Philipsen',fg:'Logopaedie'},{name:'Fadi Adelhelm',fg:'Logopaedie'},{name:'Judith Emmerich',fg:'Logopaedie'}] },
];

async function main() {
  console.log('═══════════════════════════════════════════');
  console.log(' Logo Menauer - Demo-Daten Setup');
  console.log('═══════════════════════════════════════════\n');

  // 1. Admin
  console.log('1. Admin-User...');
  const admin = await signUpOrIn('admin@logo-menauer.de', 'LogoMenauer2026!');
  console.log(`   ${admin.isNew ? '+' : '✓'} admin@logo-menauer.de (${admin.uid.slice(0,12)}...)`);
  const TOKEN = admin.token;

  // 2. Standort-User
  console.log('\n2. Standort-User...');
  const userUids = {};
  for (const s of STANDORTE) {
    const u = await signUpOrIn(s.userEmail, s.userPw);
    userUids[s.userEmail] = u.uid;
    console.log(`   ${u.isNew ? '+' : '✓'} ${s.userEmail} (${u.uid.slice(0,12)}...)`);
  }

  // 3. Praxis-IDs vorab generieren + User-Dokumente ERST erstellen
  console.log('\n3. User-Dokumente + Standorte...');
  const praxisIds = [];

  // Schritt A: Praxen erstellen und IDs sammeln
  for (const s of STANDORTE) {
    const pr = await firestore('POST', 'praxen', { fields: {
      name: sv(s.name), inhaber: sv(s.inhaber), adresse: sv(s.adresse),
      telefon: sv(s.telefon), email: sv(s.email), createdAt: tv(new Date()),
    }}, TOKEN);
    const pid = pr.name ? pr.name.split('/').pop() : null;
    if (!pid) { console.log('   ❌ Praxis erstellen fehlgeschlagen:', JSON.stringify(pr).slice(0,200)); continue; }
    praxisIds.push(pid);
    s._pid = pid;
    console.log(`\n   📍 ${s.name} (${pid.slice(0,8)}...)`);
  }

  // Schritt B: User-Dokumente mit praxisIds erstellen (damit isPraxisMember funktioniert)
  for (const s of STANDORTE) {
    if (!s._pid) continue;
    const suid = userUids[s.userEmail];
    const mask = 'updateMask.fieldPaths=email&updateMask.fieldPaths=displayName&updateMask.fieldPaths=praxisId&updateMask.fieldPaths=praxisIds&updateMask.fieldPaths=role&updateMask.fieldPaths=createdAt';
    await firestore('PATCH', `users/${suid}?${mask}`, { fields: {
      email: sv(s.userEmail), displayName: sv(s.name),
      praxisId: sv(s._pid), praxisIds: av([s._pid]),
      role: sv('user'), createdAt: tv(new Date()),
    }}, TOKEN);
    console.log(`   ✅ User-Doc: ${s.userEmail} → ${s._pid.slice(0,8)}...`);
  }

  // Admin User-Dokument (alle Standorte)
  const amask = 'updateMask.fieldPaths=email&updateMask.fieldPaths=displayName&updateMask.fieldPaths=praxisId&updateMask.fieldPaths=praxisIds&updateMask.fieldPaths=role&updateMask.fieldPaths=createdAt';
  await firestore('PATCH', `users/${admin.uid}?${amask}`, { fields: {
    email: sv('admin@logo-menauer.de'), displayName: sv('Susanne Menauer (Admin)'),
    praxisId: sv(praxisIds[0]), praxisIds: av(praxisIds),
    role: sv('admin'), createdAt: tv(new Date()),
  }}, TOKEN);
  console.log(`   ✅ Admin-Doc → ${praxisIds.length} Standorte`);

  // Schritt C: Therapeuten + Patienten (jetzt hat Admin Zugriff)
  console.log('\n4. Therapeuten + Patienten...');
  for (const s of STANDORTE) {
    const pid = s._pid;
    if (!pid) continue;
    console.log(`\n   📍 ${s.name}`);

    // Therapeuten
    const tids = [];
    for (const t of s.therapeuten) {
      const tr = await firestore('POST', `praxen/${pid}/therapeuten`, { fields: {
        name: sv(t.name), aktiv: bv(true), praxisId: sv(pid),
        maxPatienten: iv(15), fachgebiet: sv(t.fg),
      }}, TOKEN);
      const tid = tr.name ? tr.name.split('/').pop() : null;
      if (tid) tids.push(tid);
      console.log(`      👤 ${t.name}${tid ? '' : ' ❌'}`);
    }

    // 12 Patienten
    for (let i = 0; i < 12; i++) {
      const anm = randDate(180);
      const st = pick(STAT);
      const thId = st !== 'wartend' && tids.length ? pick(tids) : null;
      const rzDt = Math.random() > 0.3 ? randDate(90) : null;
      const rzBis = rzDt ? new Date(rzDt.getTime() + (28 + Math.floor(Math.random()*60))*864e5) : null;
      const lk = Math.random() > 0.3 ? randDate(60) : null;

      const f = {
        anmeldung: tv(anm), name: sv(pick(NN)), vorname: sv(pick(VN)),
        adresse: sv(`${pick(STR)} ${1+Math.floor(Math.random()*80)}`),
        telefon: sv(randPhone()), versicherung: sv(Math.random()>0.25?'KK':'Privat'),
        arzt: sv(pick(AERZTE)), stoerungsbild: sv(pick(STOER)),
        terminWunsch: sv(pick(['flexibel','vormittags','nachmittags'])),
        weitereInfos: sv(''), geburtsdatum: tv(randDate(365*50)),
        status: sv(st), monat: sv(monat(anm)), praxisId: sv(pid),
        prioritaet: sv(pick(PRIO)),
      };
      if (thId) f.therapeutId = sv(thId);
      if (st==='platzGefunden'||st==='inBehandlung') f.platzGefundenAm = tv(randDate(60));
      if (rzDt) { f.rezeptDatum = tv(rzDt); f.rezeptGueltigBis = tv(rzBis); f.verordnungsMenge = iv((1+Math.floor(Math.random()*3))*10); }
      if (lk) f.letzterKontakt = tv(lk);

      await firestore('POST', `praxen/${pid}/patienten`, { fields: f }, TOKEN);
    }
    console.log(`      ✅ 12 Patienten`);
  }

  // Zusammenfassung
  console.log('\n═══════════════════════════════════════════');
  console.log(' ✅ FERTIG!');
  console.log('═══════════════════════════════════════════');
  console.log('\n Admin (alle Standorte):');
  console.log('   E-Mail:   admin@logo-menauer.de');
  console.log('   Passwort: LogoMenauer2026!\n');
  STANDORTE.forEach(s => {
    console.log(` ${s.name}:`);
    console.log(`   E-Mail:   ${s.userEmail}`);
    console.log(`   Passwort: ${s.userPw}\n`);
  });
  console.log(` Erstellt: 4 User, 3 Standorte, ${STANDORTE.reduce((s,x)=>s+x.therapeuten.length,0)} Therapeuten, 36 Patienten\n`);
}

main().catch(e => { console.error('FEHLER:', e.message); process.exit(1); });
