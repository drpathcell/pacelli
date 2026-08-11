/**
 * Push notifications — telling the OTHER person something happened.
 *
 * The server cannot read a task title: Pacelli is end-to-end encrypted and the
 * household key never leaves the members' devices. It does not need to. The
 * already-encrypted title is copied straight out of Firestore into the payload
 * as `enc_title`, and the Notification Service Extension on the recipient's
 * device opens it there (Phase C).
 *
 * Until that extension ships — and any time it fails, times out, or has no key
 * cached — iOS displays the generic `alert.body` the payload arrived with.
 * Degrading to privacy-safe text is the design, not a stopgap, and it is the
 * reason this is safe to send at all.
 *
 * Nothing here decrypts anything, and nothing here logs a title.
 */
import * as admin from "firebase-admin";
import { onDocumentCreated } from "firebase-functions/v2/firestore";
import { logger } from "firebase-functions";

const REGION = "us-central1";
const getDb = () => admin.firestore();

interface Target {
  token: string;
  ref: admin.firestore.DocumentReference;
}

/**
 * Every registered device in the household except the actor's own.
 *
 * Excluded by user_id, not by token: someone with two phones should not be
 * pinged on the second one for something they just did on the first.
 */
async function targets(
  householdId: string,
  exceptUid: string,
  requiresActivityOptIn: boolean
): Promise<Target[]> {
  const snap = await getDb()
    .collection("device_tokens")
    .where("household_id", "==", householdId)
    .get();
  return snap.docs
    .filter((d) => d.data().user_id !== exceptUid)
    // Opt-IN, and absence counts as off. Two people sharing one list generate
    // constant task churn, and a notification stream nobody asked for is how
    // an app teaches people to swipe it away without reading. Rare, important
    // events (someone joining) ignore this.
    .filter((d) => !requiresActivityOptIn || d.data().activity_push === true)
    .map((d) => ({ token: d.data().token as string, ref: d.ref }))
    .filter((t) => !!t.token);
}

/**
 * Send, then delete whatever APNs tells us is dead.
 *
 * Unregistered tokens are not an error to swallow — left in place they are
 * retried forever, and they quietly inflate every future send. Firestore is
 * the only registry we have, so it has to be the one that gets pruned.
 */
async function sendAll(
  targetList: Target[],
  bodyLocKey: string,
  data: Record<string, string>
): Promise<void> {
  if (targetList.length === 0) return;

  const res = await admin.messaging().sendEachForMulticast({
    tokens: targetList.map((t) => t.token),
    data,
    apns: {
      payload: {
        aps: {
          // `loc-key`, not literal text. This function has no idea what
          // language the recipient reads — it is a trigger, not a session —
          // so iOS resolves the key against the app's own Localizable
          // strings on the device. Sending English would have given every
          // Spanish and Italian user English notifications, and after the
          // extension lands, an English FALLBACK whenever decryption fails.
          // `locKey`, camelCase: the Admin SDK maps it to the wire's
          // `loc-key`. Writing the wire spelling here is a type error.
          alert: {
            title: "Pacelli",
            locKey: bodyLocKey,
          },
          // Lets the Notification Service Extension rewrite the body with the
          // decrypted title. On failure iOS keeps the localised loc-key text.
          "mutable-content": 1,
          sound: "default",
        },
      },
    },
  });

  const dead: admin.firestore.DocumentReference[] = [];
  res.responses.forEach((r, i) => {
    if (r.success) return;
    const code = r.error?.code ?? "";
    if (
      code === "messaging/registration-token-not-registered" ||
      code === "messaging/invalid-registration-token" ||
      code === "messaging/invalid-argument"
    ) {
      dead.push(targetList[i].ref);
    } else {
      logger.warn("push send failed", { code });
    }
  });
  await Promise.all(dead.map((ref) => ref.delete().catch(() => undefined)));
  logger.info("push sent", {
    attempted: targetList.length,
    ok: res.successCount,
    pruned: dead.length,
  });
}

/**
 * A new task appeared in the household.
 *
 * The body is generic and stays generic even after Phase C lands, because it
 * is what shows whenever decryption is not possible.
 */
export const onTaskCreated = onDocumentCreated(
  { document: "tasks/{taskId}", region: REGION },
  async (event) => {
    const task = event.data?.data();
    if (!task) return;
    const householdId = task.household_id as string | undefined;
    const author = task.created_by as string | undefined;
    if (!householdId || !author) return;

    const list = await targets(householdId, author, true);
    await sendAll(
      list,
      "push_task_created",
      {
        // The title travels as the SAME ciphertext already at rest in
        // Firestore. The server holds no key and performs no crypto.
        enc_title: typeof task.title === "string" ? task.title : "",
        kind: "task_created",
        task_id: event.params.taskId,
        household_id: householdId,
      }
    );
  }
);

/**
 * Someone joined the household.
 *
 * Deliberately carries no encrypted payload: there is no content to show, and
 * "someone joined" is the whole message.
 */
export const onMemberJoined = onDocumentCreated(
  { document: "household_members/{memberId}", region: REGION },
  async (event) => {
    const member = event.data?.data();
    if (!member) return;
    const householdId = member.household_id as string | undefined;
    const joiner = member.user_id as string | undefined;
    if (!householdId || !joiner) return;

    // Creating a household writes the founder's own member doc, which would
    // otherwise push "someone joined" to nobody in particular on every signup.
    const household = await getDb().collection("households").doc(householdId).get();
    if (household.exists && household.data()?.created_by === joiner) return;

    const list = await targets(householdId, joiner, false);
    await sendAll(
      list,
      "push_member_joined",
      { kind: "member_joined", household_id: householdId }
    );
  }
);
