const { setGlobalOptions } = require("firebase-functions/v2");
setGlobalOptions({ memory: "256MiB" });

const { onRequest } = require("firebase-functions/v2/https");
const {
  onDocumentUpdated,
  onDocumentCreated,
  onDocumentDeleted,
} = require("firebase-functions/v2/firestore");
const { onSchedule } = require("firebase-functions/v2/scheduler");
const { defineSecret } = require("firebase-functions/params");
const logger = require("firebase-functions/logger");
const axios = require("axios");
const cors = require("cors")({ origin: true });
const admin = require("firebase-admin");
const crypto = require("crypto");

if (!admin.apps.length) {
  admin.initializeApp();
}

const db = admin.firestore();
const FieldValue = admin.firestore.FieldValue;
const paystackSecret = defineSecret("PAYSTACK_SECRET_KEY");
const newsApiKey = defineSecret("NEWS_API_KEY");

/**
 * Normalize email to lowercase trimmed format.
 * @param {string} email
 * @return {string}
 */
function normalizeEmail(email) {
  return String(email || "").trim().toLowerCase();
}

/**
 * Convert value into safe uppercase reference part.
 * @param {string} value
 * @return {string}
 */
function sanitizeForReference(value) {
  return String(value || "")
    .trim()
    .toUpperCase()
    .replace(/\s+/g, "_");
}

/**
 * Resolve voucher prefix from exam type.
 * @param {string} examType
 * @return {string}
 */
function voucherPrefix(examType) {
  switch (String(examType || "").trim().toLowerCase()) {
    case "jamb":
      return "JAM";
    case "post_utme":
      return "PUT";
    case "waec":
      return "WAE";
    case "neco":
      return "NEC";
    default:
      return "GEN";
  }
}

/**
 * Generate random uppercase alphanumeric segment.
 * @param {number=} length
 * @return {string}
 */
function randomSegment(length = 4) {
  const chars = "ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789";
  let result = "";
  for (let i = 0; i < length; i++) {
    result += chars.charAt(Math.floor(Math.random() * chars.length));
  }
  return result;
}

/**
 * Build voucher code from exam type.
 * @param {string} examType
 * @return {string}
 */
function buildVoucherCode(examType) {
  return `${voucherPrefix(examType)}-${randomSegment(4)}-${randomSegment(4)}`;
}

/**
 * Generate a single unique voucher code.
 * @param {string} examType
 * @return {Promise<string>}
 */
async function generateUniqueVoucherCode(examType) {
  for (let i = 0; i < 20; i++) {
    const code = buildVoucherCode(examType);
    const voucherSnap = await db.collection("vouchers").doc(code).get();
    if (!voucherSnap.exists) {
      return code;
    }
  }
  throw new Error("Could not generate a unique voucher code.");
}

/**
 * Generate many unique voucher codes safely and efficiently.
 * Uses db.getAll() to verify uniqueness in bulk, preventing atomic batch failures.
 * @param {string} examType
 * @param {number} quantity
 * @return {Promise<string[]>}
 */
async function generateUniqueVoucherCodes(examType, quantity) {
  const codes = new Set();
  let attempts = 0;
  const maxAttempts = quantity * 30;

  while (codes.size < quantity && attempts < maxAttempts) {
    attempts++;
    codes.add(buildVoucherCode(examType));
  }

  if (codes.size !== quantity) {
    throw new Error("Could not generate enough initial voucher codes.");
  }

  let codeArray = Array.from(codes);
  let isCompletelyUnique = false;
  let validationAttempts = 0;

  while (!isCompletelyUnique && validationAttempts < 5) {
    validationAttempts++;

    const refs = codeArray.map((code) => db.collection("vouchers").doc(code));
    const snapshots = [];

    for (let i = 0; i < refs.length; i += 100) {
      const chunkRefs = refs.slice(i, i + 100);
      const chunkSnaps = await db.getAll(...chunkRefs);
      snapshots.push(...chunkSnaps);
    }

    const existingCodes = new Set(
      snapshots.filter((snap) => snap.exists).map((snap) => snap.id),
    );

    if (existingCodes.size === 0) {
      isCompletelyUnique = true;
      break;
    }

    const freshSet = new Set(
      codeArray.filter((code) => !existingCodes.has(code)),
    );

    let refillAttempts = 0;
    const refillMaxAttempts = quantity * 20;

    while (freshSet.size < quantity && refillAttempts < refillMaxAttempts) {
      refillAttempts++;
      freshSet.add(buildVoucherCode(examType));
    }

    if (freshSet.size !== quantity) {
      throw new Error("Could not refill voucher codes safely.");
    }

    codeArray = Array.from(freshSet);
  }

  if (!isCompletelyUnique) {
    throw new Error("System unable to resolve code collisions. Please try again.");
  }

  return codeArray;
}

/**
 * Chunk an array into smaller arrays.
 * @param {Array} array
 * @param {number} size
 * @return {Array[]}
 */
function chunkArray(array, size) {
  const result = [];
  for (let i = 0; i < array.length; i += size) {
    result.push(array.slice(i, i + size));
  }
  return result;
}

/**
 * Save transaction update with merge.
 * @param {FirebaseFirestore.DocumentReference} txRef
 * @param {Object} payload
 * @return {Promise<void>}
 */
async function mergeTransaction(txRef, payload) {
  await txRef.set({
    ...payload,
    updatedAt: FieldValue.serverTimestamp(),
  }, { merge: true });
}

/**
 * Extract bearer token from Authorization header.
 * @param {Object} req
 * @return {string|null}
 */
function getBearerToken(req) {
  const header = req.headers.authorization || req.headers.Authorization;
  if (!header || typeof header !== "string" || !header.startsWith("Bearer ")) {
    return null;
  }
  return header.substring(7).trim();
}

/**
 * Verify Firebase ID token.
 * @param {Object} req
 * @return {Promise<Object>}
 */
async function verifyRequestUser(req) {
  const token = getBearerToken(req);

  if (!token) {
    throw new Error("Missing Authorization token.");
  }

  try {
    return await admin.auth().verifyIdToken(token);
  } catch (error) {
    throw new Error("Invalid or expired token.");
  }
}

/**
 * Ensure request is from active admin.
 * @param {Object} req
 * @return {Promise<Object>}
 */
async function requireActiveAdmin(req) {
  const decoded = await verifyRequestUser(req);
  const adminRef = db.collection("admins").doc(decoded.uid);
  const adminSnap = await adminRef.get();

  if (!adminSnap.exists || adminSnap.data().isActive !== true) {
    throw new Error("Admin access required.");
  }

  return decoded;
}


/**
 * Send push notification to all active tokens of a user.
 */
async function sendPushNotification(
  uid,
  notification,
  data = {},
  type = "general",
  saveToDb = true,
  ignoreGeneralEnabled = false,
) {
  try {
    const userSnap = await db.collection("users").doc(uid).get();
    if (!userSnap.exists) return;

    const userData = userSnap.data();

    if (!ignoreGeneralEnabled && userData.generalNotificationEnabled === false) return;

    const tokensSnap = await db.collection("users")
      .doc(uid)
      .collection("fcmTokens")
      .where("isActive", "==", true)
      .get();

    if (tokensSnap.empty) return;

    const tokens = tokensSnap.docs.map((doc) => doc.id);

    const safeData = {};
    Object.keys(data).forEach((key) => {
      safeData[key] = String(data[key]);
    });

    safeData.type = String(type);
    safeData.title = String(notification.title || "");
    safeData.body = String(notification.body || "");

    const sendPromises = tokens.map(async (token) => {
      const singleMessage = {
        token: token,
        notification: notification,
        data: safeData,
        android: {
          priority: "high",
          notification: {
            sound: "default",
            channelId: "high_importance_channel",
          },
        },
        apns: {
          payload: {
            aps: {
              "content-available": 1,
              "sound": "default",
            },
          },
        },
      };

      try {
        await admin.messaging().send(singleMessage);
        return { success: true, token };
      } catch (err) {
        logger.error(`FCM token failed for user ${uid}:`, err);
        return { success: false, token, error: err };
      }
    });

    const results = await Promise.all(sendPromises);
    const successCount = results.filter((r) => r.success).length;

    logger.info(`Push sent: ${successCount}/${tokens.length}`);

    // Clean up failed tokens only if they are permanently invalid/unregistered
    const cleanupPromises = results
      .filter((r) => {
        if (r.success) return false;

        const err = r.error || {};
        const code = err.code || (err.errorInfo && err.errorInfo.code) || "";

        // Permanent invalid token errors
        return (
          code === "messaging/registration-token-not-registered" ||
          code === "messaging/invalid-argument" ||
          code === "messaging/invalid-registration-token"
        );
      })
      .map((r) => {
        return db.collection("users")
          .doc(uid)
          .collection("fcmTokens")
          .doc(r.token)
          .delete();
      });
    await Promise.all(cleanupPromises);

    if (saveToDb) {
      await db.collection("users").doc(uid)
        .collection("notifications")
        .add({
          title: notification.title,
          body: notification.body,
          type,
          payload: data,
          isRead: false,
          source: "system",
          fcmSent: true,
          createdAt: FieldValue.serverTimestamp(),
        });
    }
  } catch (error) {
    logger.error("Push error:", error);
  }
}

