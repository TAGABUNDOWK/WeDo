const functions = require('firebase-functions/v1');
const { initializeApp } = require('firebase-admin/app');
const { getFirestore } = require('firebase-admin/firestore');

initializeApp();
const db = getFirestore();

async function cleanupUserDataByUid(uid) {
  const batch = db.batch();

  batch.delete(db.collection('users').doc(uid));

  const friendsSnap = await db
    .collection('friends')
    .where('userIds', 'array-contains', uid)
    .get();
  friendsSnap.docs.forEach((d) => batch.delete(db.collection('friends').doc(d.id)));

  await batch.commit();
}

exports.cleanupUserData = functions.auth.user().onDelete((user) =>
  cleanupUserDataByUid(user.uid)
);

// ──────────────────── Session Cleanup (runs every 6 hours) ────────────────────

async function cleanupExpiredSessions() {
  const now = new Date();
  const sessionsRef = db.collection('sessions');
  const expiredSnap = await sessionsRef
    .where('expiresAt', '<=', now)
    .limit(100)
    .get();

  if (expiredSnap.empty) return;

  const batch = db.batch();

  for (const sessionDoc of expiredSnap.docs) {
    // Delete all participants subcollection docs
    const participantsSnap = await sessionDoc.ref.collection('participants').get();
    participantsSnap.docs.forEach((pDoc) => batch.delete(pDoc.ref));
    // Delete the session document itself
    batch.delete(sessionDoc.ref);
  }

  await batch.commit();
  console.log(`Cleaned up ${expiredSnap.size} expired sessions`);
}

exports.scheduledSessionCleanup = functions.pubsub
  .schedule('every 6 hours')
  .onRun(async (context) => {
    await cleanupExpiredSessions();
  });
