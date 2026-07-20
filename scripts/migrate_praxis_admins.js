/**
 * Migration: befuellt `admins` (UID-Array) auf allen /praxen Dokumenten.
 *
 * Regel:  admins = [createdBy]  ∪  { uid | users/{uid}.role == 'admin'
 *                                        && praxisId ∈ users/{uid}.praxisIds }
 *
 * Hintergrund: Admin-Zugriff haengt sonst allein an users/{uid}.praxisIds und
 * geht z.B. durch "Standort entfernen" unwiederbringlich verloren. Mit dem
 * admins-Array am Praxis-Dokument ist der Zugriff nicht mehr verlierbar.
 *
 * Nutzung:
 *   node migrate_praxis_admins.js           # Dry-Run (zeigt nur an)
 *   node migrate_praxis_admins.js --apply   # schreibt
 *
 * Voraussetzung: GOOGLE_APPLICATION_CREDENTIALS = Service-Account JSON.
 */
const { initializeApp, applicationDefault } = require('firebase-admin/app');
const { getFirestore, FieldValue } = require('firebase-admin/firestore');

const APPLY = process.argv.includes('--apply');

initializeApp({ credential: applicationDefault(), projectId: 'warteliste-pro' });
const db = getFirestore();

(async () => {
  const [praxenSnap, usersSnap] = await Promise.all([
    db.collection('praxen').get(),
    db.collection('users').get(),
  ]);

  // uid -> {email, role, praxisIds}
  const users = [];
  usersSnap.forEach((d) => {
    const x = d.data();
    users.push({
      uid: d.id,
      email: x.email || '',
      role: x.role || 'user',
      praxisIds: Array.isArray(x.praxisIds) ? x.praxisIds : [],
      praxisId: x.praxisId || '',
    });
  });

  const emailOf = (uid) => (users.find((u) => u.uid === uid) || {}).email || uid;

  console.log(APPLY ? '=== APPLY ===' : '=== DRY-RUN (nichts wird geschrieben) ===\n');
  let changed = 0;

  for (const doc of praxenSnap.docs) {
    const p = doc.data();
    const current = Array.isArray(p.admins) ? p.admins : [];

    const wanted = new Set();
    if (p.createdBy) wanted.add(p.createdBy);
    for (const u of users) {
      if (u.role !== 'admin') continue;
      if (u.praxisIds.includes(doc.id) || u.praxisId === doc.id) wanted.add(u.uid);
    }

    const toAdd = [...wanted].filter((uid) => !current.includes(uid));
    console.log(`▸ ${p.name || '(ohne Namen)'}  [${doc.id}]`);
    console.log(`    admins vorher : ${current.length ? current.map(emailOf).join(', ') : '(leer)'}`);
    console.log(`    admins nachher: ${[...new Set([...current, ...wanted])].map(emailOf).join(', ')}`);
    if (toAdd.length === 0) {
      console.log('    → keine Aenderung\n');
      continue;
    }
    changed++;
    if (APPLY) {
      await doc.ref.update({ admins: FieldValue.arrayUnion(...toAdd) });
      console.log(`    ✔ ${toAdd.length} Admin(s) hinzugefuegt\n`);
    } else {
      console.log(`    (würde ${toAdd.length} hinzufuegen)\n`);
    }
  }

  console.log(`\n${changed} Standort(e) ${APPLY ? 'aktualisiert' : 'zu aendern'}.`);
  if (!APPLY && changed) console.log('Zum Schreiben: node migrate_praxis_admins.js --apply');
})()
  .then(() => process.exit(0))
  .catch((e) => {
    console.error('ERR:', e.message);
    process.exit(1);
  });