/**
 * Check velocity rate limit: max 5 initialize requests per user in 10 minutes.
 * Automatically cleans up logs older than 10 minutes in the background.
 * @param {string} uid
 * @return {Promise<boolean>} True if rate limited, false otherwise.
 */
async function checkRateLimitAndClean(uid) {
  const now = new Date();
  const tenMinutesAgo = new Date(now.getTime() - 10 * 60 * 1000);
  const rateLimitRef = db.collection("users").doc(uid).collection("payment_rate_limits");

  // Fetch recent entries
  const recentSnap = await rateLimitRef.where("timestamp", ">=", tenMinutesAgo).get();

  if (recentSnap.size >= 5) {
    logger.warn(`Suspicious activity: Rate limit hit for user ${uid}. Exceeded 5 initialize attempts in 10 minutes.`);
    return true;
  }

  // Record current attempt
  await rateLimitRef.add({
    timestamp: FieldValue.serverTimestamp(),
  });

  // Clean up older entries asynchronously
  rateLimitRef.where("timestamp", "<", tenMinutesAgo).get().then((oldSnap) => {
    if (!oldSnap.empty) {
      const batch = db.batch();
      oldSnap.forEach((doc) => batch.delete(doc.ref));
      return batch.commit();
    }
    return null;
  }).catch((err) => {
    logger.error(`Error cleaning old rate limit entries for user ${uid}:`, err);
  });

  return false;
}

/**
 * Process a verified payment transaction inside a Firestore transaction.
 * @param {string} reference
 * @param {Object} paystackData
 * @return {Promise<Object>} Result object containing status and details
 */
async function processVerifiedPayment(reference, paystackData) {
  const txRef = db.collection("payment_transactions").doc(reference);

  const paidStatus = String(paystackData.status || "").toLowerCase();
  const paidAmount = Number(paystackData.amount);
  const paidCurrency = String(paystackData.currency || "").toUpperCase();
  const paidEmail = normalizeEmail(paystackData.customer?.email);
  const metadataUid = String(paystackData.metadata?.uid || "").trim();
  const metadataExamType = String(paystackData.metadata?.examType || "").trim().toLowerCase();

  let result = null;

  const txSnap = await txRef.get();
  if (!txSnap.exists) {
    throw new Error(`Transaction record ${reference} not found`);
  }
  const txData = txSnap.data();
  const isBulk = txData.transactionType === "bulk_code_purchase";
  const quantity = txData.quantity || 1;

  let voucherCodes = [];
  if (isBulk) {
    voucherCodes = await generateUniqueVoucherCodes(metadataExamType, quantity);
  } else {
    const voucherCode = await generateUniqueVoucherCode(metadataExamType);
    voucherCodes = [voucherCode];
  }

  await db.runTransaction(async (transaction) => {
    const txSnapTrans = await transaction.get(txRef);
    if (!txSnapTrans.exists) {
      throw new Error(`Transaction record ${reference} not found`);
    }

    const txDataTrans = txSnapTrans.data();

    // Prevent duplicate voucher generation
    if (txDataTrans.status === "voucher_generated" || txDataTrans.status === "approved") {
      result = {
        status: "already_processed",
        voucherCode: txDataTrans.voucherCode,
        examType: txDataTrans.examType,
        amount: Number(txDataTrans.expectedAmount || 0) / 100,
      };
      return;
    }

    if (txDataTrans.processingLock === true) {
      result = {
        status: "processing_locked",
        message: "Transaction is currently being processed by another worker",
      };
      return;
    }

    // 1. Perform all Firestore transaction reads BEFORE any writes
    const voucherSnaps = [];
    for (const code of voucherCodes) {
      const voucherRef = db.collection("vouchers").doc(code);
      const voucherSnap = await transaction.get(voucherRef);
      voucherSnaps.push({ code, snap: voucherSnap });
    }

    // 2. Perform all Firestore transaction writes and updates
    // Set processing lock atomically
    transaction.update(txRef, {
      processingLock: true,
      updatedAt: FieldValue.serverTimestamp(),
    });

    const expectedAmount = Number(txDataTrans.expectedAmount || 0);
    const expectedEmail = normalizeEmail(txDataTrans.email);
    const expectedUid = String(txDataTrans.uid || "").trim();
    const expectedExamType = String(txDataTrans.examType || "").trim().toLowerCase();

    // Security & Data validation checks
    if (paidStatus !== "success") {
      transaction.update(txRef, {
        status: "failed",
        failureReason: `Paystack payment status was: ${paidStatus}`,
        processingLock: false,
        paystackResponse: paystackData,
        updatedAt: FieldValue.serverTimestamp(),
      });
      throw new Error(`Verification failed: status is ${paidStatus}`);
    }

    const paidFees = Number(paystackData.fees || 0);
    const netAmount = paidAmount - paidFees;

    const amountsMatch = (paidAmount === expectedAmount) ||
                         (paidAmount === expectedAmount * 100) ||
                         (paidAmount * 100 === expectedAmount) ||
                         (netAmount === expectedAmount) ||
                         (netAmount === expectedAmount * 100) ||
                         (netAmount * 100 === expectedAmount);

    if (!amountsMatch) {
      transaction.update(txRef, {
        status: "failed",
        failureReason: "Amount mismatch detected",
        processingLock: false,
        paystackResponse: paystackData,
        updatedAt: FieldValue.serverTimestamp(),
      });
      logger.error(`Suspicious activity: amount mismatch for ${reference}. Expected: ${expectedAmount}, Paid: ${paidAmount}, Fees: ${paidFees}, Net: ${netAmount}`);
      throw new Error("Validation failed: amount mismatch");
    }

    if (paidCurrency !== "NGN") {
      transaction.update(txRef, {
        status: "failed",
        failureReason: "Currency mismatch detected",
        processingLock: false,
        paystackResponse: paystackData,
        updatedAt: FieldValue.serverTimestamp(),
      });
      logger.error(`Suspicious activity: currency mismatch for ${reference}. Expected: NGN, Paid: ${paidCurrency}`);
      throw new Error("Validation failed: currency mismatch");
    }

    if (paidEmail !== expectedEmail) {
      transaction.update(txRef, {
        status: "failed",
        failureReason: "Email mismatch detected",
        processingLock: false,
        paystackResponse: paystackData,
        updatedAt: FieldValue.serverTimestamp(),
      });
      logger.error(`Suspicious activity: email mismatch for ${reference}. Expected: ${expectedEmail}, Paid: ${paidEmail}`);
      throw new Error("Validation failed: email mismatch");
    }

    if (metadataUid !== expectedUid) {
      transaction.update(txRef, {
        status: "failed",
        failureReason: "User ID mismatch detected",
        processingLock: false,
        paystackResponse: paystackData,
        updatedAt: FieldValue.serverTimestamp(),
      });
      logger.error(`Suspicious activity: UID mismatch for ${reference}. Expected: ${expectedUid}, Paid: ${metadataUid}`);
      throw new Error("Validation failed: uid mismatch");
    }

    if (metadataExamType !== expectedExamType) {
      transaction.update(txRef, {
        status: "failed",
        failureReason: "Exam type mismatch detected",
        processingLock: false,
        paystackResponse: paystackData,
        updatedAt: FieldValue.serverTimestamp(),
      });
      logger.error(`Suspicious activity: examType mismatch for ${reference}. Expected: ${expectedExamType}, Paid: ${metadataExamType}`);
      throw new Error("Validation failed: examType mismatch");
    }

    // Uniqueness validation on all generated codes inside the transaction (checking the snaps we read earlier)
    for (const item of voucherSnaps) {
      if (item.snap.exists) {
        throw new Error(`Voucher collision check failed for ${item.code}`);
      }
    }

    // Set new voucher documents inside transaction
    for (const code of voucherCodes) {
      const voucherRef = db.collection("vouchers").doc(code);
      if (isBulk) {
        transaction.set(voucherRef, {
          code: code,
          examType: expectedExamType,
          price: expectedAmount / quantity / 100, // per code price in Naira
          status: "sold",
          generatedByAdminUid: "system",
          subAdminId: expectedUid, // unified sub-admin mapping
          createdBy: expectedUid, // owned by the sub-admin (legacy)
          paymentMethod: "paystack",
          paymentReference: reference,
          soldAt: FieldValue.serverTimestamp(),
          createdAt: FieldValue.serverTimestamp(),
          confirmedByAdminUid: null,
          usedByUid: null,
          usedAt: null,
          updatedAt: FieldValue.serverTimestamp(),
        });
      } else {
        transaction.set(voucherRef, {
          code: code,
          examType: expectedExamType,
          price: expectedAmount / 100,
          status: "sold",
          generatedByAdminUid: "system",
          soldToUid: expectedUid, // sold directly to normal user
          paymentMethod: "paystack",
          paymentReference: reference,
          soldAt: FieldValue.serverTimestamp(),
          createdAt: FieldValue.serverTimestamp(),
          confirmedByAdminUid: null,
          usedByUid: null,
          usedAt: null,
          updatedAt: FieldValue.serverTimestamp(),
        });
      }
    }

    const finalCodesString = voucherCodes.join(", ");

    // Update payment transaction document status
    transaction.update(txRef, {
      status: "completed",
      voucherCode: finalCodesString,
      generatedCodes: voucherCodes,
      paystackResponse: paystackData,
      verifiedAt: FieldValue.serverTimestamp(),
      voucherGeneratedAt: FieldValue.serverTimestamp(),
      processingLock: false,
      failureReason: null,
      updatedAt: FieldValue.serverTimestamp(),
    });

    result = {
      status: "success",
      voucherCode: finalCodesString,
      examType: expectedExamType,
      amount: expectedAmount / 100,
    };
  });

  return result;
}

