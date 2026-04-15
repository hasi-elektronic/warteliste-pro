#!/bin/bash
# Setup Logo Menauer Demo-Daten via Firebase REST API
# Erstellt: Admin, 3 Standorte, User, Patienten

API_KEY="AIzaSyDZZhjrosMl1rQGKc8cOtCLJRGxZR3VwFE"
PROJECT_ID="warteliste-pro"
FIRESTORE_URL="https://firestore.googleapis.com/v1/projects/${PROJECT_ID}/databases/(default)/documents"

# ══════════════════════════════════════════
# Hilfsfunktionen
# ══════════════════════════════════════════

create_user() {
  local EMAIL="$1"
  local PASSWORD="$2"
  local DISPLAY="$3"

  RESULT=$(curl -s "https://identitytoolkit.googleapis.com/v1/accounts:signUp?key=${API_KEY}" \
    -H 'Content-Type: application/json' \
    -d "{\"email\":\"${EMAIL}\",\"password\":\"${PASSWORD}\",\"returnSecureToken\":true}")

  FUID=$(echo "$RESULT" | python3 -c "import sys,json; print(json.load(sys.stdin).get('localId',''))" 2>/dev/null)

  if [ -z "$UID" ]; then
    # User existiert wahrscheinlich -> einloggen
    RESULT=$(curl -s "https://identitytoolkit.googleapis.com/v1/accounts:signInWithPassword?key=${API_KEY}" \
      -H 'Content-Type: application/json' \
      -d "{\"email\":\"${EMAIL}\",\"password\":\"${PASSWORD}\",\"returnSecureToken\":true}")
    FUID=$(echo "$RESULT" | python3 -c "import sys,json; print(json.load(sys.stdin).get('localId',''))" 2>/dev/null)
    TOKEN=$(echo "$RESULT" | python3 -c "import sys,json; print(json.load(sys.stdin).get('idToken',''))" 2>/dev/null)
    echo "  ✓ User existiert: ${EMAIL} (${UID})"
  else
    TOKEN=$(echo "$RESULT" | python3 -c "import sys,json; print(json.load(sys.stdin).get('idToken',''))" 2>/dev/null)
    echo "  + User erstellt: ${EMAIL} (${UID})"
  fi

  # Return values via global vars
  LAST_FUID="$UID"
  LAST_TOKEN="$TOKEN"
}

write_firestore() {
  local PATH_="$1"
  local DATA="$2"
  local TOKEN="$3"

  curl -s -X PATCH \
    "${FIRESTORE_URL}/${PATH_}" \
    -H "Authorization: Bearer ${TOKEN}" \
    -H "Content-Type: application/json" \
    -d "$DATA" > /dev/null 2>&1
}

create_firestore_doc() {
  local COLLECTION="$1"
  local DATA="$2"
  local TOKEN="$3"

  RESULT=$(curl -s -X POST \
    "${FIRESTORE_URL}/${COLLECTION}" \
    -H "Authorization: Bearer ${TOKEN}" \
    -H "Content-Type: application/json" \
    -d "$DATA")

  DOC_ID=$(echo "$RESULT" | python3 -c "import sys,json; name=json.load(sys.stdin).get('name',''); print(name.split('/')[-1])" 2>/dev/null)
  echo "$DOC_ID"
}

timestamp_now() {
  date -u +"%Y-%m-%dT%H:%M:%SZ"
}

random_date() {
  local DAYS_AGO=$1
  local OFFSET=$((RANDOM % DAYS_AGO))
  if [[ "$(uname)" == "Darwin" ]]; then
    date -u -v-${OFFSET}d +"%Y-%m-%dT%H:%M:%SZ"
  else
    date -u -d "${OFFSET} days ago" +"%Y-%m-%dT%H:%M:%SZ"
  fi
}

random_monat() {
  local DAYS_AGO=$1
  local OFFSET=$((RANDOM % DAYS_AGO))
  if [[ "$(uname)" == "Darwin" ]]; then
    date -v-${OFFSET}d +"%Y-%m"
  else
    date -d "${OFFSET} days ago" +"%Y-%m"
  fi
}

echo "═══════════════════════════════════════════"
echo " Logo Menauer - Demo-Daten Setup"
echo "═══════════════════════════════════════════"
echo ""

