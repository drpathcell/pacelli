/**
 * Authentication middleware for Pacelli Cloud Functions.
 *
 * Verifies Firebase ID tokens and loads the household encryption key
 * for every authenticated request.
 */
import * as admin from "firebase-admin";
import { loadHouseholdKey, resolveHouseholdId } from "../crypto/key-manager";

/**
 * Authenticated request context — available to all API handlers.
 */
export interface AuthContext {
  /** Firebase UID of the authenticated user */
  uid: string;
  /** The user's household ID */
  householdId: string;
  /** Decrypted household encryption key (64-char hex) */
  householdKey: string;
}

/**
 * Authenticates a request and returns the full context needed for API operations.
 *
 * 1. Verifies the Firebase ID token from the Authorization header
 * 2. Resolves the user's household ID
 * 3. Loads and decrypts the household encryption key
 *
 * Throws descriptive errors if any step fails.
 */
export async function authenticateRequest(
  authHeader: string | undefined
): Promise<AuthContext> {
  // 1. Extract and verify token
  if (!authHeader?.startsWith("Bearer ")) {
    throw new AuthError("Missing or invalid Authorization header", 401);
  }

  const idToken = authHeader.slice(7);
  let uid: string;

  try {
    const decoded = await admin.auth().verifyIdToken(idToken);
    uid = decoded.uid;
  } catch (e) {
    throw new AuthError("Invalid or expired token", 401);
  }

  // 2. Resolve household
  const householdId = await resolveHouseholdId(uid);
  if (!householdId) {
    throw new AuthError("User is not a member of any household", 403);
  }

  // 3. Load encryption key
  const householdKey = await loadHouseholdKey(uid, householdId);
  if (!householdKey) {
    throw new AuthError("Could not load household encryption key", 500);
  }

  return { uid, householdId, householdKey };
}

/**
 * Custom error class for auth failures with HTTP status codes.
 */
export class AuthError extends Error {
  constructor(
    message: string,
    public readonly statusCode: number
  ) {
    super(message);
    this.name = "AuthError";
  }
}
