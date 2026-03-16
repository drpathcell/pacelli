# Pacelli — AI Integration Maintenance & Extension

## Overview
This skill covers maintenance, extension, and debugging of Pacelli's AI integration layer. The AI integration is a 5-layer stack: Cloud Functions REST API → MCP Server → Flutter AI Assistant screen → In-App AI Chat → Deployment (Docker/Cloud Run). Use this skill whenever you need to add a new API endpoint, register a new MCP tool or resource, update the OpenAPI spec, modify rate limiting, change the Flutter AI Assistant screen, modify the in-app AI chat, or debug connection issues.

## Project Location
The Pacelli project is at the user's local path (typically `~/Developer/pacelli`). In Cowork sessions it is mounted at `/sessions/*/mnt/pacelli/`.

## Architecture Overview

```
┌─────────────────────────────────────────────────────────────────┐
│  Flutter App                                                     │
│  ┌──────────────────────────────────────┐                       │
│  │  In-App AI Chat (FAB → ChatScreen)    │                       │
│  │  lib/features/ai_chat/               │                       │
│  │    data/chat_service.dart            │  ← Direct CF caller    │
│  │    data/chat_providers.dart          │  ← Riverpod state      │
│  │    presentation/screens/chat_screen  │  ← Full-screen chat    │
│  │    presentation/widgets/             │  ← Bubble, InputBar    │
│  ├──────────────────────────────────────┤                       │
│  │  AI Assistant Settings Screen         │                       │
│  │  lib/features/settings/               │                       │
│  │    data/ai_assistant_service.dart     │  ← Token gen, config  │
│  │    presentation/screens/              │                       │
│  │      ai_assistant_screen.dart         │  ← MCP setup UI       │
│  └──────────────────────────────────────┘                       │
│  MainShell (main_shell.dart) — center FAB opens chat            │
└───────────────┬──────────────────────────┬──────────────────────┘
                │ Firebase ID Token        │ Firebase ID Token
                │ (in-app chat)            │ (MCP external)
                ▼                          ▼
┌─────────────────────────────────────────────────────────────────┐
│  MCP Server  (mcp-server/)                                       │
│  ┌─────────────────┐  ┌──────────────────┐  ┌────────────────┐ │
│  │  Tools (25+)     │  │  Resources (4)    │  │  ApiClient     │ │
│  │  list_tasks      │  │  pacelli://schema │  │  api-client.ts │ │
│  │  create_task     │  │  pacelli://summary│  │  tokenProvider │ │
│  │  search          │  │  pacelli://capab. │  │  call(fn,args) │ │
│  │  ...             │  │  pacelli://diag.  │  └───────┬────────┘ │
│  └─────────────────┘  └──────────────────┘          │          │
│  ┌──────────────────────────────────────────────┐   │          │
│  │  TokenManager (token-manager.ts)              │   │          │
│  │  Service account → custom token → ID token    │   │          │
│  │  Auto-refresh with 5-min buffer               │   │          │
│  └──────────────────────────────────────────────┘   │          │
│  Hardening: rate limiting, session TTL, HTTPS,       │          │
│  default-deny origins, non-root container            │          │
│  Transport: --stdio (local) or --http (Cloud Run)    │          │
└──────────────────────────────────────────────────────┼──────────┘
                                                       │ HTTP POST
                                                       ▼
┌─────────────────────────────────────────────────────────────────┐
│  Cloud Functions  (functions/)                                    │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────────┐      │
│  │  apiHandler() │  │  Auth         │  │  Rate Limiter     │      │
│  │  index.ts     │  │  auth.ts      │  │  rate-limiter.ts  │      │
│  └──────┬───────┘  └──────────────┘  └──────────────────┘      │
│         │  routes to:                                            │
│  ┌──────┴───────────────────────────────────────────────┐       │
│  │  functions/tasks.ts   functions/inventory.ts          │       │
│  │  functions/plans.ts   functions/categories.ts         │       │
│  │  functions/checklists.ts  functions/attachments.ts    │       │
│  │  functions/search.ts     functions/feedback.ts       │       │
│  └───────────────────────────────────────────────────────┘       │
│  middleware/auth.ts — verifies token, resolves household, loads  │
│                       AES-256-CBC key for decryption             │
│  middleware/encryption.ts — createFieldCrypto(key) → dec/decN    │
│  middleware/rate-limiter.ts — Firestore sliding window            │
└─────────────────────────────────────────────────────────────────┘
                            │
                            ▼
┌─────────────────────────────────────────────────────────────────┐
│  Firestore (encrypted at rest)                                   │
│  Collections: tasks, subtasks, categories, checklists,           │
│  checklist_items, plans, plan_entries, plan_checklist_items,      │
│  inventory_items, inventory_categories, inventory_locations,      │
│  inventory_logs, inventory_attachments, task_attachments,         │
│  plan_attachments, manual_entries, manual_categories,             │
│  feedback, diagnostics, weekly_digests, _rate_limits              │
└─────────────────────────────────────────────────────────────────┘
```

