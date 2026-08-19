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

// ──────────────────── Call Notification (sends FCM when a call is created) ────────────────────

exports.onCallCreated = functions.firestore
  .document('calls/{callId}')
  .onCreate(async (snap, context) => {
    const callData = snap.data();
    if (!callData) return;

    const createdBy = callData.createdBy;
    const members = callData.members || [];
    const type = callData.type || 'audio';

    const otherMembers = members.filter((uid) => uid !== createdBy);
    if (otherMembers.length === 0) return;

    const callerDoc = await db.collection('users').doc(createdBy).get();
    const callerName = callerDoc.data()?.display_name || callerDoc.data()?.displayName || 'Someone';

    const tokens = [];
    for (const uid of otherMembers) {
      const userDoc = await db.collection('users').doc(uid).get();
      const token = userDoc.data()?.fcm_token;
      if (token) tokens.push(token);
    }

    if (tokens.length === 0) return;

    const payload = {
      data: {
        callId: context.params.callId,
        callerName: callerName,
        callerUid: createdBy,
        type: type,
      },
      notification: {
        title: `Incoming ${type} call`,
        body: `${callerName} is calling you`,
      },
    };

    const { getMessaging } = require('firebase-admin/messaging');
    const messaging = getMessaging();

    const results = await messaging.sendEachForMulticast({
      tokens: tokens,
      data: payload.data,
      notification: payload.notification,
      android: {
        priority: 'high',
      },
    });

    console.log(`Call notification sent to ${tokens.length} devices, ${results.successCount} succeeded`);
  });
