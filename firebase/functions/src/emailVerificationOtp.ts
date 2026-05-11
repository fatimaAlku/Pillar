/**
 * Email OTP verification (6-digit code). Production setup:
 * 1) firebase functions:secrets:set EMAIL_OTP_SECRET  (long random string)
 * 2) Set on the Cloud Run service (or Functions env): SMTP_HOST, SMTP_PORT (optional, default 587),
 *    SMTP_USER, SMTP_PASS, EMAIL_FROM
 * 3) Deploy: firebase deploy --only functions,firestore:rules
 * Emulator: OTP is printed to the function log; SMTP_HOST may be omitted.
 */
import * as admin from "firebase-admin";
import * as crypto from "crypto";
import {HttpsError, onCall} from "firebase-functions/v2/https";
import {defineSecret} from "firebase-functions/params";
import nodemailer from "nodemailer";

const OTP_LENGTH = 6;
const OTP_TTL_MS = 15 * 60 * 1000;
const MIN_RESEND_MS = 60 * 1000;
const MAX_SENDS_PER_HOUR = 5;
const MAX_VERIFY_ATTEMPTS = 8;

const emailOtpSecret = defineSecret("EMAIL_OTP_SECRET");

function isFunctionsEmulator(): boolean {
  return process.env.FUNCTIONS_EMULATOR === "true";
}

function resolveOtpSecret(): string {
  const fromEnv = process.env.EMAIL_OTP_SECRET?.trim();
  if (fromEnv) {
    return fromEnv;
  }
  const fromParam = emailOtpSecret.value()?.trim();
  if (fromParam) {
    return fromParam;
  }
  if (isFunctionsEmulator()) {
    return "emulator-only-pepper-not-for-production";
  }
  throw new HttpsError(
    "failed-precondition",
    "Server misconfiguration: EMAIL_OTP_SECRET is not set.",
  );
}

function hashOtp(uid: string, code: string, secret: string): string {
  return crypto.createHmac("sha256", secret).update(`${uid}:${code}`).digest("hex");
}

function timingSafeEqualHex(a: string, b: string): boolean {
  try {
    const ba = Buffer.from(a, "hex");
    const bb = Buffer.from(b, "hex");
    if (ba.length !== bb.length || ba.length === 0) {
      return false;
    }
    return crypto.timingSafeEqual(ba, bb);
  } catch {
    return false;
  }
}

function randomDigits(length: number): string {
  const bytes = crypto.randomBytes(length);
  let out = "";
  for (let i = 0; i < length; i++) {
    out += (bytes[i]! % 10).toString();
  }
  return out;
}

type OtpDoc = {
  codeHash: string;
  expiresAt: admin.firestore.Timestamp;
  lastSentAt: admin.firestore.Timestamp;
  sendWindowStart: admin.firestore.Timestamp;
  sendsInWindow: number;
  failedAttempts: number;
};

function otpCollection() {
  return admin.firestore().collection("emailVerificationOtps");
}

async function sendOtpEmail(input: {
  to: string;
  code: string;
  lang: "ar" | "en";
}): Promise<void> {
  const host = process.env.SMTP_HOST?.trim();
  if (!host) {
    if (isFunctionsEmulator()) {
      console.log(`[emulator] Email OTP for ${input.to}: ${input.code}`);
      return;
    }
    throw new HttpsError(
      "failed-precondition",
      "SMTP is not configured. Set SMTP_HOST (and related env vars) on the function.",
    );
  }

  const port = Number.parseInt(process.env.SMTP_PORT ?? "587", 10) || 587;
  const user = process.env.SMTP_USER?.trim() ?? "";
  const pass = process.env.SMTP_PASS?.trim() ?? "";
  const from = process.env.EMAIL_FROM?.trim() ?? "noreply@localhost";

  const transporter = nodemailer.createTransport({
    host,
    port,
    secure: port === 465,
    auth: user && pass ? {user, pass} : undefined,
  });

  const subject =
    input.lang === "ar"
      ? "رمز التحقق — بيلار"
      : "Your Pillar verification code";

  const text =
    input.lang === "ar"
      ? `رمز التحقق الخاص بك: ${input.code}\n\nصالح لمدة 15 دقيقة. إذا لم تطلب هذا الرمز، يمكنك تجاهل هذه الرسالة.`
      : `Your verification code is: ${input.code}\n\nThis code expires in 15 minutes. If you did not request it, you can ignore this email.`;

  const html =
    input.lang === "ar"
      ? `<p>رمز التحقق الخاص بك:</p><p style="font-size:24px;font-weight:bold;letter-spacing:4px;">${input.code}</p><p>صالح لمدة 15 دقيقة.</p>`
      : `<p>Your verification code:</p><p style="font-size:24px;font-weight:bold;letter-spacing:4px;">${input.code}</p><p>This code expires in 15 minutes.</p>`;

  await transporter.sendMail({
    from,
    to: input.to,
    subject,
    text,
    html,
  });
}