/**
 * Initialize Paystack transaction and save pending record.
 */
exports.initializePaystackTransaction = onRequest(
  {
    secrets: [paystackSecret],
    timeoutSeconds: 60,
    memory: "256MiB",
  },
  (req, res) => {
    cors(req, res, async () => {
      let txRef = null;

      try {
        if (req.method !== "POST") {
          return res.status(405).json({
            status: false,
            message: "Method not allowed",
          });
        }

        const { email, amount, examType, uid, name, quantity, transactionType } = req.body || {};

        const cleanEmail = normalizeEmail(email);
        const normalizedExamType = String(examType || "").trim().toLowerCase();
        const cleanUid = String(uid || "").trim();
        const cleanName = String(name || "").trim();
        const parsedAmount = Number(amount);
        const parsedQuantity = quantity ? Math.max(1, Number(quantity)) : 1;
        const cleanTransactionType = String(transactionType || "single_code_purchase").trim();

        if (!cleanEmail || !cleanEmail.includes("@")) {
          return res.status(400).json({
            status: false,
            message: "Invalid email",
          });
        }

        if (!normalizedExamType || !cleanUid || !parsedAmount) {
          return res.status(400).json({
            status: false,
            message: "Missing required fields",
          });
        }

        if (Number.isNaN(parsedAmount) || parsedAmount <= 0) {
          return res.status(400).json({
            status: false,
            message: "Invalid amount",
          });
        }

        // Velocity Rate Limiting
        const isLimited = await checkRateLimitAndClean(cleanUid);
        if (isLimited) {
          return res.status(429).json({
            status: false,
            message: "Too many payment requests. Please try again in 10 minutes.",
          });
        }

        // Anti-Fraud Protection: Prevent duplicate pending payments within 30 minutes
        const pendingSnap = await db.collection("payment_transactions")
          .where("uid", "==", cleanUid)
          .where("examType", "==", normalizedExamType)
          .where("status", "==", "pending")
          .get();

        if (!pendingSnap.empty) {
          const nowMs = Date.now();
          const thirtyMinutesAgo = nowMs - 30 * 60 * 1000;
          let activePendingExists = false;

          for (const doc of pendingSnap.docs) {
            const data = doc.data();
            // Skip manual bank transfers from duplicate checks and automatic expiration
            if (data.paymentMethod === "bank_transfer") {
              continue;
            }
            const createdTime = data.createdAt ?
              (data.createdAt.toMillis ? data.createdAt.toMillis() : new Date(data.createdAt).getTime()) : 0;

            if (createdTime < thirtyMinutesAgo) {
              // Automatically expire stale pending transaction older than 30 minutes
              await doc.ref.update({
                status: "failed",
                failureReason: "Expired by anti-fraud check for new request",
                updatedAt: FieldValue.serverTimestamp(),
              });
            } else {
              activePendingExists = true;
            }
          }

          if (activePendingExists) {
            logger.info(`Duplicate check: Active pending transaction already exists for ${cleanUid} - ${normalizedExamType}`);
            return res.status(429).json({
              status: false,
              message: "You have an active pending payment for this exam. Please complete or cancel it before starting a new one.",
            });
          }
        }

        const reference =
          `${sanitizeForReference(normalizedExamType)}_` +
          `${sanitizeForReference(cleanUid)}_${Date.now()}`;

        txRef = db.collection("payment_transactions").doc(reference);

        const isBulkPurchase = cleanTransactionType === "bulk_code_purchase";

        await txRef.set({
          reference,
          uid: cleanUid,
          subAdminUid: isBulkPurchase ? cleanUid : null, // set subAdminUid if bulk purchase
          email: cleanEmail,
          userName: cleanName,
          examType: normalizedExamType,
          expectedAmount: parsedAmount,
          currency: "NGN",
          paymentMethod: "paystack",
          source: "mobile_app",
          status: "pending",
          voucherCode: null,
          purchaseId: null,
          paystackAccessCode: null,
          authorizationUrl: null,
          paystackResponse: null,
          failureReason: null,
          verifiedAt: null,
          voucherGeneratedAt: null,
          processingLock: false,
          retryCount: 0,
          lastRetryAt: null,
          nextRetryAt: null,
          createdAt: FieldValue.serverTimestamp(),
          updatedAt: FieldValue.serverTimestamp(),
          quantity: parsedQuantity,
          transactionType: cleanTransactionType,
        });

        const response = await axios.post(
          "https://api.paystack.co/transaction/initialize",
          {
            email: cleanEmail,
            amount: parsedAmount,
            reference,
            callback_url: "https://utme-pass-at-once-36340.web.app/paystack/callback",
            channels: [
              "card",
              "bank",
              "ussd",
              "qr",
              "mobile_money",
              "bank_transfer",
              "eft",
            ],
            metadata: {
              uid: cleanUid,
              examType: normalizedExamType,
              name: cleanName,
              cancel_action: "https://utme-pass-at-once-36340.web.app/paystack/cancel",
              quantity: parsedQuantity,
              transactionType: cleanTransactionType,
            },
          },
          {
            headers: {
              "Authorization": `Bearer ${paystackSecret.value()}`,
              "Content-Type": "application/json",
            },
          },
        );

        const data = response.data;

        if (!data?.status || !data?.data?.authorization_url) {
          throw new Error("Invalid Paystack initialize response");
        }

        await mergeTransaction(txRef, {
          authorizationUrl: data.data.authorization_url,
          paystackAccessCode: data.data.access_code || null,
          paystackResponse: data.data,
        });

        return res.status(200).json({
          status: true,
          message: "Transaction initialized",
          authorization_url: data.data.authorization_url,
          access_code: data.data.access_code,
          reference: data.data.reference,
          examType: normalizedExamType,
        });
      } catch (error) {
        logger.error("Initialize error", error);

        if (txRef) {
          await mergeTransaction(txRef, {
            status: "failed",
            failureReason:
              error.response?.data?.message ||
              error.message ||
              "Unable to initialize payment",
          });
        }

        return res.status(500).json({
          status: false,
          message:
            error.response?.data?.message ||
            error.message ||
            "Unable to initialize payment",
        });
      }
    });
  },
);

/**
 * Verify Paystack payment manually via app frontend.
 */
exports.verifyPaystackTransaction = onRequest(
  {
    secrets: [paystackSecret],
    timeoutSeconds: 60,
    memory: "512MiB",
  },
  (req, res) => {
    cors(req, res, async () => {
      try {
        if (req.method !== "POST") {
          return res.status(405).json({
            status: false,
            message: "Method not allowed",
          });
        }

        const { reference } = req.body || {};
        const cleanReference = String(reference || "").trim();

        if (!cleanReference) {
          return res.status(400).json({
            status: false,
            message: "Reference required",
          });
        }

        const txRef = db.collection("payment_transactions")
          .doc(cleanReference);

        const txSnap = await txRef.get();

        if (!txSnap.exists) {
          return res.status(404).json({
            status: false,
            message: "Record not found",
          });
        }

        const txData = txSnap.data();

        if ((txData.status === "completed" || txData.status === "voucher_generated") && txData.voucherCode) {
          return res.status(200).json({
            status: true,
            message: "Already verified",
            paymentStatus: "success",
            reference: cleanReference,
            voucherCode: txData.voucherCode,
            examType: txData.examType,
            amount: Number(txData.expectedAmount || 0) / 100,
          });
        }

        if (txData.processingLock === true) {
          return res.status(200).json({
            status: true,
            message: "Payment verification in progress",
            paymentStatus: "processing",
            reference: cleanReference,
            voucherCode: null,
            examType: txData.examType,
            amount: Number(txData.expectedAmount || 0) / 100,
          });
        }

        await mergeTransaction(txRef, {
          status: "pending",
        });

        const verifyUrl = "https://api.paystack.co/transaction/verify/" +
          encodeURIComponent(cleanReference);

        const verifyResponse = await axios.get(verifyUrl, {
          headers: {
            "Authorization": `Bearer ${paystackSecret.value()}`,
            "Content-Type": "application/json",
          },
        });

        const paystackData = verifyResponse.data?.data;

        if (!paystackData) {
          await mergeTransaction(txRef, {
            status: "failed",
            failureReason: "Invalid Paystack verification response",
          });

          return res.status(400).json({
            status: false,
            message: "Invalid Paystack verification response",
          });
        }

        const paidStatus = String(paystackData.status || "").toLowerCase();

        if (paidStatus === "abandoned" || paidStatus === "pending") {
          await mergeTransaction(txRef, {
            status: "pending",
            paystackResponse: paystackData,
            failureReason: null,
          });

          return res.status(200).json({
            status: true,
            message: "Payment not completed yet",
            paymentStatus: paidStatus,
            reference: cleanReference,
            voucherCode: null,
            examType: txData.examType,
            amount: Number(txData.expectedAmount || 0) / 100,
          });
        }

        // Delegate transaction block & security checks to processVerifiedPayment helper
        const result = await processVerifiedPayment(cleanReference, paystackData);

        if (result.status === "success" || result.status === "already_processed") {
          return res.status(200).json({
            status: true,
            message: "Payment verified",
            paymentStatus: "success",
            reference: cleanReference,
            voucherCode: result.voucherCode,
            examType: result.examType || txData.examType,
            amount: result.amount || (Number(txData.expectedAmount || 0) / 100),
          });
        } else if (result.status === "processing_locked") {
          return res.status(200).json({
            status: true,
            message: "Verification in progress",
            paymentStatus: "processing",
            reference: cleanReference,
            voucherCode: null,
            examType: txData.examType,
            amount: Number(txData.expectedAmount || 0) / 100,
          });
        } else {
          return res.status(400).json({
            status: false,
            message: result.message || "Payment verification failed",
          });
        }
      } catch (error) {
        logger.error("Verify error", error);
        return res.status(500).json({
          status: false,
          message: error.message || "Unable to verify payment",
        });
      }
    });
  },
);

