/**
 * API client for calling Pacelli Cloud Functions.
 *
 * The MCP server acts as a thin wrapper — it forwards the user's
 * Firebase ID token to the Cloud Functions, which handle auth,
 * encryption, and Firestore access.
 */

export interface ApiClientConfig {
  /** Base URL of the Cloud Functions (e.g. https://us-central1-pacelli-app.cloudfunctions.net) */
  baseUrl: string;
  /** Async function that returns a valid Firebase ID token */
  tokenProvider: () => Promise<string>;
}

export class ApiClient {
  private baseUrl: string;
  private tokenProvider: () => Promise<string>;

  constructor(config: ApiClientConfig) {
    this.baseUrl = config.baseUrl.replace(/\/$/, ""); // Strip trailing slash
    this.tokenProvider = config.tokenProvider;
  }

  /**
   * Call a Cloud Function endpoint.
   * @param functionName - The exported function name (e.g. "tasksList")
   * @param body - Request body (JSON-serialisable)
   */
  async call<T = unknown>(
    functionName: string,
    body: Record<string, unknown> = {}
  ): Promise<T> {
    const url = `${this.baseUrl}/${functionName}`;
    const authToken = await this.tokenProvider();

    const response = await fetch(url, {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
        Authorization: `Bearer ${authToken}`,
      },
      body: JSON.stringify(body),
    });

    if (!response.ok) {
      const errorBody = await response.text();
      throw new Error(
        `API call ${functionName} failed (${response.status}): ${errorBody}`
      );
    }

    const json = (await response.json()) as { success: boolean; data?: T; error?: string };

    if (!json.success) {
      throw new Error(`API call ${functionName} returned error: ${json.error}`);
    }

    return json.data as T;
  }
}
