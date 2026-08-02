const admin = require('firebase-admin');
admin.initializeApp({ credential: admin.credential.applicationDefault() });
const db = admin.firestore();

const BASE32 = '0123456789bcdefghjkmnpqrstuvwxyz';

function geohashEncode(lat, lng, precision = 5) {
  let latI = [-90, 90], lngI = [-180, 180], hash = 0, bits = 0, even = true;
  const result = [];
  while (result.length < precision) {
    if (even) {
      const mid = (lngI[0] + lngI[1]) / 2;
      if (lng >= mid) { hash = (hash << 1) | 1; lngI[0] = mid; }
      else { hash <<= 1; lngI[1] = mid; }
    } else {
      const mid = (latI[0] + latI[1]) / 2;
      if (lat >= mid) { hash = (hash << 1) | 1; latI[0] = mid; }
      else { hash <<= 1; latI[1] = mid; }
    }
    even = !even;
    bits++;
    if (bits === 5) { result.push(BASE32[hash]); bits = 0; hash = 0; }
  }
  return result.join('');
}

// base: tester1 at Cebu (10.3156983, 123.8854)
const users = [
  { username: 'suman',     lat: 10.325,  lng: 123.885,  note: '~1 km north' },
  { username: 'arvir_jay', lat: 10.3607, lng: 123.8854, note: '~5 km north' },
  { username: 'marvz02',   lat: 10.4507, lng: 123.8854, note: '~15 km north' },
];

(async () => {
  for (const u of users) {
    const snap = await db.collection('users').where('username', '==', u.username).get();
    if (snap.empty) { console.log('NOT FOUND', u.username); continue; }
    const ref = snap.docs[0].ref;
    await ref.set({
      latitude: u.lat,
      longitude: u.lng,
      geohash: geohashEncode(u.lat, u.lng, 5),
      last_location_at: new Date().toISOString(),
    }, { merge: true });
    console.log('updated', u.username, u.note, '->', u.lat, u.lng, geohashEncode(u.lat, u.lng, 5));
  }
  console.log('DONE');
})();
