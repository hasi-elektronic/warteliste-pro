/**
 * Migration: befuellt den Mitarbeiter-Index /praxen/{praxisId}/mitarbeiter/{uid}
 * aus users/{uid}.praxisIds.
 *
 * Warum: `users` kann client-seitig NICHT per Query gelesen werden — bei einer
 * Collection-Query (`list`) ist `resource` in den Firestore-Rules null, eine
 * datenabhaengige Regel ist dort nicht auswertbar. Der Index haengt dagegen nur
 * am Pfad (praxisId) und ist damit abfragbar.
 *
 * Quelle der Wahrheit fuer den ZUGRIFF bleibt users/{uid}.praxisIds —
 * dies ist nur der Index fuer die Anzeige der Mitarbeiter-Liste.
 *
 * Nutzung:
 *   node migrate_mitarbeiter_index.js           # Dry-Run
 *   node migrate_mitarbeiter_index.js --apply   # schreibt
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

  const praxisName = {};
  praxenSnap.forEach((d) => (praxisName[d.id] = d.data().name || d.id));

  // praxisId -> [{uid, email, role}]
  const byPraxis = {};
  usersSnap.forEach((d) => {
    const x = d.data();
    const ids = Array.isArray(x.praxisIds) ? x.praxisIds : [];
    for (const pid of ids) {
      (byPraxis[pid] = byPraxis[pid] || []).push({
        uid: d.id,
        email: x.email || '',
        displayName: x.displayName || '',
        role: x.role || 'user',
      });
    }
  });

  console.log(APPLY ? '=== APPLY ===\n' : '=== DRY-RUN (nichts wird geschrieben) ===\n');
  let total = 0;

  for (const [pid, members] of Object.entries(byPraxis)) {
    if (!praxisName[pid]) {
      console.log(`⚠️  Praxis ${pid} existiert nicht — ${members.length} Verweis(e) uebersprungen\n`);
      continue;
    }
    console.log(`▸ ${praxisName[pid]}  [${pid}] — ${members.length} Mitarbeiter`);
    for (const m of members) {
      console.log(`    • ${m.email} (${m.role})`);
      if (APPLY) {
        await db
          .collection('praxen').doc(pid)
          .collection('mitarbeiter').doc(m.uid)
          .set(
            {
              email: m.email,
              displayName: m.displayName,
              role: m.role,
              joinedAt: FieldValue.serverTimestamp(),
            },
            { merge: true },
          );
      }
      total++;
    }
    console.log('');
  }

  console.log(`${total} Index-Eintrag/Eintraege ${APPLY ? 'geschrieben' : 'zu schreiben'}.`);
  if (!APPLY && total) console.log('Zum Schreiben: node migrate_mitarbeiter_index.js --apply');
})()
  .then(() => process.exit(0))
  .catch((e) => {
    console.error('ERR:', e.message);
    process.exit(1);
  });
