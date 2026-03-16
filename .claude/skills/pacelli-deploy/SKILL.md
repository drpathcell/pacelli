---
name: pacelli-deploy
description: >
  Deployment guide and checklist for Pacelli's infrastructure: Firebase (Firestore rules, indexes,
  Cloud Functions), Cloud Run (MCP server), and Google Cloud Secret Manager. Covers pre-deployment
  checks, deployment commands, post-deployment verification, and rollback procedures. Use whenever
  the user mentions deploy, release, push to production, update cloud functions, update firestore
  rules, deploy MCP server, Cloud Run, or any infrastructure deployment for Pacelli.
---

# Pacelli — Deployment Guide & Checklist

## Purpose
Step-by-step deployment procedures for all Pacelli infrastructure components. Use this skill when deploying Firebase resources, Cloud Functions, the MCP server to Cloud Run, or managing secrets.

## Project Location
Pacelli lives at the user's local path (typically `~/Developer/pacelli`). In Cowork sessions it is mounted at `/sessions/*/mnt/pacelli/`.

## Infrastructure Overview

| Component | Platform | Region | Project |
|-----------|----------|--------|---------|
| Firestore rules & indexes | Firebase | us-central1 | `pacelli-35621` |
| Cloud Functions | Firebase Functions | us-central1 | `pacelli-35621` |
| MCP Server | Cloud Run | us-central1 | `pacelli-35621` |
| Secrets | Secret Manager | — | `pacelli-35621` |

### Key Identifiers

| Resource | Value |
|----------|-------|
| Firebase project | `pacelli-35621` |
| Project number | `506154778945` |
| Cloud Run service | `pacelli-mcp` |
| Cloud Run URL | `https://pacelli-mcp-506154778945.us-central1.run.app` |
| MCP service account | `pacelli-mcp-sa@pacelli-35621.iam.gserviceaccount.com` |
| Compute default SA | `506154778945-compute@developer.gserviceaccount.com` |
| Service user UID | `0182eSESEkMSogpNER98VDRZrls32` |
| Secrets | `firebase-api-key`, `mcp-service-uid`, `mcp-sa-key` |

## Pre-Deployment Checklist

Before any deployment, verify:

- [ ] `gcloud` CLI is installed and authenticated: `gcloud auth list`
- [ ] Active project is correct: `gcloud config get-value project` → `pacelli-35621`
- [ ] Firebase CLI is installed: `firebase --version`
- [ ] Firebase project is set: `firebase use` → `pacelli-35621`
- [ ] Node.js 20+ installed: `node --version`
- [ ] TypeScript compiles cleanly:
  ```bash
  cd functions && npx tsc --noEmit
  cd ../mcp-server && npx tsc --noEmit
  ```
- [ ] Flutter app builds: `flutter analyze` (no errors)

## Phase 1: Deploy Firestore Rules

### When to deploy
After any change to `firestore.rules`.

### Commands
```bash
cd ~/Developer/pacelli
firebase deploy --only firestore:rules
```

### Verification
- Check Firebase Console → Firestore → Rules tab for updated rules
- Test a read/write from the app to confirm rules aren't too restrictive

### Key files
- `firestore.rules` — all security rules
- Collections requiring `isMember()`: tasks, subtasks, categories, checklists, checklist_items, scratch_plans, plan_entries, plan_checklist_items, task_attachments, plan_attachments, inventory_items, inventory_categories, inventory_locations, inventory_logs, inventory_attachments, manual_entries, manual_categories, feedback, diagnostics, weekly_digests

## Phase 2: Deploy Firestore Indexes

### When to deploy
After adding/removing entries in `firestore.indexes.json`. Required when queries use `where()` + `orderBy()` on different fields.

### Commands
```bash
cd ~/Developer/pacelli
firebase deploy --only firestore:indexes
```

### Verification
- Firebase Console → Firestore → Indexes tab — check all indexes show "Enabled" (may take a few minutes to build)
- Test the queries that depend on the new indexes from the app

### Key files
- `firestore.indexes.json` — all composite index definitions

### Common issue
If a query fails with `failed-precondition` error → likely a missing composite index. Add the index to `firestore.indexes.json` and redeploy.

## Phase 3: Deploy Cloud Functions

### When to deploy
After any change to files in `functions/src/`.

### Commands
```bash
cd ~/Developer/pacelli

# Deploy all functions
firebase deploy --only functions

# Deploy a specific function (faster)
firebase deploy --only functions:tasksList,functions:tasksCreate
```

### Pre-deploy
```bash
cd functions
npm ci
npx tsc --noEmit  # Must compile cleanly
cd ..
```

### Verification
- Firebase Console → Functions tab — check all functions show "Active"
- Check Cloud Functions logs: `firebase functions:log --only <functionName>`
- Test an API call from the app (e.g., open Tasks screen to trigger `tasksList`)