## Key Files

| Concern                | File                                                    |
|------------------------|---------------------------------------------------------|
| API entry point        | `functions/src/index.ts`                                |
| Auth middleware         | `functions/src/middleware/auth.ts`                       |
| Encryption middleware   | `functions/src/middleware/encryption.ts`                 |
| Rate limiting          | `functions/src/middleware/rate-limiter.ts`               |
| Task business logic    | `functions/src/functions/tasks.ts`                       |
| Inventory logic        | `functions/src/functions/inventory.ts`                   |
| Plan logic             | `functions/src/functions/plans.ts`                       |
| Checklist logic        | `functions/src/functions/checklists.ts`                  |
| Category logic         | `functions/src/functions/categories.ts`                  |
| Attachment logic       | `functions/src/functions/attachments.ts`                 |
| Search logic           | `functions/src/functions/search.ts`                      |
| MCP server entry       | `mcp-server/src/index.ts`                               |
| MCP API client         | `mcp-server/src/api-client.ts`                          |
| MCP token manager      | `mcp-server/src/token-manager.ts`                       |
| Feedback logic         | `functions/src/functions/feedback.ts`                    |
| OpenAPI spec           | `openapi/pacelli-api.yaml`                              |
| AI Assistant service   | `lib/features/settings/data/ai_assistant_service.dart`  |
| AI Assistant screen    | `lib/features/settings/presentation/screens/ai_assistant_screen.dart` |
| In-App Chat service    | `lib/features/ai_chat/data/chat_service.dart`           |
| Chat state (Riverpod)  | `lib/features/ai_chat/data/chat_providers.dart`         |
| Chat models            | `lib/features/ai_chat/data/chat_models.dart`            |
| Chat screen            | `lib/features/ai_chat/presentation/screens/chat_screen.dart` |
| Chat widgets           | `lib/features/ai_chat/presentation/widgets/`            |
| Main shell (FAB)       | `lib/shared/widgets/main_shell.dart`                    |
| Dockerfile             | `mcp-server/Dockerfile`                                 |
| Cloud Build config     | `mcp-server/cloudbuild.yaml`                            |

## Common Tasks

### 1. Adding a New API Endpoint

This is the most common operation. Every new piece of data the AI should access needs a Cloud Function endpoint, an MCP tool, and an OpenAPI spec entry.

#### Step 1a: Create the business logic function

If the endpoint belongs to an existing domain (tasks, inventory, etc.), add it to the existing module. If it's a new domain, create a new file in `functions/src/functions/`.

File: `functions/src/functions/{domain}.ts`

Each function receives an `AuthContext` (with `uid`, `householdId`, `householdKey`) and a params object. Use `createFieldCrypto(ctx.householdKey)` from `../middleware/encryption` to get `dec()` and `decN()` helpers for decrypting encrypted fields.

```typescript
import { createFieldCrypto } from "../middleware/encryption";
import * as admin from "firebase-admin";

const db = admin.firestore();

export async function newFunction(
  ctx: { uid: string; householdId: string; householdKey: string },
  params: { /* typed params */ }
): Promise<unknown> {
  const { dec, decN } = createFieldCrypto(ctx.householdKey);
  // Query Firestore, decrypt fields, return result
  const snap = await db
    .collection("{collection}")
    .where("household_id", "==", ctx.householdId)
    .get();

  return snap.docs.map((d) => {
    const data = d.data();
    return {
      id: d.id,
      title: dec(data.title),           // Required encrypted field
      description: decN(data.description), // Nullable encrypted field
      status: data.status,               // Unencrypted structural field
    };
  });
}
```

