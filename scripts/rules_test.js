/**
 * Security-Rules-Tests gegen den Firestore-Emulator.
 *
 * Prueft die Admin-Zugriffslogik (admins-Array am Praxis-Dokument):
 *  - Ein Admin sieht seinen Standort AUCH OHNE Eintrag in praxisIds
 *    (das war die Ursache des "Standort weg"-Vorfalls).
 *  - Mandantentrennung: fremde Praxis bleibt unlesbar.
 *
 * Start:  firebase emulators:exec --only firestore "node scripts/rules_test.js"
 */
const {
  initializeTestEnvironment,
  assertSucceeds,
  assertFails,
} = require('@firebase/rules-unit-testing');
const fs = require('fs');
const path = require('path');

const SUSANNE = 'susanne-uid';
const HAMDI = 'hamdi-uid';
const ENES = 'enes-uid';
const MITARBEITER = 'weil-user-uid';

const WEIL = 'praxis-weil';
const FREMD = 'praxis-fremd';

let passed = 0;
let failed = 0;
async function check(name, fn) {
  try {
    await fn();
    console.log(`  ✅ ${name}`);
    passed++;
  } catch (e) {
    console.log(`  ❌ ${name}\n       ${e.message.split('\n')[0]}`);
    failed++;
  }
}