### Key files
- `functions/src/index.ts` — all exports and `apiHandler()` wrapper
- `functions/src/middleware/auth.ts` — authentication
- `functions/src/middleware/rate-limiter.ts` — rate limiting
- `functions/src/middleware/encryption.ts` — server-side field encryption
- `functions/src/crypto/key-manager.ts` — server-side key management
- `functions/src/functions/*.ts` — business logic per feature
- `functions/package.json` — dependencies
- `firebase.json` — functions config (`"source": "functions", "codebase": "default", "runtime": "nodejs20"`)

### Current function groups
- Tasks: 8 (tasksList, tasksGet, tasksCreate, tasksUpdate, tasksComplete, tasksReopen, tasksDelete, tasksStats)
- Subtasks: 3 (subtasksAdd, subtasksToggle, subtasksDelete)
- Categories: 3 (categoriesList, categoriesCreate, categoriesDelete)
- Checklists: 9 (checklistsList, checklistsGet, checklistsCreate, checklistsUpdate, checklistsDelete, checklistItemsAdd, checklistItemsToggle, checklistItemsDelete, checklistItemsPushAsTask)
- Plans: 15 (plans 5 + entries 3 + checklist items 4 + templates 3)
- Attachments: 7 (task 3 + plan 4)
- Inventory: 16 (items 5 + categories 3 + locations 3 + logs 2 + attachments 3 + inventoryStats)
- Feedback: 5 (feedbackList, diagnosticsList, diagnosticStatsGet, weeklyDigestGenerate, weeklyDigestList)
- AI Chat: 1 (aiChat)
- Search: 1 (searchAll)

## Phase 4: Deploy MCP Server to Cloud Run

### When to deploy
After any change to files in `mcp-server/src/`.

### Commands

#### Source-based deploy (recommended — Cloud Build handles Docker)
```bash
cd ~/Developer/pacelli

gcloud run deploy pacelli-mcp \
  --source ./mcp-server \
  --region us-central1 \
  --service-account pacelli-mcp-sa@pacelli-35621.iam.gserviceaccount.com \
  --set-env-vars "PACELLI_API_URL=https://us-central1-pacelli-35621.cloudfunctions.net,MCP_ALLOWED_ORIGINS=https://claude.ai" \
  --set-secrets "FIREBASE_API_KEY=firebase-api-key:latest,SERVICE_USER_UID=mcp-service-uid:latest" \
  --memory 256Mi \
  --cpu 1 \
  --min-instances 0 \
  --max-instances 3 \
  --timeout 300 \
  --allow-unauthenticated
```

#### Pre-deploy
```bash
cd mcp-server
npm ci
npx tsc --noEmit  # Must compile cleanly
cd ..
```

### Verification
```bash
# Check service status
gcloud run services describe pacelli-mcp --region us-central1

# Check health endpoint
curl https://pacelli-mcp-506154778945.us-central1.run.app/health
# Expected: {"status":"ok"}

# Check logs
gcloud run services logs read pacelli-mcp --region us-central1 --limit 50
```

### Key files
- `mcp-server/src/index.ts` — MCP server, tool/resource registration, hardening
- `mcp-server/src/api-client.ts` — API client with tokenProvider pattern
- `mcp-server/src/token-manager.ts` — Service account → custom token → ID token auto-refresh
- `mcp-server/Dockerfile` — Multi-stage build, non-root user, health check
- `mcp-server/package.json` — dependencies
- `mcp-server/tsconfig.json` — TypeScript config

### Environment & Secrets

| Variable | Source | Value |
|----------|--------|-------|
| `PACELLI_API_URL` | Env var | `https://us-central1-pacelli-35621.cloudfunctions.net` |
| `MCP_ALLOWED_ORIGINS` | Env var | `https://claude.ai` (comma-separated list) |
| `FIREBASE_API_KEY` | Secret Manager | Firebase Web API key |
| `SERVICE_USER_UID` | Secret Manager | Firebase UID of MCP service user |

## Phase 5: Secret Manager Operations

### View existing secrets
```bash
gcloud secrets list --project pacelli-35621
```

### Create a new secret
```bash
echo -n "secret-value" | gcloud secrets create SECRET_NAME \
  --data-file=- \
  --project pacelli-35621

# Grant access to Cloud Run service account
gcloud secrets add-iam-policy-binding SECRET_NAME \
  --member="serviceAccount:pacelli-mcp-sa@pacelli-35621.iam.gserviceaccount.com" \
  --role="roles/secretmanager.secretAccessor" \
  --project pacelli-35621
```

### Update an existing secret
```bash
echo -n "new-value" | gcloud secrets versions add SECRET_NAME --data-file=-
```

