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

// ──────────────────── Session Cleanup (runs every 2 days) ────────────────────

async function cleanupExpiredSessions() {
  const now = new Date();
  const sessionsRef = db.collection('sessions');
  const expiredSnap = await sessionsRef
    .where('deleteAfter', '<=', now)
    .limit(100)
    .get();

  if (expiredSnap.empty) return;

  const batch = db.batch();

  for (const sessionDoc of expiredSnap.docs) {
    // Delete all participants subcollection docs
    const participantsSnap = await sessionDoc.ref.collection('participants').get();
    participantsSnap.docs.forEach((pDoc) => batch.delete(pDoc.ref));
    // Delete the session document itself (safety net — TTL should also handle this)
    batch.delete(sessionDoc.ref);
  }

  await batch.commit();
  console.log(`Cleaned up ${expiredSnap.size} expired sessions`);
}

exports.scheduledSessionCleanup = functions.pubsub
  .schedule('0 0 */2 * *')
  .timeZone('Asia/Manila')
  .onRun(async (context) => {
    await cleanupExpiredSessions();
  });

// ──────────────────── Session Cancelled Notification (sends FCM when session is cancelled) ────────────────────

exports.onSessionCancelled = functions.firestore
  .document('sessions/{sessionId}')
  .onUpdate(async (change, context) => {
    const before = change.before.data();
    const after = change.after.data();

    // Only trigger on status changing TO 'cancelled'
    if (before.status === after.status) return;
    if (after.status !== 'cancelled') return;

    const sessionId = context.params.sessionId;
    const hostId = after.hostId;
    const topic = after.topic || 'PickFight';
    const invitedUserIds = after.invitedUserIds || [];
    const participantUids = after.participantUids || [];

    // Combine invited + participant UIDs (excluding host)
    const recipientUids = [...new Set([...invitedUserIds, ...participantUids])]
      .filter(uid => uid !== hostId);

    if (recipientUids.length === 0) return;

    // Get host name for notification
    const hostDoc = await db.collection('users').doc(hostId).get();
    const hostName = hostDoc.data()?.display_name || hostDoc.data()?.displayName || 'Host';

    // Gather FCM tokens
    const tokens = [];
    for (const uid of recipientUids) {
      const userDoc = await db.collection('users').doc(uid).get();
      const token = userDoc.data()?.fcm_token;
      if (token) tokens.push(token);
    }

    if (tokens.length === 0) return;

    const { getMessaging } = require('firebase-admin/messaging');
    const messaging = getMessaging();

    const results = await messaging.sendEachForMulticast({
      tokens,
      data: {
        sessionId,
        type: 'session_cancelled',
      },
      notification: {
        title: 'PickFight Cancelled',
        body: `${hostName} cancelled the PickFight: "${topic}"`,
      },
      android: { priority: 'high' },
    });

    console.log(`Session cancel notification sent to ${tokens.length} devices, ${results.successCount} succeeded`);
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

// ──────────────────── Call Timeout (auto-end unanswered calls after 60s) ────────────────────

async function timeoutUnansweredCalls() {
  const now = new Date();
  const cutoff = new Date(now.getTime() - 60 * 1000);

  const staleCalls = await db.collection('calls')
    .where('status', '==', 'ringing')
    .where('createdAt', '<=', cutoff)
    .limit(50)
    .get();

  if (staleCalls.empty) return;

  const batch = db.batch();
  for (const doc of staleCalls.docs) {
    batch.update(doc.ref, {
      status: 'ended',
      endedAt: new Date(),
    });
  }
  await batch.commit();
  console.log(`Timed out ${staleCalls.size} unanswered calls`);
}

exports.scheduledCallTimeout = functions.pubsub
  .schedule('every 1 minutes')
  .timeZone('Asia/Manila')
  .onRun(async (context) => {
    await timeoutUnansweredCalls();
  });

// ──────────────────── Poll Vote Aggregation ────────────────────

async function aggregatePollVotes(pollRef) {
  const pollSnap = await pollRef.get();
  if (!pollSnap.exists) return;
  const pollData = pollSnap.data();

  const votesSnap = await pollRef.collection('votes').get();
  const results = {};
  (pollData.options || []).forEach((opt) => { results[opt] = 0; });
  let totalVoters = 0;

  votesSnap.docs.forEach((voteDoc) => {
    const voteData = voteDoc.data();
    const option = voteData.option;
    if (option && results.hasOwnProperty(option)) {
      results[option]++;
      totalVoters++;
    }
  });

  results.totalVoters = totalVoters;

  await pollRef.update({ results });
  console.log(`Aggregated ${totalVoters} votes for poll ${pollRef.id}`);
}

exports.onGroupPollVoteCreated = functions.firestore
  .document('group_chats/{groupId}/polls/{pollId}/votes/{voteId}')
  .onWrite(async (change, context) => {
    const pollRef = db
      .collection('group_chats').doc(context.params.groupId)
      .collection('polls').doc(context.params.pollId);
    await aggregatePollVotes(pollRef);
  });

exports.onDirectPollVoteCreated = functions.firestore
  .document('direct_chats/{chatId}/polls/{pollId}/votes/{voteId}')
  .onWrite(async (change, context) => {
    const pollRef = db
      .collection('direct_chats').doc(context.params.chatId)
      .collection('polls').doc(context.params.pollId);
    await aggregatePollVotes(pollRef);
  });

// ──────────────────── Event & Poll Notifications ────────────────────

async function getChatMemberTokens(members, excludeUid) {
  const tokens = [];
  for (const uid of members) {
    if (uid === excludeUid) continue;
    const userDoc = await db.collection('users').doc(uid).get();
    const token = userDoc.data()?.fcm_token;
    if (token) tokens.push(token);
  }
  return tokens;
}

exports.onGroupEventCreated = functions.firestore
  .document('group_chats/{groupId}/events/{eventId}')
  .onCreate(async (snap, context) => {
    const eventData = snap.data();
    if (!eventData) return;

    const groupDoc = await db.collection('group_chats').doc(context.params.groupId).get();
    const members = groupDoc.data()?.members || [];
    const tokens = await getChatMemberTokens(members, eventData.createdBy);
    if (tokens.length === 0) return;

    const creatorDoc = await db.collection('users').doc(eventData.createdBy).get();
    const creatorName = creatorDoc.data()?.display_name || creatorDoc.data()?.displayName || 'Someone';

    const { getMessaging } = require('firebase-admin/messaging');
    const messaging = getMessaging();

    await messaging.sendEachForMulticast({
      tokens,
      data: { eventId: context.params.eventId, groupId: context.params.groupId },
      notification: {
        title: 'New Event',
        body: `${creatorName} created "${eventData.title}"`,
      },
      android: { priority: 'normal' },
    });
  });

exports.onDirectEventCreated = functions.firestore
  .document('direct_chats/{chatId}/events/{eventId}')
  .onCreate(async (snap, context) => {
    const eventData = snap.data();
    if (!eventData) return;

    const chatDoc = await db.collection('direct_chats').doc(context.params.chatId).get();
    const members = chatDoc.data()?.members || [];
    const tokens = await getChatMemberTokens(members, eventData.createdBy);
    if (tokens.length === 0) return;

    const creatorDoc = await db.collection('users').doc(eventData.createdBy).get();
    const creatorName = creatorDoc.data()?.display_name || creatorDoc.data()?.displayName || 'Someone';

    const { getMessaging } = require('firebase-admin/messaging');
    const messaging = getMessaging();

    await messaging.sendEachForMulticast({
      tokens,
      data: { eventId: context.params.eventId, chatId: context.params.chatId },
      notification: {
        title: 'New Event',
        body: `${creatorName} created "${eventData.title}"`,
      },
      android: { priority: 'normal' },
    });
  });

exports.onGroupPollCreated = functions.firestore
  .document('group_chats/{groupId}/polls/{pollId}')
  .onCreate(async (snap, context) => {
    const pollData = snap.data();
    if (!pollData) return;

    const groupDoc = await db.collection('group_chats').doc(context.params.groupId).get();
    const members = groupDoc.data()?.members || [];
    const tokens = await getChatMemberTokens(members, pollData.createdBy);
    if (tokens.length === 0) return;

    const creatorDoc = await db.collection('users').doc(pollData.createdBy).get();
    const creatorName = pollData.anonymous
      ? 'Someone'
      : (creatorDoc.data()?.display_name || creatorDoc.data()?.displayName || 'Someone');

    const { getMessaging } = require('firebase-admin/messaging');
    const messaging = getMessaging();

    await messaging.sendEachForMulticast({
      tokens,
      data: { pollId: context.params.pollId, groupId: context.params.groupId },
      notification: {
        title: pollData.anonymous ? 'New Secret Vote' : 'New Poll',
        body: `${creatorName} asks "${pollData.question}"`,
      },
      android: { priority: 'normal' },
    });
  });

exports.onDirectPollCreated = functions.firestore
  .document('direct_chats/{chatId}/polls/{pollId}')
  .onCreate(async (snap, context) => {
    const pollData = snap.data();
    if (!pollData) return;

    const chatDoc = await db.collection('direct_chats').doc(context.params.chatId).get();
    const members = chatDoc.data()?.members || [];
    const tokens = await getChatMemberTokens(members, pollData.createdBy);
    if (tokens.length === 0) return;

    const creatorDoc = await db.collection('users').doc(pollData.createdBy).get();
    const creatorName = pollData.anonymous
      ? 'Someone'
      : (creatorDoc.data()?.display_name || creatorDoc.data()?.displayName || 'Someone');

    const { getMessaging } = require('firebase-admin/messaging');
    const messaging = getMessaging();

    await messaging.sendEachForMulticast({
      tokens,
      data: { pollId: context.params.pollId, chatId: context.params.chatId },
      notification: {
        title: pollData.anonymous ? 'New Secret Vote' : 'New Poll',
        body: `${creatorName} asks "${pollData.question}"`,
      },
      android: { priority: 'normal' },
    });
  });

// ──────────────────── Event Reminder (runs every 5 minutes) ────────────────────

async function sendEventReminders() {
  const now = new Date();
  const in15Min = new Date(now.getTime() + 15 * 60 * 1000);
  const { getMessaging } = require('firebase-admin/messaging');
  const messaging = getMessaging();

  // Check group chats
  const groupChatsSnap = await db.collection('group_chats').get();
  for (const chatDoc of groupChatsSnap.docs) {
    const eventsSnap = await chatDoc.ref.collection('events')
      .where('date', '>', now)
      .where('date', '<=', in15Min)
      .where('reminderSent', '!=', true)
      .get();

    for (const eventDoc of eventsSnap.docs) {
      const eventData = eventDoc.data();
      await sendReminderForEvent(eventDoc.ref, eventData, chatDoc.id, 'group', messaging);
    }
  }

  // Check direct chats
  const directChatsSnap = await db.collection('direct_chats').get();
  for (const chatDoc of directChatsSnap.docs) {
    const eventsSnap = await chatDoc.ref.collection('events')
      .where('date', '>', now)
      .where('date', '<=', in15Min)
      .where('reminderSent', '!=', true)
      .get();

    for (const eventDoc of eventsSnap.docs) {
      const eventData = eventDoc.data();
      await sendReminderForEvent(eventDoc.ref, eventData, chatDoc.id, 'direct', messaging);
    }
  }
}

async function sendReminderForEvent(eventRef, eventData, chatId, chatType, messaging) {
  const rsvps = eventData.rsvps || {};
  const yesMaybeUids = Object.entries(rsvps)
    .filter(([_, response]) => response === 'yes' || response === 'maybe')
    .map(([uid]) => uid);

  if (yesMaybeUids.length === 0) {
    await eventRef.update({ reminderSent: true });
    return;
  }

  const tokens = [];
  for (const uid of yesMaybeUids) {
    const userDoc = await db.collection('users').doc(uid).get();
    const token = userDoc.data()?.fcm_token;
    if (token) tokens.push(token);
  }

  if (tokens.length === 0) {
    await eventRef.update({ reminderSent: true });
    return;
  }

  const eventDate = eventData.date?.toDate?.() || new Date(eventData.date);
  const diffMin = Math.max(0, Math.round((eventDate - new Date()) / 60000));
  const timeText = diffMin <= 1 ? 'starting now' : `in ${diffMin} minutes`;

  const chatPath = chatType === 'group' ? `group_chats/${chatId}` : `direct_chats/${chatId}`;

  await messaging.sendEachForMulticast({
    tokens,
    data: {
      eventId: eventRef.id,
      [chatType === 'group' ? 'groupId' : 'chatId']: chatId,
    },
    notification: {
      title: 'Event Reminder',
      body: `"${eventData.title}" starts ${timeText}`,
    },
    android: { priority: 'high' },
  });

  await eventRef.update({ reminderSent: true });
  console.log(`Reminder sent for event ${eventRef.id} to ${tokens.length} devices`);
}

exports.scheduledEventReminders = functions.pubsub
  .schedule('every 5 minutes')
  .timeZone('Asia/Manila')
  .onRun(async (context) => {
    await sendEventReminders();
  });

// ──────────────────── TriRace Cleanup (runs every 2 days) ────────────────────

async function cleanupExpiredTriRaces() {
  const now = new Date();
  const triRacesRef = db.collection('triRaces');
  const expiredSnap = await triRacesRef
    .where('status', 'in', ['finished', 'cancelled'])
    .limit(100)
    .get();

  if (expiredSnap.empty) return;

  const batch = db.batch();
  let count = 0;

  for (const raceDoc of expiredSnap.docs) {
    const data = raceDoc.data();
    const createdAt = data.createdAt?.toDate?.() || new Date(data.createdAt);
    const ageMs = now.getTime() - createdAt.getTime();
    const ageDays = ageMs / (1000 * 60 * 60 * 24);

    // Delete after 30 days
    if (ageDays < 30) continue;

    const participantsSnap = await raceDoc.ref.collection('participants').get();
    participantsSnap.docs.forEach((pDoc) => batch.delete(pDoc.ref));
    batch.delete(raceDoc.ref);
    count++;
  }

  if (count > 0) {
    await batch.commit();
    console.log(`Cleaned up ${count} expired TriRaces`);
  }
}

exports.scheduledTriRaceCleanup = functions.pubsub
  .schedule('0 0 */2 * *')
  .timeZone('Asia/Manila')
  .onRun(async (context) => {
    await cleanupExpiredTriRaces();
  });

// ──────────────────── TriRace Cancelled Notification ────────────────────

exports.onTriRaceCancelled = functions.firestore
  .document('triRaces/{raceId}')
  .onUpdate(async (change, context) => {
    const before = change.before.data();
    const after = change.after.data();

    if (before.status === after.status) return;
    if (after.status !== 'cancelled') return;

    const raceId = context.params.raceId;
    const hostId = after.hostId;
    const invitedUserIds = after.invitedUserIds || [];
    const participantUids = after.participantUids || [];

    const recipientUids = [...new Set([...invitedUserIds, ...participantUids])]
      .filter(uid => uid !== hostId);

    if (recipientUids.length === 0) return;

    const hostDoc = await db.collection('users').doc(hostId).get();
    const hostName = hostDoc.data()?.display_name || hostDoc.data()?.displayName || 'Host';

    const tokens = [];
    for (const uid of recipientUids) {
      const userDoc = await db.collection('users').doc(uid).get();
      const token = userDoc.data()?.fcm_token;
      if (token) tokens.push(token);
    }

    if (tokens.length === 0) return;

    const { getMessaging } = require('firebase-admin/messaging');
    const messaging = getMessaging();

    const results = await messaging.sendEachForMulticast({
      tokens,
      data: {
        raceId,
        type: 'tri_race_cancelled',
      },
      notification: {
        title: 'TriRace Cancelled',
        body: `${hostName} cancelled the TriRace`,
      },
      android: { priority: 'high' },
    });

    console.log(`TriRace cancel notification sent to ${tokens.length} devices, ${results.successCount} succeeded`);
  });