/**
 * Paystack webhook for server-to-server verification.
 */
exports.paystackWebhook = onRequest(
  {
    secrets: [paystackSecret],
    timeoutSeconds: 60,
    memory: "256MiB",
  },
  async (req, res) => {
    try {
      const hash = crypto.createHmac("sha512", paystackSecret.value())
        .update(req.rawBody)
        .digest("hex");

      if (hash !== req.headers["x-paystack-signature"]) {
        logger.error("Webhook verification warning: Invalid HMAC signature detected");
        return res.status(401).send("Unauthorized");
      }

      const event = req.body;
      const eventId = String(event?.id || event?.data?.id || "");

      if (!eventId) {
        logger.error("Webhook processing error: Missing Paystack event ID");
        return res.status(200).send("No event ID");
      }

      // Webhook Idempotency Check: Store and check processed webhook events
      const webhookRef = db.collection("processed_webhooks").doc(eventId);
      const webhookSnap = await webhookRef.get();

      if (webhookSnap.exists) {
        logger.info(`Webhook event ${eventId} has already been processed. Ignoring.`);
        return res.status(200).send("Webhook event already processed");
      }

      if (event.event === "charge.success") {
        const data = event.data;
        const reference = String(data.reference || "").trim();

        if (!reference) {
          return res.status(200).send("No reference found");
        }

        // Set processed webhook doc to mark event as handled
        await webhookRef.set({
          reference,
          processedAt: FieldValue.serverTimestamp(),
        });

        // Verify and process verification inside transaction
        try {
          await processVerifiedPayment(reference, data);
          logger.info(`Webhook event ${eventId} processed successfully for reference ${reference}.`);
        } catch (err) {
          logger.error(`Webhook processing exception for transaction ${reference}:`, err);
        }
      }

      return res.status(200).send("Webhook received successfully");
    } catch (error) {
      logger.error("Webhook processing error", error);
      return res.status(200).send("Error logged");
    }
  },
);

/**
 * Scheduled recovery system: query stale pending transactions and verify directly with Paystack API.
 */
exports.retryPendingPayments = onSchedule(
  {
    schedule: "*/5 * * * *",
    timeZone: "Africa/Lagos",
    timeoutSeconds: 300,
    memory: "256MiB",
    secrets: [paystackSecret],
  },
  async (event) => {
    try {
      const now = admin.firestore.Timestamp.now();

      // Retrieve transactions: status == "pending" AND paymentMethod == "paystack"
      const pendingSnap = await db.collection("payment_transactions")
        .where("status", "==", "pending")
        .where("paymentMethod", "==", "paystack")
        .get();

      if (pendingSnap.empty) {
        return;
      }

      logger.info(`Scheduler: Found ${pendingSnap.size} pending transactions to check.`);

      for (const doc of pendingSnap.docs) {
        const txData = doc.data();
        const reference = doc.id;

        // Skip if transaction is already completed, failed, or locked
        if (txData.status === "completed" || txData.status === "failed" || txData.processingLock === true) {
          continue;
        }

        const retryCount = txData.retryCount || 0;

        if (retryCount >= 5) {
          await doc.ref.update({
            status: "failed",
            failureReason: "Max recovery retries (5) exceeded without webhook confirmation",
            updatedAt: FieldValue.serverTimestamp(),
          });
          logger.warn(`Scheduler: Transaction ${reference} failed permanently due to max retries.`);
          continue;
        }

        // Check nextRetryAt backoff restriction
        if (txData.nextRetryAt && txData.nextRetryAt.toMillis() > now.toMillis()) {
          continue;
        }

        logger.info(`Scheduler: Retrying verification for transaction ${reference}. Attempt ${retryCount + 1}`);

        try {
          const verifyUrl = "https://api.paystack.co/transaction/verify/" +
            encodeURIComponent(reference);

          const verifyResponse = await axios.get(verifyUrl, {
            headers: {
              "Authorization": `Bearer ${paystackSecret.value()}`,
              "Content-Type": "application/json",
            },
          });

          const paystackData = verifyResponse.data?.data;

          if (!paystackData) {
            throw new Error("Paystack verification response returned empty payload");
          }

          const paidStatus = String(paystackData.status || "").toLowerCase();

          if (paidStatus === "success") {
            await processVerifiedPayment(reference, paystackData);
            logger.info(`Scheduler: Successfully recovered and verified transaction ${reference}.`);
          } else if (paidStatus === "abandoned" || paidStatus === "failed") {
            await doc.ref.update({
              status: "failed",
              failureReason: `Payment was ${paidStatus} on Paystack`,
              retryCount: retryCount + 1,
              lastRetryAt: FieldValue.serverTimestamp(),
              updatedAt: FieldValue.serverTimestamp(),
            });
            logger.info(`Scheduler: Transaction ${reference} was marked as ${paidStatus}.`);
          } else {
            // Still pending, apply backoff delay
            const nextAttemptMinutes = 5 * Math.pow(2, retryCount); // 5, 10, 20, 40, 80 mins
            const nextRetryDate = new Date(Date.now() + nextAttemptMinutes * 60 * 1000);

            await doc.ref.update({
              retryCount: retryCount + 1,
              lastRetryAt: FieldValue.serverTimestamp(),
              nextRetryAt: admin.firestore.Timestamp.fromDate(nextRetryDate),
              updatedAt: FieldValue.serverTimestamp(),
            });
            logger.info(`Scheduler: Transaction ${reference} remains pending. Postponed next attempt by ${nextAttemptMinutes} minutes.`);
          }
        } catch (err) {
          logger.error(`Scheduler error resolving transaction ${reference}:`, err);

          const nextAttemptMinutes = 5 * Math.pow(2, retryCount);
          const nextRetryDate = new Date(Date.now() + nextAttemptMinutes * 60 * 1000);

          await doc.ref.update({
            retryCount: retryCount + 1,
            lastRetryAt: FieldValue.serverTimestamp(),
            nextRetryAt: admin.firestore.Timestamp.fromDate(nextRetryDate),
            updatedAt: FieldValue.serverTimestamp(),
          });
        }
      }
    } catch (error) {
      logger.error("Scheduler run failure:", error);
    }
  },
);

/**
 * Admin bulk voucher generation.
 */
exports.generateAdminVouchers = onRequest(
  {
    timeoutSeconds: 120,
    memory: "512MiB",
  },
  (req, res) => {
    cors(req, res, async () => {
      try {
        if (req.method !== "POST") {
          return res.status(405).json({
            status: false,
            message: "Method not allowed",
          });
        }

        const decoded = await requireActiveAdmin(req);
        const adminUid = decoded.uid;

        if (!adminUid) {
          return res.status(400).json({
            status: false,
            message: "Invalid admin user",
          });
        }

        const { examType, quantity, price } = req.body || {};
        const normalizedExamType = String(examType || "").trim().toLowerCase();
        const parsedQuantity = Number(quantity);
        const parsedPrice = Number(price || 0);

        if (!normalizedExamType) {
          return res.status(400).json({
            status: false,
            message: "examType is required",
          });
        }

        if (
          Number.isNaN(parsedQuantity) ||
          parsedQuantity <= 0 ||
          parsedQuantity > 500
        ) {
          return res.status(400).json({
            status: false,
            message: "quantity must be between 1 and 500",
          });
        }

        if (Number.isNaN(parsedPrice) || parsedPrice < 0) {
          return res.status(400).json({
            status: false,
            message: "price must be 0 or greater",
          });
        }

        const codes = await generateUniqueVoucherCodes(
          normalizedExamType,
          parsedQuantity,
        );

        const chunks = chunkArray(codes, 400);
        const createdAt = FieldValue.serverTimestamp();

        for (const chunk of chunks) {
          const batch = db.batch();

          for (const code of chunk) {
            const voucherRef = db.collection("vouchers").doc(code);
            batch.create(voucherRef, {
              code,
              examType: normalizedExamType,
              price: parsedPrice,
              status: "generated",
              generatedByAdminUid: adminUid,
              createdAt,
              soldToUid: null,
              paymentMethod: null,
              paymentReference: null,
              soldAt: null,
              confirmedByAdminUid: null,
              usedByUid: null,
              usedAt: null,
              updatedAt: createdAt,
            });
          }

          await batch.commit();
        }

        await db.collection("audit_logs").doc().set({
          uid: adminUid,
          action: "admin_bulk_voucher_generated",
          timestamp: FieldValue.serverTimestamp(),
          details: {
            examType: normalizedExamType,
            quantity: parsedQuantity,
            price: parsedPrice,
            codes,
          },
        });

        return res.status(200).json({
          status: true,
          message: "Vouchers generated successfully",
          examType: normalizedExamType,
          quantity: parsedQuantity,
          price: parsedPrice,
          codes,
        });
      } catch (error) {
        logger.error("Admin generate error", error);
        const msg = error.message || "Unable to generate vouchers";

        if (msg.includes("token") || msg.includes("Admin access")) {
          return res.status(401).json({
            status: false,
            message: msg,
          });
        }

        return res.status(500).json({
          status: false,
          message: msg,
        });
      }
    });
  },
);

