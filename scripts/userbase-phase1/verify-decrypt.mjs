import crypto from "node:crypto";
import { execSync } from "node:child_process";

const dbUrl = process.env.DATABASE_URL;
const secret = process.env.USERBASE_KEY_ENCRYPTION_SECRET;
if (!dbUrl || !secret) {
  console.error("Need DATABASE_URL and USERBASE_KEY_ENCRYPTION_SECRET in env"); process.exit(1);
}
// Pull ONE key row. All fields are ciphertext/metadata — no plaintext leaves the DB.
const sql =
  "SELECT user_id||'|'||encrypted_posting_key||'|'||encryption_iv||'|'||encryption_auth_tag " +
  "FROM public.userbase_hive_keys LIMIT 1;";
const row = execSync(`psql "${dbUrl}" -At -c "${sql}"`, { encoding: "utf8" }).trim();
if (!row) { console.log("No userbase_hive_keys rows yet — nothing to decrypt (acceptable)."); process.exit(0); }

const [userId, enc, iv, tag] = row.split("|");
function tryDecrypt(salt) {
  const key = crypto.scryptSync(secret, salt, 32);
  const d = crypto.createDecipheriv("aes-256-gcm", key, Buffer.from(iv, "base64"));
  d.setAuthTag(Buffer.from(tag, "base64"));
  return Buffer.concat([d.update(Buffer.from(enc, "base64")), d.final()]).toString("utf8");
}
let out;
for (const salt of [`skatehive-hive-key-${userId}`, "skatehive-userbase"]) {
  try { out = tryDecrypt(salt); break; } catch { /* try next salt */ }
}
if (out) {
  console.log(`DECRYPT OK for user ${userId.slice(0,8)}… (plaintext length ${out.length})`);
  console.log("=> The API secret matches the secret that ENCRYPTED this stored key.");
} else {
  console.error("DECRYPT FAILED with both salts.");
  console.error("=> API USERBASE_KEY_ENCRYPTION_SECRET does NOT match. STOP — do not plan a cutover.");
  process.exit(2);
}