**Encryption rules**: Human-readable text fields (titles, descriptions, names, notes) are encrypted with `_enc()` on write and decrypted with `dec()` on read. Structural metadata (IDs, booleans, timestamps, status enums, quantities, dates) stays unencrypted so Firestore can query on them.

#### Step 1b: Export the Cloud Function

File: `functions/src/index.ts`

Add the endpoint using the `apiHandler` wrapper. The naming convention is `{domain}{Action}` in camelCase:

```typescript
export const {domain}{Action} = apiHandler(async (ctx, body) => {
  const param1 = body.param1 as string;
  if (!param1) throw new Error("param1 is required");
  return {domain}.newFunction(ctx, { param1 });
});
```

For read-heavy endpoints that don't modify data, you can pass an explicit `operationHint` to the rate limiter:

```typescript
export const {domain}Stats = apiHandler(async (ctx) => {
  return {domain}.getStats(ctx);
}, "read");
```

The rate limiter auto-classifies based on the function name: names ending in `List`, `Get`, `Stats`, or `Search` are classified as "read" (100/min, 500/hour). Everything else is "write" (30/min, 200/hour). Use `operationHint` only when the auto-classification would be wrong.

#### Step 1c: Register the MCP tool

File: `mcp-server/src/index.ts`

Add the tool registration inside `_registerTools()`. This is important — tools registered outside `_registerTools()` will only work in stdio mode and silently not appear in HTTP sessions, because `_registerTools()` is called once for the stdio server and once per HTTP session.

The codebase has three tool patterns. Choose the right one for the situation:

**Pattern A: Single-action tool with parameters** (most common):
```typescript
server.registerTool(
  "tool_name",
  {
    description: "Clear, helpful description of what this tool does.",
    inputSchema: {
      param1: z.string().describe("What this parameter does"),
      param2: z.string().optional().describe("Optional parameter"),
    },
  },
  async (params) => {
    const data = await api.call("{domain}{Action}", params);
    return { content: [{ type: "text", text: JSON.stringify(data, null, 2) }] };
  }
);
```

**Pattern B: Parameterless tool** (stats, summary endpoints):
When a tool genuinely has no parameters, use `inputSchema: {}`. This matches the existing `get_task_stats` and `get_inventory_stats` tools. Even so, think about whether adding an optional filter would make the tool more useful — for example, a stats tool might benefit from an optional `operationType` parameter:
```typescript
// Simple parameterless tool (like get_task_stats)
server.registerTool(
  "get_{domain}_stats",
  {
    description: "Get {domain} statistics: ...",
    inputSchema: {},
  },
  async () => {
    const data = await api.call("{domain}Stats");
    return { content: [{ type: "text", text: JSON.stringify(data, null, 2) }] };
  }
);

// Better: parameterless with optional filter that makes the tool more useful
server.registerTool(
  "get_rate_limit_stats",
  {
    description: "Get current rate limit usage for the authenticated user.",
    inputSchema: {
      operationType: z.enum(["read", "write"]).optional()
        .describe("Check limits for read or write operations (default: both)"),
    },
  },
  async (params) => {
    const data = await api.call("rateLimitStatsGet", params);
    return { content: [{ type: "text", text: JSON.stringify(data, null, 2) }] };
  }
);
```

**Pattern C: Multi-action tool** (one tool with an `action` enum — used for CRUD on a resource):
```typescript
server.registerTool(
  "manage_{resource}",
  {
    description: "List, create, or delete {resource}.",
    inputSchema: {
      action: z.enum(["list", "create", "delete"]).describe("Action to perform"),
      name: z.string().optional().describe("Name (for create)"),
      {resource}Id: z.string().optional().describe("ID (for delete)"),
    },
  },
  async (params) => {
    switch (params.action) {
      case "list": {
        const data = await api.call("{domain}List");
        return { content: [{ type: "text", text: JSON.stringify(data, null, 2) }] };
      }
      case "create": {
        const data = await api.call("{domain}Create", { name: params.name });
        return { content: [{ type: "text", text: JSON.stringify(data, null, 2) }] };
      }
      case "delete": {
        await api.call("{domain}Delete", { {resource}Id: params.{resource}Id });
        return { content: [{ type: "text", text: "{Resource} deleted." }] };
      }
    }
  }
);
```

