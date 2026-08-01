const { cleanupUserData } = require('./index.js');
const admin = require('firebase-admin');

const TEST_UID = 'test-temp-uid';

async function main() {
  const db = admin.firestore();
  const batch = db.batch();
  batch.set(db.collection('users').doc(TEST_UID), { username: 'testtemp', displayName: 'Test Temp' });
  batch.set(db.collection('friends').doc('friend1_' + TEST_UID), {
    userIds: ['friend1', TEST_UID], status: 'accepted',
  });
  batch.set(db.collection('friends').doc(TEST_UID + '_friend2'), {
    userIds: [TEST_UID, 'friend2'], status: 'pending', requestedBy: TEST_UID,
  });
  await batch.commit();
  console.log('seeded users/test-temp-uid + 2 friend docs');

  const before = await db.collection('users').get();
  console.log('users count before:', before.size);
  const realBefore = await db.collection('users').where('username', 'in', ['tester1', 'suman', 'arvir_jay', 'marvz02']).get();
  console.log('real users present before:', realBefore.size);

  await cleanupUserData.run({ uid: TEST_UID }, {});

  const userDoc = await db.collection('users').doc(TEST_UID).get();
  const friends = await db.collection('friends').where('userIds', 'array-contains', TEST_UID).get();
  console.log('test user doc exists after:', userDoc.exists);
  console.log('friend docs referencing uid after:', friends.size);

  const after = await db.collection('users').get();
  console.log('users count after:', after.size);
  const realAfter = await db.collection('users').where('username', 'in', ['tester1', 'suman', 'arvir_jay', 'marvz02']).get();
  console.log('real users present after:', realAfter.size);

  const ok = !userDoc.exists && friends.size === 0 && realBefore.size === 4 && realAfter.size === 4;
  console.log(ok ? 'PASS' : 'FAIL');
  process.exit(ok ? 0 : 1);
}

main().catch((e) => {
  console.error(e);
  process.exit(1);
});