/**
 * Trigger: When a payment transaction is updated.
 */
exports.ontransactionupdated = onDocumentUpdated(
  "payment_transactions/{txId}",
  async (event) => {
    const newData = event.data.after.data();
    const oldData = event.data.before.data();

    const isNewlyApproved = (newData.status === "completed" || newData.status === "approved") &&
                            (oldData.status !== "completed" && oldData.status !== "approved");

    if (isNewlyApproved && newData && newData.uid) {
      await sendPushNotification(
        newData.uid,
        {
          title: "Payment Successful! 🎉",
          body: `Your ${newData.examType.toUpperCase()} payment ` +
            `was successful. Voucher: ${newData.voucherCode || ""}`,
        },
        {
          voucherCode: newData.voucherCode || "",
          examType: newData.examType,
          reference: newData.reference || event.params.txId,
        },
        "payment",
      );
    }

    if (newData && newData.status === "failed" && oldData && oldData.status !== "failed" && newData.uid) {
      const amount = newData.expectedAmount ? (newData.expectedAmount / 100) : 0;
      await sendPushNotification(
        newData.uid,
        {
          title: "❌ Payment Rejected",
          body: `Your payment of ₦${amount} for ${newData.examType} was not approved. Reason: ${newData.failureReason || "Unknown"}`,
        },
        {
          route: "/purchase",
          reason: newData.failureReason,
        },
        "payment_rejected",
        true,
      );
    }
  });

/**
 * Trigger: When a voucher is updated (e.g. Activated/Used).
 */
exports.onvoucherupdated = onDocumentUpdated(
  "vouchers/{voucherId}",
  async (event) => {
    const newData = event.data.after.data();
    const oldData = event.data.before.data();

    if (newData.status === "used" && oldData.status !== "used" && newData.usedByUid) {
      // 1. Send push notification
      await sendPushNotification(
        newData.usedByUid,
        {
          title: "Exam Activated! 🚀",
          body: `You have successfully activated ` +
            `${newData.examType.toUpperCase()}. Happy studying!`,
        },
        {
          examType: newData.examType,
          voucherCode: newData.code,
        },
        "exam_unlock",
        true,
      );

      // 2. Track the admin code usage in payment history
      try {
        let txExists = false;

        // Search by voucherCode in the collection (handles standalone, manual, or bulk redemption records)
        const querySnap = await db.collection("payment_transactions")
          .where("voucherCode", "==", newData.code)
          .limit(1)
          .get();

        if (!querySnap.empty) {
          txExists = true;
          const docRef = querySnap.docs[0].ref;
          const txData = querySnap.docs[0].data();
          if (txData.status !== "used") {
            await docRef.update({
              status: "used",
              updatedAt: FieldValue.serverTimestamp(),
            });
            logger.info(`Updated existing query-matched payment transaction to used status for voucher ${newData.code}`);
          } else {
            logger.info(`Existing query-matched payment transaction is already marked as used for voucher ${newData.code}`);
          }
        }

        // Only create a new transaction document if none exists (fallback for direct manual database updates or edge cases)
        if (!txExists) {
          const userSnap = await db.collection("users").doc(newData.usedByUid).get();
          const userData = userSnap.data() || {};
          const userName = `${userData.firstName || ""} ${userData.lastName || ""}`.trim() || "Unknown User";
          const userEmail = userData.email || "No Email";
          const subAdminUid = newData.subAdminId || newData.createdBy || newData.generatedByAdminUid || null;

          await db.collection("payment_transactions").add({
            transactionType: "admin_code_activation",
            uid: newData.usedByUid,
            userName: userName,
            email: userEmail,
            examType: newData.examType,
            quantity: 1,
            amount: Number(newData.price || 0),
            expectedAmount: Number(newData.price || 0) * 100, // keep kobo format for consistency if needed
            paymentMethod: "voucher",
            voucherCode: newData.code,
            status: "used",
            subAdminUid: subAdminUid,
            parentPaymentReference: newData.paymentReference || null,
            createdAt: FieldValue.serverTimestamp(),
            updatedAt: FieldValue.serverTimestamp(),
          });
          logger.info(`Recorded new fallback payment transaction for voucher ${newData.code}`);
        }
      } catch (error) {
        logger.error(`Failed to record or update transaction for voucher ${newData.code}`, error);
      }
    }
  });

/**
 * Trigger: When a user finishes an exam and history is recorded.
 */
exports.onexamhistorycreated = onDocumentCreated(
  "users/{uid}/exam_history/{histId}",
  async (event) => {
    // Disabled at user's request to use only the client-side Exam Completed notification instead
    logger.info("Result Submitted push notification bypassed at user request.");
  });

/**
 * Trigger: When user profile is updated (e.g., premium status).
 */
exports.onuserupdated = onDocumentUpdated(
  "users/{uid}",
  async (event) => {
    const newData = event.data.after.data();
    const oldData = event.data.before.data();
    const uid = event.params.uid;

    if (newData.isPremium === true && oldData.isPremium === false) {
      // Suppress duplicate Premium Unlocked push if exam_unlock or unlock_success happened very recently (< 10 seconds ago)
      try {
        const notifsSnap = await db.collection("users")
          .doc(uid)
          .collection("notifications")
          .orderBy("createdAt", "desc")
          .limit(3)
          .get();

        let hasRecentUnlock = false;
        const now = Date.now();

        notifsSnap.forEach((doc) => {
          const docData = doc.data();
          const type = docData.type;
          const createdAt = docData.createdAt;

          if (createdAt && (type === "exam_unlock" || type === "unlock_success")) {
            const createdMillis = createdAt.toMillis ? createdAt.toMillis() : new Date(createdAt).getTime();
            if (now - createdMillis < 10000) {
              hasRecentUnlock = true;
            }
          }
        });

        if (hasRecentUnlock) {
          logger.info(`Suppressing duplicate Premium Unlocked notification for user: ${uid} because of recent exam activation.`);
          return;
        }
      } catch (err) {
        logger.error(`Error checking recent notifications for user: ${uid}`, err);
      }

      await sendPushNotification(
        uid,
        {
          title: "Premium Unlocked! 💎",
          body: "Welcome to Premium! You now have full access to all features.",
        },
        {},
        "general",
      );
    }
  });

/**
 * Scheduled Task: Daily Random Quotes & Upsells
 * Runs every day at 8:00 AM (Lagos time).
 */
exports.dailystudyreminder = onSchedule(
  {
    schedule: "0 8 * * *",
    timeZone: "Africa/Lagos",
    timeoutSeconds: 540,
    memory: "512MiB",
  },
  async (event) => {
    const studyQuotes = [
      "POST-UTME is loading... have you opened a book today? 😂",
      "That medical degree won't earn itself! Time to study. 🩺",
      "Don't let POST-UTME catch you off guard. Practice now! 🚀",
      "TikTok can wait, your future can't. Open a past question! 📚",
      "You said you will study 'later'. It's later now! ⏰",
      "A chapter a day keeps the failure away. Start reading! 📖",
      "Even Einstein had to study. What's your excuse? 🧠",
      "Your dream university is waiting for you. Don't disappoint them! 🎓",
      "Stop scrolling, start studying! The exam clock is ticking. ⏳",
      "Tears of joy on admission day > Tears of regret. Practice! 💯",
    ];

    const upsellQuotes = [
      "Don't gamble with your admission. Unlock premium past questions today! 🚀",
      "Free access is good, but Premium guarantees success. Upgrade now! 🌟",
      "Tired of limited access? Get the full package and secure your admission! 🔓",
      "Join the top 1% of scorers. Upgrade to Premium for detailed explanations! 💯",
      "The best investment is in your future. Unlock all subjects today! 📚",
      "Why guess when you can know? Premium gives you the winning edge! 🏆",
    ];

    const usersSnapshot = await admin.firestore().collection("users").get();
    const users = usersSnapshot.docs;
    const chunkSize = 50;

    for (let i = 0; i < users.length; i += chunkSize) {
      const chunk = users.slice(i, i + chunkSize);

      const pushPromises = chunk.map((doc) => {
        const userData = doc.data();
        const isPremium = userData.isPremium === true;

        let selectedQuote = "";
        let title = "";

        if (isPremium) {
          selectedQuote = studyQuotes[Math.floor(Math.random() * studyQuotes.length)];
          title = "Time to Study! 📚";
        } else {
          const isUpsell = Math.random() < 0.5;
          if (isUpsell) {
            selectedQuote = upsellQuotes[Math.floor(Math.random() * upsellQuotes.length)];
            title = "Upgrade Your Study! 🚀";
          } else {
            selectedQuote = studyQuotes[Math.floor(Math.random() * studyQuotes.length)];
            title = "Time to Study! 📚";
          }
        }

        return sendPushNotification(
          doc.id,
          { title: title, body: selectedQuote },
          {},
          "daily_quote",
          true,
          true,
        );
      });

      await Promise.all(pushPromises);
    }

    logger.log(`Sent daily random quotes to ${usersSnapshot.size} users in chunks of ${chunkSize}.`);
  });