**Tool naming convention**:
- Snake case: `list_tasks`, `get_task`, `create_task`, `search`
- Multi-action: `manage_categories`, `manage_subtask`, `manage_checklist`
- Domain prefix for inventory: `list_inventory`, `get_inventory_item`, `manage_inventory_categories`

**Response formatting**: Most tools return raw JSON via `JSON.stringify(data, null, 2)`. For monitoring or stats tools, consider formatting the response as human-readable text so Claude can present it more naturally:
```typescript
// For monitoring/stats tools, formatted text is more useful than raw JSON
const message = `Rate Limit Status (${type})\n` +
  `Short window: ${used}/${max} (resets in ${resetSec}s)\n` +
  `Long window: ${longUsed}/${longMax}`;
return { content: [{ type: "text", text: message }] };
```

#### Step 1d: Add to the OpenAPI spec

File: `openapi/pacelli-api.yaml`

Add the endpoint under `paths` and any new schemas under `components/schemas`. All Pacelli endpoints are POST with JSON body:

```yaml
  /{domain}{Action}:
    post:
      tags:
        - {Domain}
      summary: Short description
      operationId: {domain}{Action}
      requestBody:
        required: true
        content:
          application/json:
            schema:
              type: object
              required:
                - param1
              properties:
                param1:
                  type: string
                  description: What this parameter does
      responses:
        "200":
          description: Success
          content:
            application/json:
              schema:
                allOf:
                  - $ref: "#/components/schemas/ApiResponse"
                  - type: object
                    properties:
                      data:
                        $ref: "#/components/schemas/{ReturnType}"
```

### 2. Adding a New Entity Type (Full Workflow)

When exposing an entirely new domain (e.g., household members, recipes, budgets) rather than adding a single endpoint to an existing domain, follow this expanded workflow. The existing codebase establishes a consistent pattern — every entity gets a **tool pair** at minimum:

| Entity     | List tool           | Get tool              | CRUD tool          |
|------------|--------------------|-----------------------|--------------------|
| Tasks      | `list_tasks`        | `get_task`            | `create_task`, `update_task`, `complete_task`, `delete_task` |
| Inventory  | `list_inventory`    | `get_inventory_item`  | `create_inventory_item`, `update_inventory_item`, `delete_inventory_item` |
| Checklists | `list_checklists`   | —                     | `create_checklist`, `manage_checklist` |
| Plans      | `list_plans`        | `get_plan`            | `create_plan`, `manage_plan` |

For a new entity, always create at least:

1. **Cloud Functions**: `{domain}List` (list all) + `{domain}Get` (get by ID). Add create/update/delete if the AI should be able to mutate data.
2. **MCP tools**: `list_{domain}` + `get_{domain}` as a pair. The list tool may have optional filter params; the get tool takes an ID with `z.string().describe(...)`.
3. **OpenAPI entries**: One entry per Cloud Function endpoint.
4. **Update `pacelli://schema` resource**: Add the new entity's fields to the schema resource in `_registerResources()` so AI assistants can discover the data model.

**Example — adding household members (list + get pair):**
```typescript
// List tool — no required params, optional filters
server.registerTool("list_household_members", {
  description: "List all members of the household with display names, emails, roles, and join dates.",
  inputSchema: {
    role: z.enum(["admin", "member"]).optional().describe("Filter by role"),
  },
}, async (params) => {
  const data = await api.call("householdMembersList", params);
  return { content: [{ type: "text", text: JSON.stringify(data, null, 2) }] };
});

// Get tool — takes an ID
server.registerTool("get_household_member", {
  description: "Get a single household member by user ID.",
  inputSchema: {
    userId: z.string().describe("The Firebase user ID of the member"),
  },
}, async ({ userId }) => {
  const data = await api.call("householdMembersGet", { userId });
  return { content: [{ type: "text", text: JSON.stringify(data, null, 2) }] };
});
```

### 3. Updating the MCP Server Resources

Resources are read-only data the AI can browse (like an API schema or household summary). They're registered in `_registerResources()` in `mcp-server/src/index.ts`.