# ══════════════════════════════════════════
# 1. Admin-User erstellen
# ══════════════════════════════════════════
echo "1. Admin-User erstellen..."
create_user "admin@logo-menauer.de" "LogoMenauer2026!" "Susanne Menauer"
ADMIN_FUID="$LAST_FUID"
ADMIN_TOKEN="$LAST_TOKEN"

if [ -z "$ADMIN_TOKEN" ]; then
  echo "FEHLER: Kein Token erhalten. Abbruch."
  exit 1
fi

# ══════════════════════════════════════════
# 2. Standort-User erstellen
# ══════════════════════════════════════════
echo ""
echo "2. Standort-User erstellen..."
create_user "weil@logo-menauer.de" "WeilDerStadt2026!" "Praxis Weil der Stadt"
WEIL_FUID="$LAST_FUID"

create_user "ditzingen@logo-menauer.de" "Ditzingen2026!" "Praxis Ditzingen"
DITZ_FUID="$LAST_FUID"

create_user "vaihingen@logo-menauer.de" "Vaihingen2026!" "Praxis Vaihingen"
VAIH_FUID="$LAST_FUID"

# ══════════════════════════════════════════
# 3. Node.js Script fuer Firestore-Daten
# ══════════════════════════════════════════
echo ""
echo "3. Firestore-Daten mit Node.js erstellen..."

# Erstelle temporaeres Node.js Script
node -e "
const https = require('https');

const TOKEN = '${ADMIN_TOKEN}';
const PROJECT = '${PROJECT_ID}';
const BASE = 'firestore.googleapis.com';

function firestoreRequest(method, path, body) {
  return new Promise((resolve, reject) => {
    const options = {
      hostname: BASE,
      path: '/v1/projects/${PROJECT_ID}/databases/(default)/documents/' + path,
      method: method,
      headers: {
        'Authorization': 'Bearer ' + TOKEN,
        'Content-Type': 'application/json',
      },
    };
    const req = https.request(options, (res) => {
      let data = '';
      res.on('data', (chunk) => data += chunk);
      res.on('end', () => {
        try { resolve(JSON.parse(data)); }
        catch (e) { resolve(data); }
      });
    });
    req.on('error', reject);
    if (body) req.write(JSON.stringify(body));
    req.end();
  });
}

function sv(val) { return { stringValue: val }; }
function bv(val) { return { booleanValue: val }; }
function iv(val) { return { integerValue: String(val) }; }
function tv(date) { return { timestampValue: date }; }
function nv() { return { nullValue: null }; }
function av(arr) { return { arrayValue: { values: arr.map(v => ({ stringValue: v })) } }; }

function randomItem(arr) { return arr[Math.floor(Math.random() * arr.length)]; }
function randomDate(daysAgo) {
  const d = new Date(Date.now() - Math.floor(Math.random() * daysAgo) * 86400000);
  return d.toISOString();
}
function formatMonat(iso) { return iso.substring(0, 7); }
function randomPhone() {
  const p = ['0711','07033','07156','07042'][Math.floor(Math.random()*4)];
  return p + '/' + Math.floor(1000000 + Math.random()*9000000);
}

const STOERUNGEN = ['Dysphagie','Dyslalie','SES','Aphasie','Dysphonie','Stottern','Myofunktionelle Stoerung','Lispeln','LRS','Sprachentwicklungsverzoegerung','Late Talker','Poltern'];
const VORNAMEN = ['Anna','Ben','Clara','David','Emma','Felix','Greta','Hans','Ida','Jan','Klara','Leon','Mia','Noah','Olivia','Paul','Rita','Sophie','Tom','Ute','Lena','Max','Nina','Oskar','Paula','Robin','Sara','Tim','Vera','Lina'];
const NACHNAMEN = ['Mueller','Schmidt','Schneider','Fischer','Weber','Meyer','Wagner','Becker','Schulz','Hoffmann','Koch','Richter','Klein','Wolf','Neumann','Schwarz','Braun','Zimmermann','Krueger','Hartmann','Lange','Werner','Lehmann','Schmitt','Frank','Berger','Kaiser','Fuchs','Scholz','Vogel'];
const AERZTE = ['Dr. Mueller','Dr. Schmidt','Dr. Weber','Dr. Fischer','Dr. Hoffmann','Dr. Becker','Dr. Klein','Dr. Braun'];
const STRASSEN = ['Hauptstr.','Bahnhofstr.','Gartenstr.','Schulstr.','Kirchstr.','Marktplatz','Lindenstr.','Rosenweg'];
const STATUS = ['wartend','wartend','wartend','wartend','platzGefunden','inBehandlung','inBehandlung','inBehandlung','abgeschlossen','abgeschlossen'];
const PRIO = ['normal','normal','normal','normal','normal','normal','normal','hoch','hoch','dringend'];

