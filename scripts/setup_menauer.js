/**
 * Setup-Script fuer Logo Menauer Demo-Daten
 * Erstellt: Admin, 3 Standorte, Mitarbeiter-User, je 10+ Patienten
 *
 * Ausfuehren: node setup_menauer.js
 * Voraussetzung: GOOGLE_APPLICATION_CREDENTIALS oder firebase login
 */

const { initializeApp, cert, applicationDefault } = require('firebase-admin/app');
const { getFirestore, Timestamp } = require('firebase-admin/firestore');
const { getAuth } = require('firebase-admin/auth');

// Firebase mit Project ID initialisieren (nutzt firebase login Token)
initializeApp({ projectId: 'warteliste-pro' });

const db = getFirestore();
const auth = getAuth();

// ══════════════════════════════════════════════════════════
// Konfiguration
// ══════════════════════════════════════════════════════════

const ADMIN_EMAIL = 'admin@logo-menauer.de';
const ADMIN_PASSWORD = 'LogoMenauer2026!';

const STANDORTE = [
  {
    name: 'Logopaedie Menauer - Weil der Stadt',
    inhaber: 'Susanne Menauer',
    adresse: 'Stuttgarter Str. 51, 71263 Weil der Stadt',
    telefon: '07033/137724',
    email: 'praxisweil@logo-menauer.de',
    therapeuten: [
      { name: 'Milena Roehrborn', fachgebiet: 'Logopaedie' },
      { name: 'Petra Rodamer', fachgebiet: 'Lerntherapie LRS/Dyskalkulie' },
      { name: 'Claudia Ehrler', fachgebiet: 'Lerntherapie' },
    ],
    userEmail: 'weil@logo-menauer.de',
    userPassword: 'WeilDerStadt2026!',
  },
  {
    name: 'Logopaedie Menauer - Ditzingen',
    inhaber: 'Susanne Menauer',
    adresse: 'Marktstr. 6/1, 71254 Ditzingen',
    telefon: '07156/1773574',
    email: 'praxisditz@logo-menauer.de',
    therapeuten: [
      { name: 'Rita Vittorio', fachgebiet: 'Logopaedie' },
      { name: 'Aynur Aktag', fachgebiet: 'Logopaedie' },
      { name: 'Lejla Pehlivan', fachgebiet: 'Logopaedie' },
      { name: 'Stephanie Eisele', fachgebiet: 'Logopaedie' },
      { name: 'Laura Zotti', fachgebiet: 'Logopaedie' },
      { name: 'Michelle Schmidgall', fachgebiet: 'Logopaedie' },
      { name: 'Vanessa Burghart', fachgebiet: 'Logopaedie' },
    ],
    userEmail: 'ditzingen@logo-menauer.de',
    userPassword: 'Ditzingen2026!',
  },
  {
    name: 'Logopaedie Menauer - Vaihingen/Enz',
    inhaber: 'Susanne Menauer',
    adresse: 'Andreaestr. 16/1, 71665 Vaihingen/Enz',
    telefon: '07042/8187767',
    email: 'praxisvaih@logo-menauer.de',
    therapeuten: [
      { name: 'Susanne Menauer', fachgebiet: 'Logopaedie/Lerntherapie' },
      { name: 'Saskia Philipsen', fachgebiet: 'Logopaedie' },
      { name: 'Fadi Adelhelm', fachgebiet: 'Logopaedie' },
      { name: 'Judith Emmerich', fachgebiet: 'Logopaedie' },
    ],
    userEmail: 'vaihingen@logo-menauer.de',
    userPassword: 'Vaihingen2026!',
  },
];

// Stoerungsbilder fuer realistische Patienten
const STOERUNGSBILDER = [
  'Dysphagie', 'Dyslalie', 'SES', 'Aphasie', 'Dysphonie',
  'Stottern', 'Myofunktionelle Stoerung', 'Autismus',
  'Hoergeraet/CI', 'Lispeln', 'LRS', 'Sprachentwicklungsverzoegerung',
];

const VORNAMEN = [
  'Anna', 'Ben', 'Clara', 'David', 'Emma', 'Felix', 'Greta', 'Hans',
  'Ida', 'Jan', 'Klara', 'Leon', 'Mia', 'Noah', 'Olivia', 'Paul',
  'Rita', 'Sophie', 'Tom', 'Ute', 'Viktor', 'Lena', 'Max', 'Nina',
  'Oskar', 'Paula', 'Robin', 'Sara', 'Tim', 'Vera',
];

