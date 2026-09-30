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
    const { email, code, newPassword } = req.body;

    if (!email || !code || !newPassword) {
      return res.status(400).json({ error: "email, code, and newPassword are required" });
    }

    if (String(newPassword).length < 6) {
      return res.status(400).json({ error: "Password must be at least 6 characters" });
    }

    let user;
    try {
      user = await auth.getUserByEmail(email);
    } catch (e) {
      return res.status(404).json({ error: "No account found with this email." });
    }

    const userId = user.uid;
    const resetDoc = await db.collection("password_reset_otps").doc(userId).get();

    if (!resetDoc.exists) {
      return res.status(400).json({ error: "No reset code found. Please request a new code." });
    }

    const resetData = resetDoc.data();

    if (resetData.used) {
      return res.status(400).json({ error: "This code has already been used. Please request a new code." });
    }

    const expiresAt = new Date(resetData.expires_at);
    if (new Date() > expiresAt) {
      return res.status(400).json({ error: "This code has expired. Please request a new code." });
    }

    if (String(resetData.code) !== String(code)) {
      return res.status(400).json({ error: "Invalid code. Please try again." });
    }

    await auth.updateUser(userId, { password: newPassword });

    await db.collection("password_reset_otps").doc(userId).update({ used: true });

    return res.status(200).json({ success: true, message: "Password updated successfully" });
  } catch (error) {
    console.error("reset-password error:", error);
    return res.status(500).json({ error: error.message || "Failed to reset password" });
  }
};