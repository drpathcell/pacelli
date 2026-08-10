/**
 * Is the legacy grace clause active in firestore.rules?
 *
 * While the live App Store build predates `joined_via`, `joinAuthorised()`
 * short-circuits with `return true` so real users can still accept invites.
 * Proof-of-authorisation assertions must expect success during that window and
 * denial afterwards — gating on the rules file itself means they flip back the
 * moment the clause is deleted, with no test edit and no silent weakening.
 */
const fs = require('fs');
const path = require('path');

const RULES = fs.readFileSync(path.resolve(__dirname, '..', 'firestore.rules'), 'utf8');
const GRACE_ACTIVE = /function joinAuthorised\([^)]*\)\s*\{[\s\S]*?return true\s*\n/.test(RULES);

module.exports = { GRACE_ACTIVE };