const NACHNAMEN = [
  'Mueller', 'Schmidt', 'Schneider', 'Fischer', 'Weber', 'Meyer',
  'Wagner', 'Becker', 'Schulz', 'Hoffmann', 'Koch', 'Richter',
  'Klein', 'Wolf', 'Neumann', 'Schwarz', 'Braun', 'Zimmermann',
  'Krueger', 'Hartmann', 'Lange', 'Werner', 'Lehmann', 'Schmitt',
  'Frank', 'Berger', 'Kaiser', 'Fuchs', 'Scholz', 'Vogel',
];

const AERZTE = [
  'Dr. Mueller', 'Dr. Schmidt', 'Dr. Weber', 'Dr. Fischer',
  'Dr. Hoffmann', 'Dr. Becker', 'Dr. Klein', 'Dr. Braun',
  'Dr. Richter', 'Dr. Wagner',
];

// ══════════════════════════════════════════════════════════
// Hilfsfunktionen
// ══════════════════════════════════════════════════════════

function randomItem(arr) {
  return arr[Math.floor(Math.random() * arr.length)];
}

function randomDate(startDays, endDays) {
  const now = new Date();
  const start = new Date(now.getTime() - startDays * 86400000);
  const end = new Date(now.getTime() - endDays * 86400000);
  return new Date(start.getTime() + Math.random() * (end.getTime() - start.getTime()));
}

function randomPhone() {
  const prefix = ['0711', '07033', '07156', '07042'][Math.floor(Math.random() * 4)];
  const num = Math.floor(1000000 + Math.random() * 9000000);
  return `${prefix}/${num}`;
}

function formatMonat(date) {
  return `${date.getFullYear()}-${String(date.getMonth() + 1).padStart(2, '0')}`;
}

const STATUS_OPTIONS = ['wartend', 'platzGefunden', 'inBehandlung', 'abgeschlossen'];
const STATUS_WEIGHTS = [0.4, 0.15, 0.3, 0.15]; // 40% wartend, ...

function weightedStatus() {
  const r = Math.random();
  let sum = 0;
  for (let i = 0; i < STATUS_OPTIONS.length; i++) {
    sum += STATUS_WEIGHTS[i];
    if (r <= sum) return STATUS_OPTIONS[i];
  }
  return STATUS_OPTIONS[0];
}

function generatePatient(praxisId, therapeutIds) {
  const anmeldung = randomDate(180, 1);
  const status = weightedStatus();
  const vorname = randomItem(VORNAMEN);
  const name = randomItem(NACHNAMEN);
  const stoerungsbild = randomItem(STOERUNGSBILDER);
  const therapeutId = status !== 'wartend' && therapeutIds.length > 0
    ? randomItem(therapeutIds) : null;

  const geburtsdatum = randomDate(365 * 80, 365 * 2);
  const rezeptDatum = Math.random() > 0.3 ? randomDate(90, 1) : null;
  const rezeptGueltigBis = rezeptDatum
    ? new Date(rezeptDatum.getTime() + (28 + Math.floor(Math.random() * 60)) * 86400000)
    : null;

  const prioritaet = Math.random() > 0.8
    ? (Math.random() > 0.5 ? 'dringend' : 'hoch')
    : 'normal';

  const letzterKontakt = Math.random() > 0.3
    ? randomDate(60, 0)
    : null;

  return {
    anmeldung: Timestamp.fromDate(anmeldung),
    name,
    vorname,
    adresse: `${randomItem(['Hauptstr.', 'Bahnhofstr.', 'Gartenstr.', 'Schulstr.', 'Kirchstr.', 'Marktplatz', 'Muehlenweg', 'Lindenstr.'])} ${Math.floor(1 + Math.random() * 80)}`,
    telefon: randomPhone(),
    versicherung: Math.random() > 0.25 ? 'KK' : 'Privat',
    arzt: randomItem(AERZTE),
    stoerungsbild,
    terminWunsch: randomItem(['flexibel', 'vormittags', 'nachmittags']),
    weitereInfos: '',
    geburtsdatum: Timestamp.fromDate(geburtsdatum),
    status,
    therapeutId,
    platzGefundenAm: status === 'platzGefunden' || status === 'inBehandlung'
      ? Timestamp.fromDate(randomDate(60, 1))
      : null,
    monat: formatMonat(anmeldung),
    praxisId,
    rezeptDatum: rezeptDatum ? Timestamp.fromDate(rezeptDatum) : null,
    rezeptGueltigBis: rezeptGueltigBis ? Timestamp.fromDate(rezeptGueltigBis) : null,
    verordnungsMenge: rezeptDatum ? (Math.floor(Math.random() * 3) + 1) * 10 : null,
    letzterKontakt: letzterKontakt ? Timestamp.fromDate(letzterKontakt) : null,
    prioritaet,
  };
}

// ══════════════════════════════════════════════════════════
// Hauptlogik
// ══════════════════════════════════════════════════════════