(async () => {
  const testEnv = await initializeTestEnvironment({
    projectId: 'warteliste-rules-test',
    firestore: {
      rules: fs.readFileSync(path.join(__dirname, '..', 'firestore.rules'), 'utf8'),
      host: '127.0.0.1',
      port: 8080,
    },
  });

  // ---- Seed (ohne Rules) ----
  await testEnv.withSecurityRulesDisabled(async (ctx) => {
    const db = ctx.firestore();
    // Susanne: Admin, aber praxisIds enthaelt WEIL NICHT (der Vorfall!)
    await db.doc(`users/${SUSANNE}`).set({
      email: 'admin@logo-menauer.de', role: 'admin', praxisId: '', praxisIds: [],
    });
    await db.doc(`users/${HAMDI}`).set({
      email: 'h@hasi.de', role: 'admin', praxisId: WEIL, praxisIds: [WEIL],
    });
    await db.doc(`users/${ENES}`).set({
      email: 'enes@x.de', role: 'admin', praxisId: FREMD, praxisIds: [FREMD],
    });
    await db.doc(`users/${MITARBEITER}`).set({
      email: 'weil@logo-menauer.de', role: 'user', praxisId: WEIL, praxisIds: [WEIL],
    });
    // Praxis Weil: Susanne + Hamdi sind Admins (admins-Array)
    await db.doc(`praxen/${WEIL}`).set({
      name: 'Logopädie Weil', createdBy: HAMDI, admins: [HAMDI, SUSANNE],
    });
    await db.doc(`praxen/${WEIL}/patienten/p1`).set({ name: 'Testpatient' });
    // Fremde Praxis (anderer Mandant)
    await db.doc(`praxen/${FREMD}`).set({
      name: 'Enes', createdBy: ENES, admins: [ENES],
    });
    await db.doc(`praxen/${FREMD}/patienten/p9`).set({ name: 'Fremd' });
  });

  const susanne = testEnv.authenticatedContext(SUSANNE, { email: 'admin@logo-menauer.de' }).firestore();
  const enes = testEnv.authenticatedContext(ENES, { email: 'enes@x.de' }).firestore();
  const mitarbeiter = testEnv.authenticatedContext(MITARBEITER, { email: 'weil@logo-menauer.de' }).firestore();
  const anon = testEnv.unauthenticatedContext().firestore();

  console.log('\n── Kernfall: Admin ohne praxisIds-Eintrag ──');
  await check('Susanne liest Praxis Weil (nur via admins-Array)', () =>
    assertSucceeds(susanne.doc(`praxen/${WEIL}`).get()));
  await check('Susanne liest Patienten von Weil (canAccessPraxis)', () =>
    assertSucceeds(susanne.doc(`praxen/${WEIL}/patienten/p1`).get()));
  await check('Susanne: Query praxen where admins array-contains uid', () =>
    assertSucceeds(susanne.collection('praxen').where('admins', 'array-contains', SUSANNE).get()));
  await check('Susanne darf Praxis Weil bearbeiten (isPraxisAdminDoc)', () =>
    assertSucceeds(susanne.doc(`praxen/${WEIL}`).update({ telefon: '123' })));

  console.log('\n── Mandantentrennung ──');
  await check('Susanne kann FREMDE Praxis NICHT lesen', () =>
    assertFails(enes.doc(`praxen/${WEIL}`).get()));
  await check('Enes kann Weil-Patienten NICHT lesen', () =>
    assertFails(enes.doc(`praxen/${WEIL}/patienten/p1`).get()));
  await check('Susanne kann fremde Praxis NICHT lesen', () =>
    assertFails(susanne.doc(`praxen/${FREMD}`).get()));
  await check('Enes-Query liefert nur eigene (keine fremden admins)', () =>
    assertFails(enes.collection('praxen').where('admins', 'array-contains', SUSANNE).get()));

  console.log('\n── Phase 2: Mitarbeiter-Index (Anzeige) ──');
  await check('Susanne listet Mitarbeiter-Index ihres Standorts', () =>
    assertSucceeds(susanne.collection(`praxen/${WEIL}/mitarbeiter`).get()));
  await check('Mitarbeiter listet Index seines Standorts', () =>
    assertSucceeds(mitarbeiter.collection(`praxen/${WEIL}/mitarbeiter`).get()));
  await check('Mitarbeiter pflegt EIGENEN Index-Eintrag', () =>
    assertSucceeds(mitarbeiter.doc(`praxen/${WEIL}/mitarbeiter/${MITARBEITER}`)
      .set({ email: 'w@b.de', role: 'user' })));
  await check('Mitarbeiter darf FREMDEN Index-Eintrag NICHT schreiben', () =>
    assertFails(mitarbeiter.doc(`praxen/${WEIL}/mitarbeiter/${HAMDI}`)
      .set({ email: 'hack@x.de', role: 'admin' })));
  await check('Admin darf fremden Index-Eintrag loeschen', () =>
    assertSucceeds(susanne.doc(`praxen/${WEIL}/mitarbeiter/${MITARBEITER}`).delete()));
  await check('Enes darf Weil-Mitarbeiter-Index NICHT lesen', () =>
    assertFails(enes.collection(`praxen/${WEIL}/mitarbeiter`).get()));

  console.log('\n── Phase 2: Zugriffs-Verwaltung durch Admin ──');
  await check('Susanne liest Mitarbeiter-Doc ihres Standorts (single get)', () =>
    assertSucceeds(susanne.doc(`users/${MITARBEITER}`).get()));
  await check('Susanne entzieht Mitarbeiter den Standort-Zugriff', () =>
    assertSucceeds(susanne.doc(`users/${MITARBEITER}`).update({ praxisIds: [], praxisId: '' })));
  await check('Susanne gibt Standort-Zugriff zurueck', () =>
    assertSucceeds(susanne.doc(`users/${MITARBEITER}`).update({ praxisIds: [WEIL], praxisId: WEIL })));

  console.log('\n── Phase 2: Missbrauch muss scheitern ──');
  await check('Admin darf role NICHT aendern (keine Eskalation)', () =>
    assertFails(susanne.doc(`users/${MITARBEITER}`).update({ role: 'admin' })));
  await check('Admin darf email NICHT aendern', () =>
    assertFails(susanne.doc(`users/${MITARBEITER}`).update({ email: 'hack@x.de' })));
  await check('Admin darf KEINEN fremden Standort zuweisen', () =>
    assertFails(susanne.doc(`users/${MITARBEITER}`).update({ praxisIds: [WEIL, FREMD] })));
  await check('Enes darf Weil-Mitarbeiter NICHT lesen', () =>
    assertFails(enes.doc(`users/${MITARBEITER}`).get()));
  await check('Enes darf Weil-Mitarbeiter NICHT veraendern', () =>
    assertFails(enes.doc(`users/${MITARBEITER}`).update({ praxisIds: [FREMD] })));
  await check('Mitarbeiter darf fremdes User-Doc NICHT lesen', () =>
    assertFails(mitarbeiter.doc(`users/${SUSANNE}`).get()));
  await check('Mitarbeiter darf sich NICHT selbst zum Admin machen', () =>
    assertFails(mitarbeiter.doc(`users/${MITARBEITER}`).update({ role: 'admin' })));

  console.log('\n── Normale Mitarbeiter / Anonym ──');
  await check('Mitarbeiter liest seine Praxis via praxisIds', () =>
    assertSucceeds(mitarbeiter.doc(`praxen/${WEIL}`).get()));
  await check('Mitarbeiter ist KEIN Admin → darf Praxis nicht bearbeiten', () =>
    assertFails(mitarbeiter.doc(`praxen/${WEIL}`).update({ telefon: '999' })));
  await check('Anonym kann nichts lesen', () =>
    assertFails(anon.doc(`praxen/${WEIL}`).get()));

  await testEnv.cleanup();
  console.log(`\n${passed} bestanden, ${failed} fehlgeschlagen`);
  process.exit(failed ? 1 : 0);
})().catch((e) => {
  console.error('FATAL:', e);
  process.exit(1);
});
