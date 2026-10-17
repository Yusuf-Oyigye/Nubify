const {
  initializeApp,
} = require("firebase-admin/app");
const {
  getAuth,
} = require("firebase-admin/auth");
const {
  getFirestore,
  Timestamp,
} = require("firebase-admin/firestore");

initializeApp();

async function main() {
  const email = String(process.argv[2] || "").trim().toLowerCase();
  if (!email || !email.includes("@")) {
    throw new Error(
      "Usage: node scripts/set_marketplace_owner.js your-email@example.com",
    );
  }
  const auth = getAuth();
  const db = getFirestore();
  const nextOwner = await auth.getUserByEmail(email);
  const ownership = db.collection("marketplaceSystem").doc("ownership");
  const existing = await ownership.get();
  const previousOwnerUid = existing.data()?.ownerUid || "";

  const nextClaims = {...(nextOwner.customClaims || {})};
  nextClaims.marketplaceOwner = true;
  nextClaims.admin = true;
  nextClaims.marketplaceReviewer = true;
  await auth.setCustomUserClaims(nextOwner.uid, nextClaims);

  if (previousOwnerUid && previousOwnerUid !== nextOwner.uid) {
    const previousOwner = await auth.getUser(previousOwnerUid);
    const previousClaims = {...(previousOwner.customClaims || {})};
    previousClaims.marketplaceOwner = false;
    await auth.setCustomUserClaims(previousOwnerUid, previousClaims);
  }

  await ownership.set({
    ownerUid: nextOwner.uid,
    previousOwnerUid,
    bootstrappedBy: "admin_sdk_script",
    transferredAt: Timestamp.now(),
  });
  process.stdout.write(
    `Marketplace owner is now ${email} (${nextOwner.uid}).\n` +
    "Ask that user to sign out and sign in again to refresh permissions.\n",
  );
}

main().catch((error) => {
  process.stderr.write(`${error.stack || error}\n`);
  process.exitCode = 1;
});
