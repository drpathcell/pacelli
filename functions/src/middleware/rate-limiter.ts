/**
 * Rate limiting middleware for Pacelli Cloud Functions.
 *
 * Uses Firestore to track per-user request counts within a sliding
 * time window. Designed for the low-volume, household-management
 * workload — generous limits that still prevent abuse.
 *
 * Limits:
 *   - 100 requests per minute per user (read-heavy operations)
 *   - 30 write operations per minute per user
 *   - 500 requests per hour per user (sustained throughput cap)
 */
import * as admin from "firebase-admin";

// ── Configuration ──

interface RateLimitConfig {
  /** Maximum requests in the short window */
  shortWindowMax: number;
  /** Short window duration in seconds */
  shortWindowSec: number;
  /** Maximum requests in the long window */
  longWindowMax: number;
  /** Long window duration in seconds */
  longWindowSec: number;
}

/** Default limits for read-heavy operations */
const READ_LIMITS: RateLimitConfig = {
  shortWindowMax: 100,
  shortWindowSec: 60,
  longWindowMax: 500,
  longWindowSec: 3600,
};

/** Stricter limits for write operations */
const WRITE_LIMITS: RateLimitConfig = {
  shortWindowMax: 30,
  shortWindowSec: 60,
  longWindowMax: 200,
  longWindowSec: 3600,
};

// ── Types ──

export type OperationType = "read" | "write";

export class RateLimitError extends Error {
  public readonly statusCode = 429;
  public readonly retryAfterSec: number;

  constructor(retryAfterSec: number) {
    super(`Rate limit exceeded. Try again in ${retryAfterSec} seconds.`);
    this.name = "RateLimitError";
    this.retryAfterSec = retryAfterSec;
  }
}

// ── Core ──

const db = () => admin.firestore();
const COLLECTION = "_rate_limits";

interface RateLimitDoc {
  /** Timestamps of recent requests (epoch ms) */
  timestamps: number[];
  /** Last cleanup time */
  lastCleanup: number;
}

/**
 * Check and record a request against the rate limit.
 *
 * Uses a single Firestore document per user+bucket with an array
 * of recent request timestamps. Old entries are pruned on each check
 * to keep the document small.
 *
 * @throws {RateLimitError} if the user has exceeded their limit
 */
export async function checkRateLimit(
  uid: string,
  operation: OperationType
): Promise<void> {
  const config = operation === "write" ? WRITE_LIMITS : READ_LIMITS;
  const bucket = `${uid}_${operation}`;
  const docRef = db().collection(COLLECTION).doc(bucket);
  const now = Date.now();
  const shortCutoff = now - config.shortWindowSec * 1000;
  const longCutoff = now - config.longWindowSec * 1000;

  await admin.firestore().runTransaction(async (tx) => {
    const snap = await tx.get(docRef);
    let timestamps: number[] = [];

    if (snap.exists) {
      const data = snap.data() as RateLimitDoc;
      // Prune entries older than the longest window
      timestamps = data.timestamps.filter((t) => t > longCutoff);
    }

    // Count requests in each window
    const shortCount = timestamps.filter((t) => t > shortCutoff).length;
    const longCount = timestamps.length;

    // Check short window
    if (shortCount >= config.shortWindowMax) {
      const oldestInWindow = timestamps.filter((t) => t > shortCutoff)[0];
      const retryAfter = Math.ceil(
        (oldestInWindow + config.shortWindowSec * 1000 - now) / 1000
      );
      throw new RateLimitError(Math.max(retryAfter, 1));
    }

    // Check long window
    if (longCount >= config.longWindowMax) {
      const oldestInWindow = timestamps[0];
      const retryAfter = Math.ceil(
        (oldestInWindow + config.longWindowSec * 1000 - now) / 1000
      );
      throw new RateLimitError(Math.max(retryAfter, 1));
    }

    // Record this request
    timestamps.push(now);
    tx.set(docRef, {
      timestamps,
      lastCleanup: now,
    } satisfies RateLimitDoc);
  });
}

/**
 * Classify a Cloud Function endpoint as read or write.
 *
 * Convention: function names ending in List, Get, Stats, or Search
 * are reads; everything else is a write.
 */
export function classifyOperation(functionName: string): OperationType {
  const readPatterns = [
    /list$/i,
    /get$/i,
    /stats$/i,
    /search$/i,
    /^search/i,
  ];
  return readPatterns.some((p) => p.test(functionName)) ? "read" : "write";
}
