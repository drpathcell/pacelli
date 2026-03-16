/**
 * TokenManager — auto-refreshing Firebase ID tokens for the MCP server.
 *
 * Uses a service account to mint custom tokens for a designated service user,
 * then exchanges them for ID tokens via the Firebase Auth REST API.
 * Tokens are cached and refreshed 5 minutes before expiry.
 */
import admin from "firebase-admin";

const TOKEN_REFRESH_BUFFER_MS = 5 * 60 * 1000; // Refresh 5 min before expiry

export class TokenManager {
  private cachedToken: string | null = null;
  private expiresAt = 0;
  private refreshPromise: Promise<string> | null = null;

  private readonly serviceUserUid: string;
  private readonly firebaseApiKey: string;

  constructor() {
    const uid = process.env.MCP_SERVICE_USER_UID;
    const apiKey = process.env.FIREBASE_API_KEY;

    if (!uid || !apiKey) {
      throw new Error(
        "Missing required environment variables: MCP_SERVICE_USER_UID, FIREBASE_API_KEY"
      );
    }

    this.serviceUserUid = uid;
    this.firebaseApiKey = apiKey;

    // Initialize Firebase Admin if not already initialized
    if (admin.apps.length === 0) {
      admin.initializeApp({
        credential: admin.credential.applicationDefault(),
      });
    }
  }

  /**
   * Returns a valid Firebase ID token, refreshing if necessary.
   * Concurrent calls share the same refresh promise to avoid duplicate requests.
   */
  async getValidToken(): Promise<string> {
    if (this.cachedToken && Date.now() < this.expiresAt - TOKEN_REFRESH_BUFFER_MS) {
      return this.cachedToken;
    }

    // Deduplicate concurrent refresh calls
    if (!this.refreshPromise) {
      this.refreshPromise = this.refresh().finally(() => {
        this.refreshPromise = null;
      });
    }

    return this.refreshPromise;
  }

  private async refresh(): Promise<string> {
    // Step 1: Mint a custom token for the service user
    const customToken = await admin.auth().createCustomToken(this.serviceUserUid);

    // Step 2: Exchange for an ID token via Firebase Auth REST API
    const url = `https://identitytoolkit.googleapis.com/v1/accounts:signInWithCustomToken?key=${this.firebaseApiKey}`;

    const response = await fetch(url, {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({
        token: customToken,
        returnSecureToken: true,
      }),
    });

    if (!response.ok) {
      const errorBody = await response.text();
      throw new Error(`Token exchange failed (${response.status}): ${errorBody}`);
    }

    const data = (await response.json()) as {
      idToken: string;
      expiresIn: string;
    };

    this.cachedToken = data.idToken;
    this.expiresAt = Date.now() + parseInt(data.expiresIn, 10) * 1000;

    console.error("[TokenManager] Token refreshed, expires in", data.expiresIn, "seconds");

    return this.cachedToken;
  }
}

/** Singleton instance */
export const tokenManager = new TokenManager();
