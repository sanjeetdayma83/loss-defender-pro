import * as crypto from "crypto";

const ALGO = "aes-256-gcm";

function keyBuf() {
  const s = process.env.CRYPTO_SECRET || "dev-only-change-me-32-characters!!";
  return Buffer.from(s.padEnd(32, "0").slice(0, 32));
}

export function encryptSecret(plain: string): string {
  if (!plain) return plain;
  const iv = crypto.randomBytes(12);
  const cipher = crypto.createCipheriv(ALGO, keyBuf(), iv);
  const enc = Buffer.concat([cipher.update(plain, "utf8"), cipher.final()]);
  const tag = cipher.getAuthTag();
  return Buffer.concat([iv, tag, enc]).toString("base64");
}

export function decryptSecret(payload: string): string {
  if (!payload) return payload;
  // allow already-plain legacy during migration
  if (!payload.match(/^[A-Za-z0-9+/=]+$/) || payload.length < 40) return payload;
  try {
    const buf = Buffer.from(payload, "base64");
    const iv = buf.subarray(0, 12);
    const tag = buf.subarray(12, 28);
    const data = buf.subarray(28);
    const decipher = crypto.createDecipheriv(ALGO, keyBuf(), iv);
    decipher.setAuthTag(tag);
    return Buffer.concat([decipher.update(data), decipher.final()]).toString("utf8");
  } catch {
    return payload;
  }
}