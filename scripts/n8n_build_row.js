/*
  n8n Node 2: "Build Row"
  
  Extracts all PR data from webhook, decodes the full diff,
  and composes a rich AI prompt for ALL changes (not just DB).
  
  Input:  Webhook payload from GitHub Actions
  Output: Structured data + ai_prompt field for the AI Agent node
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
const filesChanged = src.files_changed ?? src.db_files ?? 'No files listed';
const fileCount = src.file_count ?? '?';
const pageId = src.page_id ?? '688129';
const repository = src.repository ?? '';

// Decode the full diff (base64 → readable text)
let fullDiff = 'Diff not available';
try {
  const b64 = src.diff_base64 ?? src.db_diff_base64 ?? '';
  if (b64) {
    fullDiff = Buffer.from(b64, 'base64').toString('utf-8');
  }
} catch (e) {
  fullDiff = 'Could not decode diff: ' + e.message;
}

// Truncate diff to fit within LLM context limits (~2000 chars)
const truncatedDiff = fullDiff.length > 2000
  ? fullDiff.substring(0, 2000) + '\n... [diff truncated]'
  : fullDiff;

// Compose the AI prompt — covers ALL changes, not just DB
item.json.ai_prompt = `You are a senior software engineer writing a concise Confluence changelog entry.

Analyze the pull request below and write a 2-3 sentence plain-English summary that:
1. States WHAT was changed (files/modules affected)
2. States WHY or WHAT PURPOSE the change serves
3. Notes any important technical details (schema changes, API changes, breaking changes)

Rules:
- No markdown, no bullet points, no headings — plain text only
- Maximum 60 words
- Be specific about what actually changed

Pull Request: #${prNumber} — ${prTitle}
Author: ${author}
Repository: ${repository}
Files Changed (${fileCount} files): ${filesChanged}

Full Diff:
${truncatedDiff}

Write ONLY the summary paragraph, nothing else.`;

// Pass all fields through for downstream nodes
item.json.jira_id = jiraId;
item.json.author = author;
item.json.reviewer = reviewer;
item.json.pr_number = prNumber;
item.json.pr_title = prTitle;
item.json.pr_url = prUrl;
item.json.files_changed = filesChanged;
item.json.file_count = fileCount;
item.json.page_id = pageId;

return items;