/**
 * Trigger: Catch-all for In-App Notifications
 */
exports.oninappnotificationcreated = onDocumentCreated(
  "users/{uid}/notifications/{notifId}",
  async (event) => {
    const data = event.data.data();
    const uid = event.params.uid;

    if (data.source === "system" || data.source === "client") return;

    await sendPushNotification(
      uid,
      {
        title: data.title || "New Notification",
        body: data.body || "You have a new message from the admin.",
      },
      data.payload || {},
      data.type || "general",
      false,
    );
  }
);

/**
 * Trigger: Delete User Auth and all sub-collections when Firestore document is deleted.
 */
exports.onuserdeleted = onDocumentDeleted(
  "users/{userId}",
  async (event) => {
    const userId = event.params.userId;
    const docRef = db.collection("users").doc(userId);

    try {
      await admin.auth().deleteUser(userId);
      logger.info(`Auth record deleted for user: ${userId}`);

      await db.recursiveDelete(docRef);
      logger.info(`Successfully performed recursive deletion for user: ${userId}`);
    } catch (error) {
      if (error.code === "auth/user-not-found") {
        logger.info(`Auth record for ${userId} already deleted, proceeding to Firestore cleanup.`);
        try {
          await db.recursiveDelete(docRef);
        } catch (dbErr) {
          logger.error(`Error during Firestore recursive delete for ${userId}:`, dbErr);
        }
      } else {
        logger.error(`Error in onuserdeleted trigger for ${userId}:`, error);
      }
    }
  }
);

/**
 * Trigger: Backend Fan-Out for Admin Broadcasts & Content Updates
 */
exports.onadminbroadcastcreated = onDocumentCreated(
  {
    document: "admin_broadcasts/{docId}",
    timeoutSeconds: 540,
    memory: "512MiB",
  },
  async (event) => {
    const data = event.data.data();
    if (!data) return;

    const docId = event.params.docId;
    const title = data.title || "New Update";
    const body = data.body || "";
    const audience = data.targetAudience || "All Users";
    const type = data.type || "broadcast";
    const payload = data.payload || { source: "admin_broadcast" };

    const broadcastRef = db.collection("admin_broadcasts").doc(docId);

    try {
      const usersSnap = await db.collection("users").get();
      if (usersSnap.empty) {
        await broadcastRef.update({ status: "sent", deliveredCount: 0 });
        return;
      }

      const batches = [];
      let currentBatch = db.batch();
      let count = 0;
      let deliveredCount = 0;

      for (const user of usersSnap.docs) {
        const userData = user.data();
        const isPremium = userData.isPremium === true;

        if (audience === "Premium Users" && !isPremium) continue;
        if (audience === "Free Users" && isPremium) continue;

        const notifRef = user.ref.collection("notifications").doc();
        currentBatch.set(notifRef, {
          title: title,
          body: body,
          type: type,
          createdAt: FieldValue.serverTimestamp(),
          isRead: false,
          payload: payload,
        });

        count++;
        deliveredCount++;

        if (count === 500) {
          batches.push(currentBatch);
          currentBatch = db.batch();
          count = 0;
        }
      }

      if (count > 0) {
        batches.push(currentBatch);
      }

      for (const batch of batches) {
        await batch.commit();
      }

      await broadcastRef.update({
        status: "sent",
        deliveredCount: deliveredCount,
        sentAt: FieldValue.serverTimestamp(),
      });
      logger.info(`Broadcast ${docId} delivered to ${deliveredCount} users.`);
    } catch (error) {
      logger.error(`Failed to fan-out broadcast ${docId}`, error);
      await broadcastRef.update({
        status: "failed",
        errorMsg: error.message,
      });
    }
  }
);

/**
 * Trigger: Backend Push Notification for Announcements
 */
exports.onannouncementcreated = onDocumentCreated(
  {
    document: "announcements/{docId}",
    timeoutSeconds: 540,
    memory: "512MiB",
  },
  async (event) => {
    const data = event.data.data();
    if (!data) return;

    const title = data.title || "New Announcement";
    const description = data.description || "";

    const message = {
      notification: {
        title: title,
        body: description.length > 100 ? description.substring(0, 97) + "..." : description,
      },
      topic: "all",
      data: {
        click_action: "FLUTTER_NOTIFICATION_CLICK",
        route: "/announcements",
        title: title,
        body: description,
        type: "broadcast",
      },
    };

    try {
      await admin.messaging().send(message);
      logger.info(`Announcement notification sent to topic 'all'`);
    } catch (error) {
      logger.error("Failed to send announcement notification to topic 'all'", error);
    }
  }
);

/**
 * Fans out classroom updates (notice, test, assignment, study note) from a sub-admin
 * to all referred students under that specific sub-admin center.
 */
async function fanOutSubAdminContent(adminId, title, body, type, payload) {
  try {
    // 1. Query referred students via 'referredBy' and 'referredAdminsList' in parallel
    const [byRefSnap, byListSnap] = await Promise.all([
      db.collection("users").where("referredBy", "==", adminId).get(),
      db.collection("users").where("referredAdminsList", "array-contains", adminId).get(),
    ]);

    // 2. Combine and deduplicate student IDs
    const studentIds = new Set();
    byRefSnap.forEach((doc) => studentIds.add(doc.id));
    byListSnap.forEach((doc) => studentIds.add(doc.id));

    if (studentIds.size === 0) {
      logger.info(`No students linked to sub-admin: ${adminId}. Notification fan-out skipped.`);
      return;
    }

    logger.info(`Fanning out sub-admin classroom update to ${studentIds.size} students.`);

    // 3. Batch write notifications to users' collections
    const studentIdArray = Array.from(studentIds);
    const chunks = chunkArray(studentIdArray, 400);

    for (const chunk of chunks) {
      const batch = db.batch();
      for (const studentId of chunk) {
        const notifRef = db.collection("users").doc(studentId).collection("notifications").doc();
        batch.set(notifRef, {
          title: title,
          body: body,
          type: type,
          createdAt: FieldValue.serverTimestamp(),
          isRead: false,
          payload: payload,
        });
      }
      await batch.commit();
    }
    logger.info(`Classroom notification successfully fanned out to ${studentIds.size} users.`);
  } catch (error) {
    logger.error("Error fanning out classroom notifications:", error);
  }
}

/**
 * Trigger: When a Notice Board post is created by a sub-admin.
 */
exports.onsubadminnoticecreated = onDocumentCreated(
  "admins/{adminId}/notices/{noticeId}",
  async (event) => {
    const data = event.data.data();
    if (!data) return;

    const adminId = event.params.adminId;
    const title = `Announcement: ${data.title}`;
    const body = data.message || "A new notice has been posted on the board.";

    await fanOutSubAdminContent(
      adminId,
      title,
      body,
      "classroom_notice",
      {
        route: "/eclassroom_notices",
        adminId: adminId,
        tab: "notices",
        source: "sub_admin",
      }
    );
  }
);

/**
 * Trigger: When a Notice Board post is updated by a sub-admin.
 */
exports.onsubadminnoticeupdated = onDocumentUpdated(
  "admins/{adminId}/notices/{noticeId}",
  async (event) => {
    const newData = event.data.after.data();
    const oldData = event.data.before.data();
    if (!newData) return;

    if (newData.title === oldData.title && newData.message === oldData.message) return;

    const adminId = event.params.adminId;
    const title = `Notice Updated: ${newData.title}`;
    const body = newData.message || "A notice has been updated.";

    await fanOutSubAdminContent(
      adminId,
      title,
      body,
      "classroom_notice",
      {
        route: "/eclassroom_notices",
        adminId: adminId,
        tab: "notices",
        source: "sub_admin",
      }
    );
  }
);

/**
 * Trigger: When a Classroom Test is created by a sub-admin.
 */
