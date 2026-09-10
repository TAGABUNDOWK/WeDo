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
const auth = admin.auth();

module.exports = async function handler(req, res) {
  res.setHeader("Access-Control-Allow-Origin", "*");
  res.setHeader("Access-Control-Allow-Methods", "POST, OPTIONS");
  res.setHeader("Access-Control-Allow-Headers", "Content-Type");

  if (req.method === "OPTIONS") {
    return res.status(200).end();
  }

  if (req.method !== "POST") {
    return res.status(405).json({ error: "Method not allowed" });
  }

  try {
    const { userId, newEmail } = req.body;

    if (!userId || !newEmail) {
      return res.status(400).json({ error: "userId and newEmail are required" });
    }

    await auth.updateUser(userId, { email: newEmail });

    await db.collection("users").doc(userId).update({ email: newEmail });

    return res.status(200).json({ success: true, message: "Email updated successfully" });
  } catch (error) {
    console.error("update-email error:", error);
    return res.status(500).json({ error: error.message || "Failed to update email" });
  }
};