The four existing resources:
- `pacelli://schema` — static JSON describing the data model (entities and their fields, including manualEntry, feedbackEntry, appDiagnostic, weeklyDigest)
- `pacelli://summary` — live data: task stats, inventory stats, checklist count, plan count
- `pacelli://capabilities` — static JSON catalogue of all 8 app feature groups (24 capabilities) with `aiSupported` flags and tool/resource cross-references
- `pacelli://diagnostics` — live 7-day error/warning/feedback sentiment summary via `diagnosticStatsGet` Cloud Function

To add a new resource:
```typescript
server.resource(
  "resource-name",        // Display name
  "pacelli://resource-id", // URI
  async () => ({
    contents: [{
      uri: "pacelli://resource-id",
      mimeType: "application/json",
      text: JSON.stringify(/* data */),
    }],
  })
);
```

If the resource fetches live data, wrap the API calls in try/catch and return a helpful fallback message on failure (see the `household-summary` resource for the pattern).

### 4. Modifying Rate Limiting

File: `functions/src/middleware/rate-limiter.ts`

The rate limiter uses a dual sliding window — a short window (per-minute) and a long window (per-hour). Current limits:

| Operation | Short window | Long window |
|-----------|-------------|-------------|
| Read      | 100 / min   | 500 / hour  |
| Write     | 30 / min    | 200 / hour  |

To change limits, update the `READ_LIMITS` and `WRITE_LIMITS` constants. The operation classification (`classifyOperation`) uses regex on the function name — if you add an endpoint whose name doesn't fit the pattern (doesn't end in List/Get/Stats/Search but is actually a read), either rename it or pass `operationHint: "read"` in the `apiHandler` call.

Rate limit data is stored in the `_rate_limits` Firestore collection with documents keyed by `{uid}_{read|write}`.

### 5. Updating the Flutter AI Assistant Screen

File: `lib/features/settings/presentation/screens/ai_assistant_screen.dart`
Service: `lib/features/settings/data/ai_assistant_service.dart`

The screen has 4 guided steps and a local/hosted mode toggle. Key widget patterns:
- `_SectionHeader(icon, title)` — section dividers
- `_CopyableField(label, value, obscure)` — monospace display with copy button
- `_ConfigBlock(fileName, code)` — dark code block for JSON config
- `_ConnectionStatusBanner(status)` — green/orange/red status
- `_WarningBanner(text)` — orange caution box
- `_TipItem(text)` — bullet point tip

The two config modes produce different JSON:
- **Local (stdio)**: `{ "mcpServers": { "pacelli": { "command": "node", "args": [...], "env": {...} } } }`
- **Hosted (HTTP)**: `{ "mcpServers": { "pacelli": { "type": "streamable-http", "url": "...", "headers": {...} } } }`

All UI strings use `context.l10n.aiAssistant*` keys — currently 34 keys across all 3 ARB files. Use the `/pacelli-add-arb-keys` skill when adding new strings.

### 6. In-App AI Chat

The in-app AI chat provides a natural-language interface directly inside the Flutter app. Users tap the center FAB (semicircle button above the bottom nav) on any tab to open a full-screen chat.

**Architecture:**
- **MainShell** (`lib/shared/widgets/main_shell.dart`) — Contains the center FAB that floats above the `NavigationBar`. Uses a 5-destination nav bar with index 2 as a disabled spacer. The FAB triggers `context.push(AppRoutes.aiChat)`.
- **ChatService** (`lib/features/ai_chat/data/chat_service.dart`) — Calls the `/aiChat` Cloud Function directly with Firebase ID tokens. Tokens are cached for 55 minutes with auto-refresh on 401.
- **ChatProviders** (`lib/features/ai_chat/data/chat_providers.dart`) — Riverpod state: `chatServiceProvider` (singleton), `chatMessagesProvider` (StateNotifier), `chatLoadingProvider`.
- **ChatScreen** (`lib/features/ai_chat/presentation/screens/chat_screen.dart`) — Full-screen chat with message list, empty state with suggestion chips, auto-scroll.
- **ChatBubble** / **ChatInputBar** — UI widgets for message rendering and text input.
- **ChatModels** (`lib/features/ai_chat/data/chat_models.dart`) — `ChatRole`, `ChatMessageStatus`, `ChatMessage`, `ActionConfirmation`.

**Key patterns:**
- The chat FAB uses a gradient + glow matching the current theme's primary colour
- The `NavigationBar` has 5 destinations: Home, Tasks, (spacer), Calendar, Settings. Tab index mapping skips index 2
- The `/aiChat` route uses `CustomTransitionPage` with a bottom-to-top slide transition
- `ActionConfirmation` allows the AI to ask for user confirmation before executing write operations inline in the chat