async function createOrGetUser(email, password, displayName) {
  try {
    const user = await auth.getUserByEmail(email);
    console.log(`  ✓ User existiert: ${email} (${user.uid})`);
    return user.uid;
  } catch (e) {
    if (e.code === 'auth/user-not-found') {
      const user = await auth.createUser({
        email,
        password,
        displayName,
        emailVerified: true,
      });
      console.log(`  + User erstellt: ${email} (${user.uid})`);
      return user.uid;
    }
    throw e;
  }
}

async function main() {
  console.log('═══════════════════════════════════════════');
  console.log(' Logo Menauer - Demo-Daten Setup');
  console.log('═══════════════════════════════════════════\n');

  // 1. Admin-User erstellen
  console.log('1. Admin-User erstellen...');
  const adminUid = await createOrGetUser(
    ADMIN_EMAIL, ADMIN_PASSWORD, 'Susanne Menauer (Admin)'
  );

  // 2. Standorte erstellen
  console.log('\n2. Standorte erstellen...');
  const praxisIds = [];
  const allPraxisIds = [];

  for (const standort of STANDORTE) {
    const praxisRef = db.collection('praxen').doc();
    const praxisId = praxisRef.id;
    praxisIds.push(praxisId);
    allPraxisIds.push(praxisId);

    await praxisRef.set({
      name: standort.name,
      inhaber: standort.inhaber,
      adresse: standort.adresse,
      telefon: standort.telefon,
      email: standort.email,
      createdAt: Timestamp.fromDate(new Date()),
    });
    console.log(`  + Standort: ${standort.name} (${praxisId})`);

    // Therapeuten erstellen
    const therapeutIds = [];
    for (const therapeut of standort.therapeuten) {
      const thRef = praxisRef.collection('therapeuten').doc();
      await thRef.set({
        name: therapeut.name,
        aktiv: true,
        praxisId,
        maxPatienten: 15,
        fachgebiet: therapeut.fachgebiet,
      });
      therapeutIds.push(thRef.id);
      console.log(`    + Therapeut: ${therapeut.name}`);
    }

    // Patienten erstellen (12 pro Standort)
    console.log(`    Erstelle 12 Patienten...`);
    for (let i = 0; i < 12; i++) {
      const patient = generatePatient(praxisId, therapeutIds);
      await praxisRef.collection('patienten').add(patient);
    }
    console.log(`    ✓ 12 Patienten erstellt`);

    // Standort-User erstellen
    console.log(`    Standort-User: ${standort.userEmail}`);
    const standortUid = await createOrGetUser(
      standort.userEmail, standort.userPassword, standort.name
    );

    // User-Dokument fuer Standort-User
    await db.collection('users').doc(standortUid).set({
      email: standort.userEmail,
      displayName: standort.name,
      praxisId,
      praxisIds: [praxisId],
      role: 'user',
      createdAt: Timestamp.fromDate(new Date()),
    });
    console.log(`    ✓ User-Dokument erstellt`);
  }

  // 3. Admin User-Dokument (alle Standorte)
  console.log('\n3. Admin User-Dokument (alle Standorte)...');
  await db.collection('users').doc(adminUid).set({
    email: ADMIN_EMAIL,
    displayName: 'Susanne Menauer (Admin)',
    praxisId: allPraxisIds[0], // Erster Standort als Default
    praxisIds: allPraxisIds,
    role: 'admin',
    createdAt: Timestamp.fromDate(new Date()),
  });
  console.log(`  ✓ Admin hat Zugriff auf ${allPraxisIds.length} Standorte`);

  // 4. Zusammenfassung
  console.log('\n═══════════════════════════════════════════');
  console.log(' FERTIG! Zusammenfassung:');
  console.log('═══════════════════════════════════════════');
  console.log(`\n  Admin-Login:`);
  console.log(`    E-Mail:   ${ADMIN_EMAIL}`);
  console.log(`    Passwort: ${ADMIN_PASSWORD}`);
  console.log(`    Rolle:    admin (alle ${allPraxisIds.length} Standorte)`);

  console.log(`\n  Standort-Logins:`);
  for (const s of STANDORTE) {
    console.log(`    ${s.name}:`);
    console.log(`      E-Mail:   ${s.userEmail}`);
    console.log(`      Passwort: ${s.userPassword}`);
  }

  console.log(`\n  Erstellt:`);
  console.log(`    - 1 Admin + 3 Standort-User = 4 Benutzer`);
  console.log(`    - 3 Standorte`);
  console.log(`    - ${STANDORTE.reduce((s, st) => s + st.therapeuten.length, 0)} Therapeuten`);
  console.log(`    - 36 Patienten (12 pro Standort)`);
  console.log('');

  process.exit(0);
}

main().catch(err => {
  console.error('FEHLER:', err);
  process.exit(1);
});
