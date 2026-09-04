/**
 * TEST 10 — Hesap, rol ve onay kurallari.
 *
 * Kayit ekranindan ulasilan yetki yukseltmelerini kapatan kurallari sinar:
 *
 *   • users belgesine "role: club" yazip etkinlik olusturmak
 *   • kulubun kendi belgesine "clubStatus: approved" yazip onay kapisini atlamasi
 *   • engellenmis hesabin "banned" bayragini temizlemesi ya da kaydini silip
 *     yeniden kaydolarak engeli asmasi
 *
 * Ayrica mesru akislarin (ilk kayit, ikinci rol ekleme, profil duzenleme,
 * alanlari eksik ESKI belgeler) bozulmadigini dogrular.
 *
 * Kurallar dogrudan ASIL dosyadan okunur (Desktop/REGIPASS/firestore.rules),
 * bu klasordeki kopyadan degil.
 *
 * Calistirma:
 *   cd tool/loadtest/rules-env && firebase emulators:start --only firestore --project regipass-rules-check
 *   node tool/loadtest/10-hesap-rolleri.mjs
 */
import { readFileSync } from "node:fs";
import {
  initializeTestEnvironment,
  assertSucceeds,
  assertFails,
} from "@firebase/rules-unit-testing";
import {
  doc,
  setDoc,
  updateDoc,
  deleteDoc,
  serverTimestamp,
} from "firebase/firestore";

const RULES = "C:/Users/5sana/Desktop/REG\u0130PASS/firestore.rules";

const env = await initializeTestEnvironment({
  projectId: "regipass-rules-check",
  firestore: {
    rules: readFileSync(RULES, "utf8"),
    host: "127.0.0.1",
    port: 8733,
  },
});

let pass = 0;
let fail = 0;
async function check(name, fn) {
  try {
    await fn();
    pass++;
    console.log("  OK   " + name);
  } catch (e) {
    fail++;
    console.log("  FAIL " + name + "\n       " + (e.message || e));
  }
}

async function seed(fn) {
  await env.withSecurityRulesDisabled(async (ctx) => fn(ctx.firestore()));
}

const as = (uid) => env.authenticatedContext(uid).firestore();

await env.clearFirestore();

// ── Kurulum ────────────────────────────────────────────────────────────
await seed(async (db) => {
  // Onayli kulup
  await setDoc(doc(db, "club_profiles/club1"), {
    uid: "club1", onboardingCompleted: true, clubStatus: "approved",
    clubName: "Kulup 1", phone: "+905550000001", phoneVerified: false,
  });
  await setDoc(doc(db, "users/club1"), {
    uid: "club1", role: "club", lastRole: "club",
    roles: { club: true }, clubStatus: "approved",
  });

  // Onay bekleyen kulup
  await setDoc(doc(db, "club_profiles/club2"), {
    uid: "club2", onboardingCompleted: true, clubStatus: "pending_review",
    clubName: "Kulup 2", phone: "+905550000002", phoneVerified: false,
  });
  await setDoc(doc(db, "users/club2"), {
    uid: "club2", role: "club", lastRole: "club", roles: { club: true },
    clubStatus: "pending_review",
  });

  // Ogrenci — users belgesinde KENDINI kulup ilan etmis
  await setDoc(doc(db, "student_profiles/stu1"), {
    uid: "stu1", onboardingCompleted: true, phoneVerified: false,
    phone: "+905550000003", firstName: "A", lastName: "B",
  });
  await setDoc(doc(db, "users/stu1"), {
    uid: "stu1", role: "club", lastRole: "club",
    roles: { student: true, club: true },
  });

  // Engellenmis ogrenci
  await setDoc(doc(db, "student_profiles/stu2"), {
    uid: "stu2", onboardingCompleted: true, phoneVerified: false,
    phone: "+905550000004", banned: true,
  });
  await setDoc(doc(db, "users/stu2"), { uid: "stu2", role: "student", banned: true });

  // Engellenmis kulup
  await setDoc(doc(db, "club_profiles/club3"), {
    uid: "club3", onboardingCompleted: true, clubStatus: "banned",
    clubName: "Kulup 3", phone: "+905550000005", phoneVerified: false,
  });
});

const eventPayload = (clubId) => ({
  clubId, title: "Etkinlik", hiddenGlobally: false, quota: 10,
  createdAt: serverTimestamp(),
});

console.log("\n── Yetki yukseltme ───────────────────────────────────────");

await check("beyanla kulup olan ogrenci etkinlik OLUSTURAMAZ", () =>
  assertFails(setDoc(doc(as("stu1"), "events/e1"), eventPayload("stu1"))));

await check("onay bekleyen kulup etkinlik OLUSTURAMAZ", () =>
  assertFails(setDoc(doc(as("club2"), "events/e2"), eventPayload("club2"))));

await check("onayli kulup etkinlik olusturabilir", () =>
  assertSucceeds(setDoc(doc(as("club1"), "events/e3"), eventPayload("club1"))));