**Adding new chat intents:**
The MVP uses keyword matching in the `aiChat` Cloud Function. To add a new intent:
1. Add a new condition block in `functions/src/index.ts` under the `aiChat` export
2. Call the relevant existing Pacelli functions (tasks, inventory, plans, etc.)
3. Format a natural-language reply
4. In the future, this will be replaced by LLM function-calling with the full MCP tool set

**Chat l10n keys:** `aiChat*` prefix — `aiChatWelcomeTitle`, `aiChatWelcomeSubtitle`, `aiChatInputHint`, `aiChatSuggestion1/2/3`, plus `commonClear`.

### 7. Deployment

**Local development:**
```bash
# Cloud Functions — compile and run emulator
cd functions && npm run build && firebase emulators:start

# MCP server — stdio mode (for Claude Desktop)
cd mcp-server && npm run dev

# MCP server — HTTP mode (for testing hosted transport)
cd mcp-server && npm run dev:http
```

**Production deployment:**
```bash
# Cloud Functions → Firebase
cd functions && npm run build && firebase deploy --only functions

# Firestore rules & indexes
firebase deploy --only firestore:rules
firebase deploy --only firestore:indexes

# MCP server → Cloud Run
cd mcp-server && gcloud run deploy pacelli-mcp \
  --source . --region us-central1 --platform managed --allow-unauthenticated \
  --set-env-vars "PACELLI_API_URL=https://us-central1-pacelli-35621.cloudfunctions.net,MCP_ALLOWED_ORIGINS=http://localhost:3000,GOOGLE_APPLICATION_CREDENTIALS=/secrets/sa-key/service-account-key.json" \
  --set-secrets "FIREBASE_API_KEY=firebase-api-key:latest,MCP_SERVICE_USER_UID=mcp-service-uid:latest,/secrets/sa-key/service-account-key.json=mcp-sa-key:latest" \
  --port 3000 --memory 256Mi --min-instances 0 --max-instances 3
```

Docker setup (`mcp-server/Dockerfile`): Multi-stage Node 20 slim build. Port 3000. Health check at `/health`. Runs as non-root user `appuser` (UID/GID 1001). CMD: `node dist/index.js --http`.

**MCP Server Hardening** (implemented in `mcp-server/src/index.ts`):
- **Rate limiting**: 100 requests/min per IP, sliding window, returns 429 with `Retry-After` header
- **Session timeouts**: 30-minute idle TTL, 60-second cleanup interval
- **HTTPS enforcement**: `PACELLI_API_URL` must use `https://` in HTTP mode
- **Default-deny origins**: `MCP_ALLOWED_ORIGINS` must be explicitly set in HTTP mode or server refuses to start
- **Sanitized health endpoint**: Returns only `{"status":"ok"}`, no version or transport info

**Authentication** (`mcp-server/src/token-manager.ts`):
- Uses Firebase service account (`pacelli-mcp-sa`) to mint custom tokens via `admin.auth().createCustomToken()`
- Exchanges custom tokens for ID tokens via Firebase Auth REST API
- Auto-refreshes with 5-minute expiry buffer, deduplicates concurrent refresh requests
- No more manual token management — tokens never expire

**Secret Manager secrets** (project: `pacelli-35621`):
- `firebase-api-key` — Firebase web API key for token exchange
- `mcp-service-uid` — Firebase UID of the service user to impersonate
- `mcp-sa-key` — Service account key JSON (volume-mounted at `/secrets/sa-key/`)

**Cloud Run service**: `pacelli-mcp` in `us-central1`, URL: `https://pacelli-mcp-506154778945.us-central1.run.app`

### 8. Debugging Connection Issues

Common problems and how to fix them:

**"Missing required environment variables"** — The MCP server requires `PACELLI_API_URL`. In stdio mode, `PACELLI_AUTH_TOKEN` is also needed (for manual token). In HTTP mode with service account auth, the token manager handles tokens automatically via `GOOGLE_APPLICATION_CREDENTIALS`, `FIREBASE_API_KEY`, and `MCP_SERVICE_USER_UID`.

