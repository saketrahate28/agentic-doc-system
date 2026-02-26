/*
  ============================================================
  UPDATED n8n WORKFLOW — with AI Agent Node
  ============================================================

  New 7-node pipeline:
  1. Webhook          → Receives PR merge payload from GitHub Actions
  2. Build Row        → Extracts & structures PR/Jira/DB data
  3. AI Agent         → Generates human-readable DB change summary
  4. Merge AI Output  → Combines AI summary back into the row data
  5. GET Page         → Fetches current Confluence page + version
  6. Append Row       → Appends new table row with AI summary
  7. PUT Page         → Publishes updated page to Confluence

  ──────────────────────────────────────────────────────────
  NODE 2: "Build Row" — Code Node (JavaScript)
  Purpose: Extract fields from webhook, prepare for AI Agent
  ──────────────────────────────────────────────────────────
*/

const items = $input.all();
const item = items[0];

// Support both nested body (n8n wraps POST body) and flat
const src = item.json.body ?? item.json;

const jiraId = src.jira_id ?? 'NO-ID';
const author = src.author ?? 'Unknown';
const reviewer = src.reviewer ?? 'Morgan Housel';
const prNumber = src.pr_number ?? '';
const prTitle = src.pr_title ?? '';
const prUrl = src.pr_url ?? '#';
const dbFiles = src.db_files ?? 'No DB scripts changed';
const pageId = src.page_id ?? '688129';
const hasDb = src.has_db_changes === 'true';

// Decode the base64 diff so AI Agent can read it
let dbDiff = 'No diff available';
if (src.db_diff_base64) {
  try {
    dbDiff = Buffer.from(src.db_diff_base64, 'base64').toString('utf-8');
  } catch (e) {
    dbDiff = atob(src.db_diff_base64);
  }
}

// Compose the AI prompt — will be consumed by the AI Agent node
item.json.ai_prompt = `You are a technical documentation assistant.

A developer just merged a Pull Request. Analyze the database change below and write a 
ONE-sentence plain-English summary suitable for a Confluence changelog table cell.

Requirements:
- Max 20 words
- Must mention what table/object changed and WHY
- No markdown, no bullet points — plain text only
- Example: "Added auth_log table to track login events per user session."

Jira Story: ${jiraId}
PR Title: ${prTitle}

DB Files Changed:
${dbFiles}

SQL Diff:
${dbDiff.substring(0, 800)}

Respond with ONLY the one-sentence summary.`;

// Pass all fields through for later nodes
item.json.jira_id = jiraId;
item.json.author = author;
item.json.reviewer = reviewer;
item.json.pr_number = prNumber;
item.json.pr_title = prTitle;
item.json.pr_url = prUrl;
item.json.db_files = dbFiles;
item.json.page_id = pageId;

return items;