const STANDORTE = [
  {
    name: 'Logopaedie Menauer - Weil der Stadt',
    inhaber: 'Susanne Menauer',
    adresse: 'Stuttgarter Str. 51, 71263 Weil der Stadt',
    telefon: '07033/137724',
    email: 'praxisweil@logo-menauer.de',
    userUid: '${WEIL_FUID}',
    userEmail: 'weil@logo-menauer.de',
    therapeuten: [
      { name: 'Milena Roehrborn', fachgebiet: 'Logopaedie' },
      { name: 'Petra Rodamer', fachgebiet: 'Lerntherapie' },
      { name: 'Claudia Ehrler', fachgebiet: 'Lerntherapie' },
    ],
  },
  {
    name: 'Logopaedie Menauer - Ditzingen',
    inhaber: 'Susanne Menauer',
    adresse: 'Marktstr. 6/1, 71254 Ditzingen',
    telefon: '07156/1773574',
    email: 'praxisditz@logo-menauer.de',
    userUid: '${DITZ_FUID}',
    userEmail: 'ditzingen@logo-menauer.de',
    therapeuten: [
      { name: 'Rita Vittorio', fachgebiet: 'Logopaedie' },
      { name: 'Aynur Aktag', fachgebiet: 'Logopaedie' },
      { name: 'Lejla Pehlivan', fachgebiet: 'Logopaedie' },
      { name: 'Stephanie Eisele', fachgebiet: 'Logopaedie' },
      { name: 'Laura Zotti', fachgebiet: 'Logopaedie' },
      { name: 'Michelle Schmidgall', fachgebiet: 'Logopaedie' },
      { name: 'Vanessa Burghart', fachgebiet: 'Logopaedie' },
    ],
  },
  {
    name: 'Logopaedie Menauer - Vaihingen/Enz',
    inhaber: 'Susanne Menauer',
    adresse: 'Andreaestr. 16/1, 71665 Vaihingen/Enz',
    telefon: '07042/8187767',
    email: 'praxisvaih@logo-menauer.de',
    userUid: '${VAIH_FUID}',
    userEmail: 'vaihingen@logo-menauer.de',
    therapeuten: [
      { name: 'Susanne Menauer', fachgebiet: 'Logopaedie/Lerntherapie' },
      { name: 'Saskia Philipsen', fachgebiet: 'Logopaedie' },
      { name: 'Fadi Adelhelm', fachgebiet: 'Logopaedie' },
      { name: 'Judith Emmerich', fachgebiet: 'Logopaedie' },
    ],
  },
];

