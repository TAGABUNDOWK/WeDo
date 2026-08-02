const admin = require("firebase-admin");

if (!admin.apps.length) {
  admin.initializeApp({
    credential: admin.credential.cert({
      projectId: process.env.FIREBASE_PROJECT_ID,
      clientEmail: process.env.FIREBASE_CLIENT_EMAIL,
      privateKey: process.env.FIREBASE_PRIVATE_KEY?.replace(/\\n/g, "\n"),
    }),
  });
}

const db = admin.firestore();

function slugify(name) {
  const base = (name || "user")
    .toLowerCase()
    .replace(/[^a-z0-9]/g, "_")
    .replace(/_+/g, "_")
    .replace(/^_+|_+$/g, "");
  let username = base;
  if (username.length < 3) username = (username + "___").slice(0, 3);
  if (username.length > 20) username = username.slice(0, 20);
  return username;
}

async function main() {
  const snap = await db.collection("users").get();
  let updated = 0;
  const seen = new Set();

  for (const doc of snap.docs) {
    const data = doc.data();
    if (data.username && data.username_lower) continue;

    let username = slugify(data.display_name || "user");
    let candidate = username;
    let counter = 1;
    while (seen.has(candidate)) {
      const suffix = counter.toString();
      candidate = username.slice(0, 20 - suffix.length) + suffix;
      counter++;
    }
    seen.add(candidate);

    await doc.ref.update({
      username: candidate,
      username_lower: candidate,
    });
    updated++;
    console.log(`  -> ${doc.id}: @${candidate}`);
  }

  console.log(`\nDone. Updated ${updated} user(s).`);
}

main().catch((error) => {
  console.error("backfill failed:", error);
  process.exit(1);
});