exports.onsubadmintestcreated = onDocumentCreated(
  "admins/{adminId}/tests/{testId}",
  async (event) => {
    const data = event.data.data();
    if (!data) return;

    const adminId = event.params.adminId;
    const title = "New CBT Test Posted 📝";
    const body = `"${data.title}" is now available in your eClassroom.`;

    await fanOutSubAdminContent(
      adminId,
      title,
      body,
      "classroom_test",
      {
        route: "/eclassroom_tests",
        adminId: adminId,
        tab: "tests",
        source: "sub_admin",
      }
    );
  }
);

/**
 * Trigger: When a Classroom Test is updated by a sub-admin.
 */
exports.onsubadmintestupdated = onDocumentUpdated(
  "admins/{adminId}/tests/{testId}",
  async (event) => {
    const newData = event.data.after.data();
    const oldData = event.data.before.data();
    if (!newData) return;

    if (newData.title === oldData.title && newData.subject === oldData.subject) return;

    const adminId = event.params.adminId;
    const title = "Classroom Test Updated 📝";
    const body = `"${newData.title}" has been updated.`;

    await fanOutSubAdminContent(
      adminId,
      title,
      body,
      "classroom_test",
      {
        route: "/eclassroom_tests",
        adminId: adminId,
        tab: "tests",
        source: "sub_admin",
      }
    );
  }
);

/**
 * Trigger: When a Classroom Assignment is created by a sub-admin.
 */
exports.onsubadminassignmentcreated = onDocumentCreated(
  "admins/{adminId}/assignments/{assignmentId}",
  async (event) => {
    const data = event.data.data();
    if (!data) return;

    const adminId = event.params.adminId;
    const title = "New Assignment Posted 📚";
    const body = `"${data.title}" has been assigned to your class.`;

    await fanOutSubAdminContent(
      adminId,
      title,
      body,
      "classroom_assignment",
      {
        route: "/eclassroom_assignments",
        adminId: adminId,
        tab: "assignments",
        source: "sub_admin",
      }
    );
  }
);

/**
 * Trigger: When a Classroom Assignment is updated by a sub-admin.
 */
exports.onsubadminassignmentupdated = onDocumentUpdated(
  "admins/{adminId}/assignments/{assignmentId}",
  async (event) => {
    const newData = event.data.after.data();
    const oldData = event.data.before.data();
    if (!newData) return;

    if (newData.title === oldData.title && newData.instructions === oldData.instructions) return;

    const adminId = event.params.adminId;
    const title = "Assignment Updated 📚";
    const body = `"${newData.title}" has been updated.`;

    await fanOutSubAdminContent(
      adminId,
      title,
      body,
      "classroom_assignment",
      {
        route: "/eclassroom_assignments",
        adminId: adminId,
        tab: "assignments",
        source: "sub_admin",
      }
    );
  }
);

/**
 * Trigger: When a Classroom Study Note is uploaded by a sub-admin.
 */
exports.onsubadminstudynotecreated = onDocumentCreated(
  "admins/{adminId}/study_notes/{noteId}",
  async (event) => {
    const data = event.data.data();
    if (!data) return;

    const adminId = event.params.adminId;
    const title = "New Study Note Uploaded 📖";
    const body = `"${data.title}" is now available in study notes.`;

    await fanOutSubAdminContent(
      adminId,
      title,
      body,
      "classroom_note",
      {
        route: "/eclassroom_study_notes",
        adminId: adminId,
        tab: "study_notes",
        source: "sub_admin",
      }
    );
  }
);

/**
 * Trigger: When a Classroom Study Note is updated by a sub-admin.
 */
exports.onsubadminstudynoteupdated = onDocumentUpdated(
  "admins/{adminId}/study_notes/{noteId}",
  async (event) => {
    const newData = event.data.after.data();
    const oldData = event.data.before.data();
    if (!newData) return;

    if (newData.title === oldData.title && newData.description === oldData.description) return;

    const adminId = event.params.adminId;
    const title = "Study Note Updated 📖";
    const body = `"${newData.title}" has been updated.`;

    await fanOutSubAdminContent(
      adminId,
      title,
      body,
      "classroom_note",
      {
        route: "/eclassroom_study_notes",
        adminId: adminId,
        tab: "study_notes",
        source: "sub_admin",
      }
    );
  }
);

/**
 * Scheduled Cloud Function to sync educational news from NewsData.io.
 * Runs once every 3 hours.
 */
exports.syncNews = onSchedule(
  {
    schedule: "0 */3 * * *",
    timeZone: "Africa/Lagos",
    timeoutSeconds: 300,
    memory: "512MiB",
    secrets: [newsApiKey],
  },
  async (event) => {
    try {
      const apiKey = newsApiKey.value();
      if (!apiKey) {
        logger.error("syncNews: NEWS_API_KEY secret is not set.");
        return;
      }

      const educationQuery = "(jamb OR waec OR neco OR \"post-utme\" OR \"nigeria education\" OR \"admission list\")";
      const url = `https://newsdata.io/api/1/latest?country=ng&q=${encodeURIComponent(educationQuery)}&apikey=${apiKey}`;

      logger.info("syncNews: Fetching latest news from NewsData.io");
      const response = await axios.get(url, { timeout: 15000 });

      if (response.status !== 200) {
        logger.error(`syncNews: API returned status code ${response.status}`);
        return;
      }

      const data = response.data;
      const results = data.results || [];
      logger.info(`syncNews: Fetched ${results.length} articles.`);

      const fallbackImage = "https://images.unsplash.com/photo-1522202176988-66273c2fd55f?q=80&w=800&auto=format&fit=crop";
      let brandNewArticlesCount = 0;
      let latestBrandNewArticle = null;

      // Process up to 30 articles to avoid overloading
      const maxArticles = Math.min(results.length, 30);

      for (let i = 0; i < maxArticles; i++) {
        const item = results[i];
        const link = item.link || "";
        if (!link) continue;

        // Generate deterministic document ID using MD5 hash of article link
        const docId = crypto.createHash("md5").update(link).digest("hex");
        const docRef = db.collection("news").doc(docId);
        const docSnap = await docRef.get();

        const rawContent = item.content || item.description || "Read the full story...";
        // Strip HTML tag safely
        const cleanContent = rawContent.replace(/<[^>]*>/g, " ").replace(/\s+/g, " ").trim();
        const cleanDescription = (item.description || cleanContent).replace(/<[^>]*>/g, " ").replace(/\s+/g, " ").trim();

        let formattedDate = "";
        try {
          if (item.pubDate) {
            const dt = new Date(item.pubDate);
            const day = String(dt.getDate()).padStart(2, "0");
            const months = ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"];
            const month = months[dt.getMonth()];
            const year = dt.getFullYear();
            let hours = dt.getHours();
            const minutes = String(dt.getMinutes()).padStart(2, "0");
            const ampm = hours >= 12 ? "PM" : "AM";
            hours = hours % 12;
            hours = hours ? hours : 12;
            const strTime = String(hours).padStart(2, "0") + ":" + minutes + " " + ampm;
            formattedDate = `${day} ${month} ${year} • ${strTime}`;
          }
        } catch (_) {
          formattedDate = item.pubDate || "";
        }

        const newsData = {
          title: item.title || "No Title",
          description: cleanDescription.substring(0, 300),
          fullContent: cleanContent,
          imageUrl: item.image_url || fallbackImage,
          link: link,
          source: (item.source_id || "Education News").toString().toUpperCase(),
          pubDate: formattedDate,
          syncedAt: new Date().toISOString(),
        };

        if (!docSnap.exists) {
          // Check if article with the same title already exists in the collection (duplicate detection)
          const titleCheck = await db.collection("news")
            .where("title", "==", newsData.title)
            .limit(1)
            .get();

          if (titleCheck.empty) {
            // Brand new article!
            brandNewArticlesCount++;
            if (!latestBrandNewArticle) {
              latestBrandNewArticle = newsData;
              latestBrandNewArticle.id = docId;
            }
            await docRef.set(newsData);
          } else {
            logger.info(`syncNews: Article with title "${newsData.title}" already exists. Skipping duplicate notification.`);
          }
        } else {
          // Update the existing article to refresh fields if content updated
          await docRef.update({
            title: newsData.title,
            description: newsData.description,
            fullContent: newsData.fullContent,
            imageUrl: newsData.imageUrl,
            source: newsData.source,
            pubDate: newsData.pubDate,
          });
        }
      }

      logger.info(`syncNews: Sync finished. Brand new articles: ${brandNewArticlesCount}`);

      // --- PUSH NOTIFICATION FAN-OUT FOR BRAND NEW NEWS ---
      if (brandNewArticlesCount > 0 && latestBrandNewArticle) {
        logger.info(`syncNews: Fanning out push notifications for new article: "${latestBrandNewArticle.title}"`);
        const usersSnap = await db.collection("users").get();
        if (!usersSnap.empty) {
          const batches = [];
          let currentBatch = db.batch();
          let count = 0;
          let totalSent = 0;

          for (const userDoc of usersSnap.docs) {
            const notifRef = userDoc.ref.collection("notifications").doc();
            currentBatch.set(notifRef, {
              title: "New Education News 📰",
              body: latestBrandNewArticle.title,
              type: "education_news",
              createdAt: FieldValue.serverTimestamp(),
              isRead: false,
              payload: {
                route: "/news",
                newsId: latestBrandNewArticle.id,
              },
            });

            count++;
            totalSent++;

            if (count === 500) {
              batches.push(currentBatch);
              currentBatch = db.batch();
              count = 0;
            }
          }

          if (count > 0) {
            batches.push(currentBatch);
          }

          for (const batch of batches) {
            await batch.commit();
          }

          logger.info(`syncNews: Fanned out notifications to ${totalSent} users.`);
        }
      }

      await cleanupOldNewsBackend();
    } catch (err) {
      logger.error("syncNews failed:", err);
    }
  }
);

