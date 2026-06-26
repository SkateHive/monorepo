import { createRequire } from "node:module";
import crypto from "node:crypto";
// Load dhive from the api repo's node_modules (monorepo root has no deps).
const require = createRequire(
  process.env.DHIVE_FROM ||
    "/Users/web3warrior/Code/skatehive/monorepo/services/skatehive-api/"
);
const { PrivateKey, Client } = require("@hiveio/dhive");

const master = process.env.MASTER;          // backup/master password (runtime only, never logged)
const account = process.env.ACCOUNT || "skateuser";
const webFp = process.env.WEB_KEY_FP || ""; // sha256[:12] of web-prod DEFAULT_HIVE_POSTING_KEY
if (!master) { console.error("MASTER env required"); process.exit(1); }

const fp = (s) => crypto.createHash("sha256").update(s).digest("hex").slice(0, 12);

const posting = PrivateKey.fromLogin(account, master, "posting");
const wif = posting.toString();
const pub = posting.createPublic("STM").toString();

console.log(`account                    : ${account}`);
console.log(`derived posting WIF length : ${wif.length}`);
console.log(`derived posting WIF fp     : ${fp(wif)}`);
console.log(`web-prod DEFAULT key fp    : ${webFp || "(not provided)"}`);
console.log(`fp match vs web-prod env   : ${webFp ? (fp(wif) === webFp ? "YES" : "NO") : "n/a"}`);
console.log(`derived posting pubkey     : ${pub}`);

const client = new Client(["https://api.hive.blog", "https://api.deathwing.me", "https://anyx.io"]);
const [acct] = await client.database.getAccounts([account]);
if (!acct) { console.log("on-chain account           : NOT FOUND"); process.exit(0); }
const auths = acct.posting.key_auths.map(([k]) => k);
console.log(`on-chain posting authority : ${auths.join(", ")}`);
console.log(`pubkey matches on-chain    : ${auths.includes(pub) ? "YES" : "NO"}`);