export const sendEmailVerificationOtp = onCall(
  {
    secrets: [emailOtpSecret],
  },
  async (request) => {
    if (!request.auth?.uid) {
      throw new HttpsError("unauthenticated", "Sign in to request a verification code.");
    }

    const uid = request.auth.uid;
    const user = await admin.auth().getUser(uid);
    if (user.emailVerified) {
      return {alreadyVerified: true};
    }
    const email = user.email?.trim();
    if (!email) {
      throw new HttpsError("failed-precondition", "Account has no email address.");
    }

    const langRaw = request.data?.languageCode;
    const lang: "ar" | "en" = langRaw === "ar" ? "ar" : "en";

    const secret = resolveOtpSecret();
    const now = Date.now();
    const ref = otpCollection().doc(uid);
    const snap = await ref.get();
    const data = snap.exists ? (snap.data() as OtpDoc) : null;

    if (data) {
      const lastSent = data.lastSentAt?.toMillis?.() ?? 0;
      if (now - lastSent < MIN_RESEND_MS) {
        throw new HttpsError(
          "resource-exhausted",
          "Please wait a minute before requesting another code.",
        );
      }
      const windowStart = data.sendWindowStart?.toMillis?.() ?? now;
      const inWindow = now - windowStart < 60 * 60 * 1000;
      const count = data.sendsInWindow ?? 0;
      if (inWindow && count >= MAX_SENDS_PER_HOUR) {
        throw new HttpsError(
          "resource-exhausted",
          "Too many verification emails sent. Try again later.",
        );
      }
    }

    const code = randomDigits(OTP_LENGTH);
    const codeHash = hashOtp(uid, code, secret);
    const expiresAt = admin.firestore.Timestamp.fromMillis(now + OTP_TTL_MS);

    const resetWindow =
      !data ||
      now - (data.sendWindowStart?.toMillis?.() ?? 0) >= 60 * 60 * 1000;
    const prevCount = data?.sendsInWindow ?? 0;
    const sendsInWindow = resetWindow ? 1 : prevCount + 1;
    const sendWindowStart = resetWindow
      ? admin.firestore.Timestamp.fromMillis(now)
      : (data?.sendWindowStart ?? admin.firestore.Timestamp.fromMillis(now));

    await ref.set(
      {
        codeHash,
        expiresAt,
        lastSentAt: admin.firestore.Timestamp.fromMillis(now),
        sendWindowStart,
        sendsInWindow,
        failedAttempts: 0,
      },
      {merge: true},
    );

    await sendOtpEmail({to: email, code, lang});

    return {sent: true};
  },
);

type VerifyRequest = {
  code?: string;
};

export const verifyEmailWithOtp = onCall(
  {
    secrets: [emailOtpSecret],
  },
  async (request) => {
    if (!request.auth?.uid) {
      throw new HttpsError("unauthenticated", "Sign in to verify your email.");
    }

    const uid = request.auth.uid;
    const raw = (request.data as VerifyRequest)?.code;
    const code = typeof raw === "string" ? raw.replace(/\D/g, "").trim() : "";
    if (code.length !== OTP_LENGTH) {
      throw new HttpsError("invalid-argument", "Enter the 6-digit code from your email.");
    }

    const secret = resolveOtpSecret();
    const ref = otpCollection().doc(uid);
    const snap = await ref.get();
    if (!snap.exists) {
      throw new HttpsError(
        "not-found",
        "No verification code on file. Request a new code.",
      );
    }

    const data = snap.data() as OtpDoc;
    const expiresAt = data.expiresAt?.toMillis?.() ?? 0;
    if (Date.now() > expiresAt) {
      await ref.delete();
      throw new HttpsError(
        "not-found",
        "That code has expired. Request a new code.",
      );
    }

    const attempts = data.failedAttempts ?? 0;
    if (attempts >= MAX_VERIFY_ATTEMPTS) {
      await ref.delete();
      throw new HttpsError(
        "resource-exhausted",
        "Too many incorrect attempts. Request a new code.",
      );
    }

    const expectedHash = data.codeHash;
    const actualHash = hashOtp(uid, code, secret);
    if (!timingSafeEqualHex(expectedHash, actualHash)) {
      await ref.update({failedAttempts: attempts + 1});
      throw new HttpsError("permission-denied", "Incorrect code. Try again.");
    }

    await admin.auth().updateUser(uid, {emailVerified: true});
    await ref.delete();
    return {verified: true};
  },
);
