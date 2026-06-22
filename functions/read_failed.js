const admin = require("firebase-admin");

if (!admin.apps.length) {
  admin.initializeApp({
    projectId: "utme-pass-at-once-36340"
  });
}

const db = admin.firestore();

/**
 * Run diagnostic reading of recent failed payment transactions.
 * @returns {Promise<void>}
 */
async function run() {
  try {
    const snap = await db.collection("payment_transactions")
      .orderBy("createdAt", "desc")
      .limit(5)
      .get();

    console.log(`Found ${snap.size} transactions:`);
    snap.forEach((doc) => {
      const data = doc.data();
      console.log(`- Reference: ${doc.id}`);
      console.log(`  Status: ${data.status}`);
      console.log(`  ExpectedAmount: ${data.expectedAmount}`);
      console.log(`  FailureReason: ${data.failureReason}`);
      if (data.paystackResponse) {
        console.log(`  Paystack Paid Amount: ${data.paystackResponse.amount}`);
        console.log(`  Paystack Paid Status: ${data.paystackResponse.status}`);
      }
    });
  } catch (err) {
    console.error("Error reading from firestore:", err);
  }
}

run();