async function main() {
  const praxisIds = [];

  for (const s of STANDORTE) {
    // Praxis erstellen
    const praxisResult = await firestoreRequest('POST', 'praxen', {
      fields: {
        name: sv(s.name), inhaber: sv(s.inhaber), adresse: sv(s.adresse),
        telefon: sv(s.telefon), email: sv(s.email),
        createdAt: tv(new Date().toISOString()),
      }
    });
    const praxisId = praxisResult.name ? praxisResult.name.split('/').pop() : '';
    praxisIds.push(praxisId);
    console.log('  + Standort: ' + s.name + ' (' + praxisId + ')');

    // Therapeuten
    const therapeutIds = [];
    for (const t of s.therapeuten) {
      const tResult = await firestoreRequest('POST', 'praxen/' + praxisId + '/therapeuten', {
        fields: {
          name: sv(t.name), aktiv: bv(true), praxisId: sv(praxisId),
          maxPatienten: iv(15), fachgebiet: sv(t.fachgebiet),
        }
      });
      const tId = tResult.name ? tResult.name.split('/').pop() : '';
      therapeutIds.push(tId);
      console.log('    + ' + t.name);
    }

    // 12 Patienten
    for (let i = 0; i < 12; i++) {
      const anmeldung = randomDate(180);
      const status = randomItem(STATUS);
      const thId = (status !== 'wartend' && therapeutIds.length > 0) ? randomItem(therapeutIds) : null;
      const rezeptDate = Math.random() > 0.3 ? randomDate(90) : null;
      const rezeptBis = rezeptDate ? new Date(new Date(rezeptDate).getTime() + (28 + Math.floor(Math.random()*60))*86400000).toISOString() : null;
      const kontakt = Math.random() > 0.3 ? randomDate(60) : null;

      const fields = {
        anmeldung: tv(anmeldung),
        name: sv(randomItem(NACHNAMEN)),
        vorname: sv(randomItem(VORNAMEN)),
        adresse: sv(randomItem(STRASSEN) + ' ' + Math.floor(1+Math.random()*80)),
        telefon: sv(randomPhone()),
        versicherung: sv(Math.random() > 0.25 ? 'KK' : 'Privat'),
        arzt: sv(randomItem(AERZTE)),
        stoerungsbild: sv(randomItem(STOERUNGEN)),
        terminWunsch: sv(randomItem(['flexibel','vormittags','nachmittags'])),
        weitereInfos: sv(''),
        geburtsdatum: tv(randomDate(365*50)),
        status: sv(status),
        monat: sv(formatMonat(anmeldung)),
        praxisId: sv(praxisId),
        prioritaet: sv(randomItem(PRIO)),
      };
      if (thId) fields.therapeutId = sv(thId);
      if (status === 'platzGefunden' || status === 'inBehandlung') fields.platzGefundenAm = tv(randomDate(60));
      if (rezeptDate) {
        fields.rezeptDatum = tv(rezeptDate);
        fields.rezeptGueltigBis = tv(rezeptBis);
        fields.verordnungsMenge = iv((Math.floor(Math.random()*3)+1)*10);
      }
      if (kontakt) fields.letzterKontakt = tv(kontakt);

      await firestoreRequest('POST', 'praxen/' + praxisId + '/patienten', { fields });
    }
    console.log('    ✓ 12 Patienten erstellt');

    // Standort-User Dokument
    await firestoreRequest('PATCH', 'users/' + s.userUid + '?updateMask.fieldPaths=email&updateMask.fieldPaths=displayName&updateMask.fieldPaths=praxisId&updateMask.fieldPaths=praxisIds&updateMask.fieldPaths=role&updateMask.fieldPaths=createdAt', {
      fields: {
        email: sv(s.userEmail), displayName: sv(s.name),
        praxisId: sv(praxisId), praxisIds: av([praxisId]),
        role: sv('user'), createdAt: tv(new Date().toISOString()),
      }
    });
    console.log('    ✓ User-Dokument: ' + s.userEmail);
  }

  // Admin User-Dokument
  await firestoreRequest('PATCH', 'users/${ADMIN_FUID}?updateMask.fieldPaths=email&updateMask.fieldPaths=displayName&updateMask.fieldPaths=praxisId&updateMask.fieldPaths=praxisIds&updateMask.fieldPaths=role&updateMask.fieldPaths=createdAt', {
    fields: {
      email: sv('admin@logo-menauer.de'), displayName: sv('Susanne Menauer (Admin)'),
      praxisId: sv(praxisIds[0]), praxisIds: av(praxisIds),
      role: sv('admin'), createdAt: tv(new Date().toISOString()),
    }
  });
  console.log('  ✓ Admin hat Zugriff auf ' + praxisIds.length + ' Standorte');

  console.log('');
  console.log('═══════════════════════════════════════════');
  console.log('FERTIG!');
  console.log('═══════════════════════════════════════════');
}

main().catch(err => { console.error('FEHLER:', err); process.exit(1); });
" 2>&1

echo ""
echo "═══════════════════════════════════════════"
echo "  LOGIN-DATEN:"
echo "═══════════════════════════════════════════"
echo ""
echo "  Admin (alle 3 Standorte):"
echo "    E-Mail:   admin@logo-menauer.de"
echo "    Passwort: LogoMenauer2026!"
echo ""
echo "  Weil der Stadt:"
echo "    E-Mail:   weil@logo-menauer.de"
echo "    Passwort: WeilDerStadt2026!"
echo ""
echo "  Ditzingen:"
echo "    E-Mail:   ditzingen@logo-menauer.de"
echo "    Passwort: Ditzingen2026!"
echo ""
echo "  Vaihingen/Enz:"
echo "    E-Mail:   vaihingen@logo-menauer.de"
echo "    Passwort: Vaihingen2026!"
echo ""
