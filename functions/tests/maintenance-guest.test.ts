/**
 * The two predicates that decide whether a guest account gets deleted.
 *
 * They are small and pure, and they are where the dangerous mistake lives:
 * picking `lastSignInTime` over `lastRefreshTime` would delete active users
 * and every test below would still have looked reasonable.
 *
 * NEGATIVE-CONTROL: RUN 2026-08-25. Making `lastActive` prefer
 * `lastSignInTime` reddens "prefers lastRefreshTime" and "a guest using the
 * app daily is NOT idle"; dropping the `providerData` clause from
 * `isPlainGuest` reddens "an account with a federated provider is not a plain
 * guest".
 */
import { lastActive, isPlainGuest } from "../src/functions/maintenance";

const CREATED = "2026-05-01T10:00:00.000Z";

// Only the fields these predicates read. The real UserRecord is a class with
// a great deal else on it, none of which either function touches.
const user = (over: Record<string, unknown> = {}) =>
  ({
    uid: "guest-1",
    email: undefined,
    phoneNumber: undefined,
    providerData: [],
    disabled: false,
    metadata: { creationTime: CREATED, lastSignInTime: CREATED, lastRefreshTime: undefined },
    ...over,
    // eslint-disable-next-line @typescript-eslint/no-explicit-any
  }) as any;

describe("lastActive", () => {
  it("prefers lastRefreshTime over lastSignInTime", () => {
    // THE point of the whole file. An anonymous session persists in the
    // keychain and never signs in a second time, so lastSignInTime stays at
    // the moment the user first tapped "Continue as guest" — for ever, however
    // much they use the app. lastRefreshTime is the one that moves.
    const u = user({
      metadata: {
        creationTime: CREATED,
        lastSignInTime: CREATED,
        lastRefreshTime: "2026-08-25T09:00:00.000Z",
      },
    });
    expect(lastActive(u)).toBe(new Date("2026-08-25T09:00:00.000Z").getTime());
  });

  it("a guest using the app daily is NOT idle", () => {
    const now = new Date("2026-08-25T10:00:00.000Z").getTime();
    const u = user({
      metadata: {
        creationTime: CREATED,           // signed up in May
        lastSignInTime: CREATED,         // and never signed in again
        lastRefreshTime: "2026-08-25T08:00:00.000Z", // but opened it two hours ago
      },
    });
    expect(now - lastActive(u)).toBeLessThan(14 * 24 * 60 * 60 * 1000);
  });

  it("falls back to lastSignInTime when there is no refresh time", () => {
    expect(lastActive(user())).toBe(new Date(CREATED).getTime());
  });

  it("falls back to creationTime when there is neither", () => {
    const u = user({ metadata: { creationTime: CREATED } });
    expect(lastActive(u)).toBe(new Date(CREATED).getTime());
  });

  it("an abandoned E2E guest IS idle", () => {
    const now = new Date("2026-08-25T10:00:00.000Z").getTime();
    expect(now - lastActive(user())).toBeGreaterThan(14 * 24 * 60 * 60 * 1000);
  });
});

describe("isPlainGuest", () => {
  it("a bare anonymous account is a plain guest", () => {
    expect(isPlainGuest(user())).toBe(true);
  });

  it("an account with an email is not", () => {
    expect(isPlainGuest(user({ email: "juancarlos.celis@outlook.com" }))).toBe(false);
  });

  it("an account with a federated provider is not a plain guest", () => {
    // Sign in with Apple + Hide My Email: the relay address may be absent from
    // some views, so providerData is checked separately and not as a proxy.
    expect(isPlainGuest(user({ providerData: [{ providerId: "apple.com" }] }))).toBe(false);
  });

  it("an account with a phone number is not", () => {
    expect(isPlainGuest(user({ phoneNumber: "+353871234567" }))).toBe(false);
  });

  it("a paired AI assistant is not", () => {
    expect(isPlainGuest(user({ uid: "ai_7527e16413b71d0a8dfe7e14" }))).toBe(false);
  });

  it("an already-disabled account is left alone", () => {
    // Somebody disabled it deliberately — a revoked assistant, or a decision
    // taken in the console. Not this sweep's business to finish the job.
    expect(isPlainGuest(user({ disabled: true }))).toBe(false);
  });

  it("the App Review account is not a plain guest", () => {
    expect(isPlainGuest(user({ uid: "appreview", email: "appreview@pacelli.app" }))).toBe(false);
  });
});
