const admin = require("firebase-admin");
const Brevo = require("@getbrevo/brevo");

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
    const { userId, email, resend } = req.body;

    if (!userId || !email) {
      return res.status(400).json({ error: "userId and email are required" });
    }

    let code;
    let expiryMs;

    if (!resend) {
      const existing = await db.collection("email_otps").doc(userId).get();
      if (existing.exists) {
        const data = existing.data();
        const expiresAt = new Date(data.expires_at);
        if (!data.used && new Date() < expiresAt) {
          code = data.code;
          expiryMs = expiresAt.getTime() - Date.now();
          const apiInstance = new Brevo.TransactionalEmailsApi();
          apiInstance.setApiKey(Brevo.TransactionalEmailsApiApiKeys.apiKey, process.env.BREVO_API_KEY);

          const sendSmtpEmail = new Brevo.SendSmtpEmail();
          sendSmtpEmail.sender = {
            name: process.env.BREVO_SENDER_NAME || "WeDo",
            email: process.env.BREVO_SENDER_EMAIL,
          };
          sendSmtpEmail.to = [{ email: email }];
          sendSmtpEmail.subject = "WeDo - Email Verification Code";
          sendSmtpEmail.htmlContent = `
            <div style="font-family: Arial, sans-serif; max-width: 480px; margin: 0 auto; padding: 32px;">
              <h2 style="color: #1a73e8;">WeDo Email Verification</h2>
              <p>Your verification code is:</p>
              <div style="font-size: 32px; font-weight: bold; letter-spacing: 8px; color: #333; background: #f5f5f5; padding: 16px; text-align: center; border-radius: 8px; margin: 16px 0;">
                ${code}
              </div>
              <p style="color: #666;">This code expires in ${Math.ceil(expiryMs / 60000)} minutes.</p>
              <p style="color: #999; font-size: 12px;">If you didn't request this code, please ignore this email.</p>
            </div>
          `;
          sendSmtpEmail.textContent = `Your verification code is: ${code}. It expires in ${Math.ceil(expiryMs / 60000)} minutes.`;

          await apiInstance.sendTransacEmail(sendSmtpEmail);
          return res.status(200).json({ success: true, message: "OTP resent successfully" });
        }
      }
    }

    code = Math.floor(100000 + Math.random() * 900000).toString();
    const now = new Date();
    expiryMs = parseInt(process.env.OTP_EXPIRY_MINUTES || "5") * 60 * 1000;

    await db.collection("email_otps").doc(userId).set({
      code: code,
      created_at: admin.firestore.FieldValue.serverTimestamp(),
      expires_at: new Date(now.getTime() + expiryMs).toISOString(),
      used: false,
    });

    const apiInstance = new Brevo.TransactionalEmailsApi();
    apiInstance.setApiKey(Brevo.TransactionalEmailsApiApiKeys.apiKey, process.env.BREVO_API_KEY);

    const sendSmtpEmail = new Brevo.SendSmtpEmail();
    sendSmtpEmail.sender = {
      name: process.env.BREVO_SENDER_NAME || "WeDo",
      email: process.env.BREVO_SENDER_EMAIL,
    };
    sendSmtpEmail.to = [{ email: email }];
    sendSmtpEmail.subject = "WeDo - Email Verification Code";
    sendSmtpEmail.htmlContent = `
      <div style="font-family: Arial, sans-serif; max-width: 480px; margin: 0 auto; padding: 32px;">
        <h2 style="color: #1a73e8;">WeDo Email Verification</h2>
        <p>Your verification code is:</p>
        <div style="font-size: 32px; font-weight: bold; letter-spacing: 8px; color: #333; background: #f5f5f5; padding: 16px; text-align: center; border-radius: 8px; margin: 16px 0;">
          ${code}
        </div>
        <p style="color: #666;">This code expires in ${process.env.OTP_EXPIRY_MINUTES || 5} minutes.</p>
        <p style="color: #999; font-size: 12px;">If you didn't request this code, please ignore this email.</p>
      </div>
    `;
    sendSmtpEmail.textContent = `Your verification code is: ${code}. It expires in ${process.env.OTP_EXPIRY_MINUTES || 5} minutes.`;

    await apiInstance.sendTransacEmail(sendSmtpEmail);

    return res.status(200).json({ success: true, message: "OTP sent successfully" });
  } catch (error) {
    console.error("generateOTP error:", error);
    return res.status(500).json({ error: "Failed to generate OTP" });
  }
};
