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
