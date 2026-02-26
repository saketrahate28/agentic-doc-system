/*
  ──────────────────────────────────────────────────────────
  NODE 6: "Append Row" — Code Node (JavaScript)
  
  This runs AFTER:
    - "Build Row" node (has jira_id, pr_url, etc.)
    - AI Agent node   (has the AI-generated summary)
    - GET Page node   (has current page version + XHTML body)
  
  It builds the updated Confluence XHTML page body with the
  new row appended, and the AI summary in the Pkg Changes column.
  ──────────────────────────────────────────────────────────
*/

const items = $input.all();
const item = items[0];

// ── Data from previous nodes ──────────────────────────────

// From GET Confluence page
const currentVersion = item.json.version?.number ?? 1;
const currentBody = item.json.body?.storage?.value ?? '';

// From "Build Row" node
const buildRow = $('Build Row').item.json;
const pageId = buildRow.page_id ?? '688129';
const jiraId = buildRow.jira_id ?? 'NO-ID';
const author = buildRow.author ?? 'Unknown';
const reviewer = buildRow.reviewer ?? 'Morgan Housel';
const prNumber = buildRow.pr_number ?? '';
const prTitle = buildRow.pr_title ?? '';
const prUrl = buildRow.pr_url ?? '#';
const dbFiles = buildRow.db_files ?? '';

// ── AI Agent output ──────────────────────────────────────
// The AI Agent node outputs to item.json.output (for Basic LLM Chain)
// or item.json.text depending on the node type used
let aiSummary = '';

try {
  // Try different output paths depending on which AI node was used
  aiSummary = item.json.output           // AI Agent node
    ?? item.json.text             // Basic LLM Chain
    ?? item.json.choices?.[0]?.message?.content  // OpenAI direct
    ?? item.json.candidates?.[0]?.content?.parts?.[0]?.text  // Gemini direct
    ?? '';

  aiSummary = aiSummary.toString().trim().replace(/\n/g, ' ');
} catch (e) {
  aiSummary = '';
}

// Fallback: use DB files string if AI didn't produce output
const pkgChanges = aiSummary
  ? `${aiSummary}<br/><em style="font-size:11px;color:#666;">(Files: ${dbFiles})</em>`
  : dbFiles || 'No DB scripts changed';

// ── Build the new table row ──────────────────────────────

const newRow = `<tr>
  <td><p><strong><a href="https://pikachu28.atlassian.net/jira/software/projects/DEMO/boards">${jiraId}</a></strong></p></td>
  <td><p>${author}</p></td>
  <td><p><a href="${prUrl}">Pull request ${prNumber}: ${prTitle.substring(0, 60)}</a></p></td>
  <td><p>${pkgChanges}</p></td>
  <td><p>${reviewer}</p></td>
</tr>`;

// ── Append to existing or create new table ───────────────

let updatedBody;

if (currentBody.includes('<table>') || currentBody.includes('<table ')) {
  if (currentBody.includes('</tbody>')) {
    updatedBody = currentBody.replace('</tbody>', `${newRow}\n</tbody>`);
  } else {
    updatedBody = currentBody.replace('</table>', `${newRow}\n</table>`);
  }
} else {
  // First run — create the table from scratch
  updatedBody = `
<h2>Database Changes Log</h2>
<p>Auto-maintained by the Agentic Documentation System. Updated on every PR merge to <code>main</code>.</p>
<table>
  <tbody>
    <tr>
      <th><p><strong>User Story</strong></p></th>
      <th><p><strong>User Name</strong></p></th>
      <th><p><strong>PR</strong></p></th>
      <th><p><strong>Pkg Changes (DB Scripts)</strong></p></th>
      <th><p><strong>Reviewer</strong></p></th>
    </tr>
    ${newRow}
  </tbody>
</table>
<p><em>Powered by n8n + AI Agent + GitHub Actions</em></p>`;
}

// ── Build the PUT body ───────────────────────────────────

item.json.put_body = {
  id: pageId,
  status: 'current',
  title: 'PI DB Changes - Automated Log',
  body: {
    representation: 'storage',
    value: updatedBody
  },
  version: {
    number: currentVersion + 1,
    message: `PR #${prNumber} merged: ${jiraId} by ${author}`
  }
};

return items;