**"MCP_ALLOWED_ORIGINS must be set in HTTP mode"** — The server refuses to start without explicit allowed origins in HTTP mode (default-deny). Set `MCP_ALLOWED_ORIGINS` env var.

**401 Unauthorized from Cloud Functions** — In production (Cloud Run), the TokenManager auto-refreshes tokens so this shouldn't happen. If it does, check: (a) service account has Token Creator role, (b) `FIREBASE_API_KEY` is correct, (c) `MCP_SERVICE_USER_UID` is a valid Firebase UID. For stdio mode, regenerate token from the AI Assistant screen.

**429 Rate Limited** — Two layers of rate limiting: (1) MCP server level: 100 req/min per IP, (2) Cloud Functions level: dual sliding window in `_rate_limits` Firestore collection. Check `Retry-After` header. Adjust `READ_LIMITS`/`WRITE_LIMITS` in `rate-limiter.ts` for CF limits, or the constants in `startHttp()` in `index.ts` for MCP server limits.

**MCP tools not appearing in Claude** — Verify the MCP server compiles: `cd mcp-server && npm run build`. Check Claude Desktop logs for connection errors. For hosted mode, hit `/health` to confirm the server is running.

**Encryption errors ("Invalid IV length", "Bad decrypt")** — The household key in the auth middleware might be wrong. Verify `loadHouseholdKey()` in `auth.ts` returns a valid 64-character hex key for the user's household.

**Cloud Run deployment fails** — Check `gcloud run services describe pacelli-mcp --region us-central1` for error details. Common issues: missing IAM bindings on secrets, service account key format errors, or Docker build failures. Verify health: `curl https://pacelli-mcp-506154778945.us-central1.run.app/health`.

## Checklist for Every New Endpoint

- [ ] Business logic function created in `functions/src/functions/{domain}.ts`
- [ ] Encrypted fields use `dec()`/`decN()` for reads, `enc()`/`encN()` for writes
- [ ] Unencrypted structural fields (IDs, booleans, dates) left as-is
- [ ] Cloud Function exported in `functions/src/index.ts` with `apiHandler()` wrapper
- [ ] Naming convention: `{domain}{Action}` (camelCase) — e.g., `inventoryStats`, `tasksCreate`
- [ ] Rate limit classification is correct (auto or `operationHint`)
- [ ] MCP tool registered in `_registerTools()` in `mcp-server/src/index.ts`
- [ ] Tool uses `z` (zod) for input validation with `.describe()` on every parameter
- [ ] Tool returns `{ content: [{ type: "text", text: JSON.stringify(data, null, 2) }] }`
- [ ] OpenAPI spec entry added in `openapi/pacelli-api.yaml` with request/response schemas
- [ ] If adding a new entity type, add its schema to `components/schemas` in the OpenAPI spec
- [ ] If adding a new entity type, update the `pacelli://schema` resource in `_registerResources()`
- [ ] TypeScript compiles clean: `cd functions && npx tsc --noEmit` and `cd mcp-server && npx tsc --noEmit`
- [ ] If new UI strings are needed, add l10n keys with the `/pacelli-add-arb-keys` skill

## Common Pitfalls

- **Forgetting to register the tool in `_registerTools()`**: The tool function exists in `_registerTools()` which is called for both stdio and HTTP sessions. If you accidentally add it outside this function, it will only work in stdio mode and silently not appear in HTTP sessions.
- **Mismatched endpoint names**: The Cloud Function export name (e.g., `tasksCreate`) must exactly match what `api.call()` uses in the MCP server. There's no routing layer — the MCP server calls Cloud Functions by name.
- **Missing parameter validation in Cloud Functions**: The `apiHandler` wrapper doesn't validate request bodies. Validate required parameters at the top of each exported function with explicit `throw new Error("x is required")` checks.
- **Encrypting structural fields**: Don't encrypt fields Firestore needs to query on (status, dates, booleans, IDs, quantities). Only human-readable text gets encrypted.
- **Forgetting the dual transport**: Any change to tool registration must go inside `_registerTools()` or `_registerResources()` — these are called for both the single stdio server instance and for every HTTP session's server instance.
- **Stale tokens in testing**: Firebase ID tokens expire after ~1 hour. When testing locally, regenerate via the AI Assistant screen or `FirebaseAuth.instance.currentUser.getIdToken(forceRefresh: true)`.