### Read a secret (for debugging)
```bash
gcloud secrets versions access latest --secret=SECRET_NAME
```

## Phase 6: Deploy Everything (Full Release)

For a full release, deploy in this order (dependencies flow top-down):

1. **Firestore rules** — security rules must be in place before data access
2. **Firestore indexes** — required by queries in Cloud Functions and app
3. **Cloud Functions** — API layer used by both app and MCP server
4. **MCP Server** — depends on Cloud Functions being deployed

```bash
cd ~/Developer/pacelli

# 1. Firestore
firebase deploy --only firestore:rules
firebase deploy --only firestore:indexes

# 2. Cloud Functions
firebase deploy --only functions

# 3. MCP Server (only if mcp-server/ changed)
gcloud run deploy pacelli-mcp \
  --source ./mcp-server \
  --region us-central1 \
  --service-account pacelli-mcp-sa@pacelli-35621.iam.gserviceaccount.com \
  --set-env-vars "PACELLI_API_URL=https://us-central1-pacelli-35621.cloudfunctions.net,MCP_ALLOWED_ORIGINS=https://claude.ai" \
  --set-secrets "FIREBASE_API_KEY=firebase-api-key:latest,SERVICE_USER_UID=mcp-service-uid:latest" \
  --memory 256Mi --cpu 1 --min-instances 0 --max-instances 3 --timeout 300 \
  --allow-unauthenticated
```

### Post-release verification
- [ ] App opens and loads data (tasks, checklists, plans, inventory, manual)
- [ ] Feedback submission works
- [ ] MCP health endpoint returns 200
- [ ] Cloud Functions logs show no errors: `firebase functions:log`
- [ ] Cloud Run logs show no errors: `gcloud run services logs read pacelli-mcp --region us-central1 --limit 20`

## Rollback Procedures

### Cloud Functions
Firebase keeps previous versions. To rollback:
```bash
# Re-deploy from a previous git commit
git checkout <previous-commit> -- functions/
firebase deploy --only functions
git checkout HEAD -- functions/  # Restore working tree
```

### Cloud Run
```bash
# List revisions
gcloud run revisions list --service pacelli-mcp --region us-central1

# Route 100% traffic to a previous revision
gcloud run services update-traffic pacelli-mcp \
  --region us-central1 \
  --to-revisions <revision-name>=100
```

### Firestore Rules
```bash
# Re-deploy from a previous git commit
git show <previous-commit>:firestore.rules > /tmp/firestore.rules.backup
cp /tmp/firestore.rules.backup firestore.rules
firebase deploy --only firestore:rules
git checkout HEAD -- firestore.rules  # Restore working tree
```

## Troubleshooting

| Issue | Likely Cause | Fix |
|-------|-------------|-----|
| `firebase deploy` — "No active project" | `.firebaserc` missing or wrong | `firebase use pacelli-35621 --alias default` |
| `firebase deploy --only functions` — "No functions source" | Missing `functions` config in `firebase.json` | Add `{"source": "functions", "codebase": "default", "runtime": "nodejs20"}` |
| Cloud Functions deploy warning about cleanup policy | Not a real error — just a cleanup policy notice | Ignore |
| `failed-precondition` on Firestore query | Missing composite index | Add to `firestore.indexes.json` and deploy |
| Cloud Run — "Permission denied on secret" | Service account missing Secret Accessor role | `gcloud secrets add-iam-policy-binding <secret> --member="serviceAccount:pacelli-mcp-sa@..." --role="roles/secretmanager.secretAccessor"` |
| Cloud Run — "Secret Manager API not enabled" | API not enabled on project | `gcloud services enable secretmanager.googleapis.com` |
| MCP server — "HTTPS required" | `PACELLI_API_URL` doesn't start with `https://` | Fix the env var value |
| MCP server — "Allowed origins required" | `MCP_ALLOWED_ORIGINS` is empty | Set to `https://claude.ai` (or comma-separated list) |
| MCP server — 429 Too Many Requests | Per-IP rate limit (100/min) exceeded | Wait for `Retry-After` seconds, or check for request loops |
| Token refresh failures in Cloud Run logs | Service account missing `roles/firebase.sdkAdminServiceAgent` or service user doesn't exist in Firebase Auth | Verify service user UID exists, verify SA permissions |

## When to Use This Skill

| Trigger | Phases to run |
|---------|---------------|
| Changed `firestore.rules` | Phase 1 |
| Changed `firestore.indexes.json` | Phase 2 |
| Changed files in `functions/src/` | Phase 3 |
| Changed files in `mcp-server/src/` | Phase 4 |
| Need to add/update a secret | Phase 5 |
| Full release | Phase 6 |
| Something broke in production | Troubleshooting table |
