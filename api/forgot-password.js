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
const auth = admin.auth();

const brevoApi = new Brevo.TransactionalEmailsApi();
brevoApi.setApiKey(Brevo.TransactionalEmailsApiApiKeys.apiKey, process.env.BREVO_API_KEY);

function getEmailContent(code, expiryMinutes) {
  return {
    subject: "WeDo - Password Reset Code",
    htmlContent: `
      <div style="font-family: Arial, sans-serif; max-width: 480px; margin: 0 auto; padding: 32px;">
        <h2 style="color: #1a73e8;">WeDo Password Reset</h2>
        <p>You requested to reset your password. Your reset code is:</p>
        <div style="font-size: 32px; font-weight: bold; letter-spacing: 8px; color: #333; background: #f5f5f5; padding: 16px; text-align: center; border-radius: 8px; margin: 16px 0;">
          ${code}
        </div>
        <p style="color: #666;">This code expires in ${expiryMinutes} minutes.</p>
        <p style="color: #999; font-size: 12px;">If you didn't request a password reset, please ignore this email.</p>
      </div>
    `,
    textContent: `Your password reset code is: ${code}. It expires in ${expiryMinutes} minutes.`,
  };
}

async function sendResetCodeEmail(email, code, expiryMinutes) {
  const emailContent = getEmailContent(code, expiryMinutes);
  const sendSmtpEmail = new Brevo.SendSmtpEmail();
  sendSmtpEmail.sender = {
    name: process.env.BREVO_SENDER_NAME || "WeDo",
    email: process.env.BREVO_SENDER_EMAIL,
  };
  sendSmtpEmail.to = [{ email: email }];
  sendSmtpEmail.subject = emailContent.subject;
  sendSmtpEmail.htmlContent = emailContent.htmlContent;
  sendSmtpEmail.textContent = emailContent.textContent;

  await brevoApi.sendTransacEmail(sendSmtpEmail);
}

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
    const { email } = req.body;

    if (!email) {
      return res.status(400).json({ error: "email is required" });
    }

    let user;
    try {
      user = await auth.getUserByEmail(email);
    } catch (e) {
      return res.status(404).json({ error: "No account found with this email." });
    }

    const userId = user.uid;
    const existing = await db.collection("password_reset_otps").doc(userId).get();
    if (existing.exists) {
      const data = existing.data();
      const expiresAt = new Date(data.expires_at);
      if (!data.used && new Date() < expiresAt) {
        const code = data.code;
        const expiryMinutes = Math.ceil((expiresAt.getTime() - Date.now()) / 60000);

        await sendResetCodeEmail(email, code, expiryMinutes);
        return res.status(200).json({ success: true, message: "Reset code sent successfully" });
      }
    }

    const code = Math.floor(100000 + Math.random() * 900000).toString();
    const now = new Date();
    const expiryMs = parseInt(process.env.OTP_EXPIRY_MINUTES || "5") * 60 * 1000;
    const expiryMinutes = parseInt(process.env.OTP_EXPIRY_MINUTES || "5");

    await db.collection("password_reset_otps").doc(userId).set({
      code: code,
      email: email,
      created_at: admin.firestore.FieldValue.serverTimestamp(),
      expires_at: new Date(now.getTime() + expiryMs).toISOString(),
      used: false,
    });

    await sendResetCodeEmail(email, code, expiryMinutes);

    return res.status(200).json({ success: true, message: "Reset code sent successfully" });
  } catch (error) {
    console.error("forgot-password error:", error);
    return res.status(500).json({ error: "Failed to send reset code" });
  }
};