/**
 * Backend cleanup for news older than 7 days.
 */
async function cleanupOldNewsBackend() {
  try {
    const sevenDaysAgo = new Date(Date.now() - 7 * 24 * 60 * 60 * 1000).toISOString();
    const oldNewsQuery = await db.collection("news")
      .where("syncedAt", "<", sevenDaysAgo)
      .get();

    if (!oldNewsQuery.empty) {
      const batch = db.batch();
      oldNewsQuery.forEach((doc) => {
        batch.delete(doc.ref);
      });
      await batch.commit();
      logger.info(`cleanupOldNewsBackend: Purged ${oldNewsQuery.size} old news articles.`);
    }
  } catch (error) {
    logger.error("cleanupOldNewsBackend Error:", error);
  }
}

/**
 * Lightweight callback endpoint to prevent WebView crash on heavy Flutter index.html loads.
 */
exports.paystackCallback = onRequest(
  {
    timeoutSeconds: 15,
    memory: "128MiB",
  },
  (req, res) => {
    res.setHeader("Content-Type", "text/html");
    return res.status(200).send(`
<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>Payment Successful</title>
  <style>
    body {
      font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, Helvetica, Arial, sans-serif;
      background-color: #0b0f19;
      color: #f3f4f6;
      display: flex;
      justify-content: center;
      align-items: center;
      height: 100vh;
      margin: 0;
      padding: 20px;
      box-sizing: border-box;
    }
    .card {
      background: #111827;
      border: 1px solid #1f2937;
      border-radius: 16px;
      padding: 40px 30px;
      text-align: center;
      max-width: 420px;
      width: 100%;
      box-shadow: 0 10px 25px -5px rgba(0, 0, 0, 0.3), 0 8px 10px -6px rgba(0, 0, 0, 0.3);
    }
    .icon-container {
      background: rgba(16, 185, 129, 0.1);
      border: 2px solid #10b981;
      width: 72px;
      height: 72px;
      border-radius: 50%;
      display: flex;
      justify-content: center;
      align-items: center;
      margin: 0 auto 24px;
    }
    .icon-container svg {
      width: 36px;
      height: 36px;
      color: #10b981;
    }
    h1 {
      margin: 0 0 12px;
      font-size: 24px;
      font-weight: 700;
      color: #ffffff;
    }
    p {
      margin: 0 0 28px;
      line-height: 1.6;
      color: #9ca3af;
      font-size: 15px;
    }
    .action-text {
      font-size: 13px;
      color: #6b7280;
      font-weight: 500;
    }
  </style>
</head>
<body>
  <div class="card">
    <div class="icon-container">
      <svg fill="none" stroke="currentColor" viewBox="0 0 24 24" xmlns="http://www.w3.org/2000/svg">
        <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2.5" d="M5 13l4 4L19 7"></path>
      </svg>
    </div>
    <h1>Payment Successful</h1>
    <p>Your transaction has been completed successfully. You can now close this page to return to your app.</p>
    <div class="action-text">Processing your payment in the background...</div>
  </div>
</body>
</html>
    `);
  }
);

/**
 * Lightweight cancel endpoint to prevent WebView crash.
 */
exports.paystackCancel = onRequest(
  {
    timeoutSeconds: 15,
    memory: "128MiB",
  },
  (req, res) => {
    res.setHeader("Content-Type", "text/html");
    return res.status(200).send(`
<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>Payment Cancelled</title>
  <style>
    body {
      font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, Helvetica, Arial, sans-serif;
      background-color: #0b0f19;
      color: #f3f4f6;
      display: flex;
      justify-content: center;
      align-items: center;
      height: 100vh;
      margin: 0;
      padding: 20px;
      box-sizing: border-box;
    }
    .card {
      background: #111827;
      border: 1px solid #1f2937;
      border-radius: 16px;
      padding: 40px 30px;
      text-align: center;
      max-width: 420px;
      width: 100%;
      box-shadow: 0 10px 25px -5px rgba(0, 0, 0, 0.3), 0 8px 10px -6px rgba(0, 0, 0, 0.3);
    }
    .icon-container {
      background: rgba(239, 68, 68, 0.1);
      border: 2px solid #ef4444;
      width: 72px;
      height: 72px;
      border-radius: 50%;
      display: flex;
      justify-content: center;
      align-items: center;
      margin: 0 auto 24px;
    }
    .icon-container svg {
      width: 36px;
      height: 36px;
      color: #ef4444;
    }
    h1 {
      margin: 0 0 12px;
      font-size: 24px;
      font-weight: 700;
      color: #ffffff;
    }
    p {
      margin: 0 0 28px;
      line-height: 1.6;
      color: #9ca3af;
      font-size: 15px;
    }
    .action-text {
      font-size: 13px;
      color: #6b7280;
      font-weight: 500;
    }
  </style>
</head>
<body>
  <div class="card">
    <div class="icon-container">
      <svg fill="none" stroke="currentColor" viewBox="0 0 24 24" xmlns="http://www.w3.org/2000/svg">
        <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2.5" d="M6 18L18 6M6 6l12 12"></path>
      </svg>
    </div>
    <h1>Payment Cancelled</h1>
    <p>You have cancelled the payment checkout. You can now close this page to return to your app.</p>
    <div class="action-text">Returning to purchase options...</div>
  </div>
</body>
</html>
    `);
  }
);


/**
 * On-Demand Campaign: Send promotional unlock exam mode notifications to FREE users only.
 */
exports.sendUnlockPromoToFreeUsers = onRequest(
  {
    timeoutSeconds: 300,
    memory: "512MiB",
  },
  (req, res) => {
    cors(req, res, async () => {
      try {
        if (req.method !== "POST") {
          return res.status(405).json({
            status: false,
            message: "Method not allowed",
          });
        }

        const authHeader = req.headers.authorization;
        const expectedToken = "utme_promo_secret_token_2026_xyz";
        if (!authHeader || authHeader !== `Bearer ${expectedToken}`) {
          return res.status(401).json({
            status: false,
            message: "Unauthorized",
          });
        }

        const promoMessages = [
          {
            title: "Ready to ace your exams? 🚀",
            body: "Unlock full Exam Mode today! Get unlimited access to past questions, real exam simulators, and detailed explanations.",
          },
          {
            title: "Unlock your potential 🎓",
            body: "Don't let restrictions hold you back. Upgrade to Premium and unlock full Exam Mode with real-time practice and solutions!",
          },
          {
            title: "Practice makes perfect! 🏆",
            body: "Get access to over 20,000+ solved exam questions. Activate premium Exam Mode now and pass your UTME at one sitting!",
          },
          {
            title: "Exam success is 1 click away! 💡",
            body: "Free access is just a preview. Unlock full offline Exam Mode to access mock exams and detailed topic syllabus notes!",
          },
          {
            title: "Special Offer: Double study speed! ⚡",
            body: "Activate Premium Exam Mode now. Master the exact questions and exam patterns to guarantee your dream score!",
          },
        ];

        const usersSnapshot = await db.collection("users").get();
        const users = usersSnapshot.docs;
        const freeUsers = users.filter((doc) => {
          const data = doc.data();
          return data.isPremium !== true;
        });

        if (freeUsers.length === 0) {
          return res.status(200).json({
            status: true,
            message: "No free users found to target.",
            totalSent: 0,
          });
        }

        const chunkSize = 50;
        let totalSent = 0;

        for (let i = 0; i < freeUsers.length; i += chunkSize) {
          const chunk = freeUsers.slice(i, i + chunkSize);

          const pushPromises = chunk.map(async (doc) => {
            const randomMessage = promoMessages[Math.floor(Math.random() * promoMessages.length)];
            try {
              await sendPushNotification(
                doc.id,
                {
                  title: randomMessage.title,
                  body: randomMessage.body,
                },
                {
                  click_action: "FLUTTER_NOTIFICATION_CLICK",
                  route: "/store",
                  screen: "store",
                },
                "unlock_promo",
                true,
                true,
              );
              totalSent++;
            } catch (err) {
              logger.error(`Error sending promo notification to user ${doc.id}:`, err);
            }
          });

          await Promise.all(pushPromises);
        }

        return res.status(200).json({
          status: true,
          message: `Successfully fanned out promotional notifications to free users.`,
          totalSent: totalSent,
          totalTargeted: freeUsers.length,
        });
      } catch (error) {
        logger.error("Error in sendUnlockPromoToFreeUsers function:", error);
        return res.status(500).json({
          status: false,
          message: error.message || "Internal server error",
        });
      }
    });
  },
);


