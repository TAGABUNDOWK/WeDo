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
    const { userId, code } = req.body;

    if (!userId || !code) {
      return res.status(400).json({ error: "userId and code are required" });
    }

    const otpDoc = await db.collection("email_otps").doc(userId).get();

    if (!otpDoc.exists) {
      return res.status(400).json({ error: "No OTP found. Please request a new code." });
    }

    const otpData = otpDoc.data();

    if (otpData.used) {
      return res.status(400).json({ error: "This code has already been used. Please request a new code." });
    }

    const expiresAt = new Date(otpData.expires_at);
    if (new Date() > expiresAt) {
      return res.status(400).json({ error: "This code has expired. Please request a new code." });
    }

    if (otpData.code !== code) {
      return res.status(400).json({ error: "Invalid code. Please try again." });
    }

    await db.collection("email_otps").doc(userId).update({ used: true });

    await db.collection("users").doc(userId).update({ is_email_verified: true });

    return res.status(200).json({ success: true, message: "Email verified successfully" });
  } catch (error) {
    console.error("verifyOTP error:", error);
    return res.status(500).json({ error: "Failed to verify OTP" });
  }
};