console.log("\n── Kendini onaylama / engel kaldirma ─────────────────────");

await check("kulup kendini ONAYLAYAMAZ (club_profiles)", () =>
  assertFails(updateDoc(doc(as("club2"), "club_profiles/club2"), { clubStatus: "approved" })));

await check("kulup users belgesine approved YAZAMAZ", () =>
  assertFails(updateDoc(doc(as("club2"), "users/club2"), { clubStatus: "approved" })));

await check("kulup belgelerini incelemeye gonderebilir (pending_review)", () =>
  assertSucceeds(updateDoc(doc(as("club1"), "club_profiles/club1"), {
    clubStatus: "pending_review", documents: { a: "x" },
  })));

await check("engellenmis ogrenci banned bayragini TEMIZLEYEMEZ", () =>
  assertFails(updateDoc(doc(as("stu2"), "student_profiles/stu2"), { banned: false })));

await check("engellenmis ogrenci users banned bayragini TEMIZLEYEMEZ", () =>
  assertFails(updateDoc(doc(as("stu2"), "users/stu2"), { banned: false })));

await check("engellenmis ogrenci profilini SILEMEZ", () =>
  assertFails(deleteDoc(doc(as("stu2"), "student_profiles/stu2"))));

await check("engellenmis kulup profilini SILEMEZ", () =>
  assertFails(deleteDoc(doc(as("club3"), "club_profiles/club3"))));

console.log("\n── Gercek akislar bozulmadi mi ───────────────────────────");

await check("yeni ogrenci kaydi (ilk onboarding)", () =>
  assertSucceeds(Promise.all([
    setDoc(doc(as("new1"), "student_profiles/new1"), {
      uid: "new1", role: "student", onboardingCompleted: true,
      phone: "+905550000010", phoneVerified: false, firstName: "C", lastName: "D",
    }),
    setDoc(doc(as("new1"), "users/new1"), {
      uid: "new1", role: "student", lastRole: "student",
      roles: { student: true }, onboardingCompleted: true,
    }),
  ])));

await check("yeni kulup kaydi (documents_pending)", () =>
  assertSucceeds(Promise.all([
    setDoc(doc(as("new2"), "club_profiles/new2"), {
      uid: "new2", role: "club", onboardingCompleted: true,
      clubStatus: "documents_pending", clubName: "Yeni",
      phone: "+905550000011", phoneVerified: false,
    }),
    setDoc(doc(as("new2"), "users/new2"), {
      uid: "new2", role: "club", lastRole: "club",
      roles: { club: true }, clubStatus: "documents_pending",
    }),
  ])));

await check("kulup hesabina IKINCI rol (ogrenci) eklenebilir", () =>
  assertSucceeds(Promise.all([
    setDoc(doc(as("club1"), "student_profiles/club1"), {
      uid: "club1", role: "student", onboardingCompleted: true,
      phone: "+905550000001", phoneVerified: false, firstName: "E", lastName: "F",
    }),
    setDoc(doc(as("club1"), "users/club1"), {
      uid: "club1", role: "student", lastRole: "student",
      roles: { club: true, student: true }, clubStatus: "approved",
    }, { merge: true }),
  ])));

await check("onayli kulup profil bilgilerini duzenleyebilir", () =>
  assertSucceeds(updateDoc(doc(as("club1"), "club_profiles/club1"), {
    clubName: "Kulup 1 (yeni ad)",
  })));

await check("onayli kulup users belgesini tazeleyebilir", () =>
  assertSucceeds(updateDoc(doc(as("club1"), "users/club1"), {
    lastLoginAt: serverTimestamp(),
  })));

console.log("-- Eski (alani eksik) belgeler --");

await seed(async (db) => {
  // clubStatus alani hic olmayan eski kulup kaydi
  await setDoc(doc(db, "club_profiles/old1"), {
    uid: "old1", onboardingCompleted: true, clubName: "Eski Kulup",
    phone: "+905550000020", phoneVerified: false,
  });
  await setDoc(doc(db, "users/old1"), { uid: "old1", role: "club" });
  // alanlarin hicbiri olmayan bos kayit
  await setDoc(doc(db, "club_profiles/old2"), { uid: "old2" });
});

await check("clubStatus'u olmayan eski kulup etkinlik OLUSTURAMAZ", () =>
  assertFails(setDoc(doc(as("old1"), "events/e9"), eventPayload("old1"))));

await check("clubStatus'u olmayan eski kulup profilini duzenleyebilir", () =>
  assertSucceeds(updateDoc(doc(as("old1"), "club_profiles/old1"), { clubName: "Eski Kulup 2" })));

await check("alanlari eksik kayit kural HATASI vermez (silinebilir)", () =>
  assertSucceeds(deleteDoc(doc(as("old2"), "club_profiles/old2"))));

await env.cleanup();
console.log("\nSonuc: " + pass + " gecti, " + fail + " kaldi");
process.exit(fail === 0 ? 0 : 1);
