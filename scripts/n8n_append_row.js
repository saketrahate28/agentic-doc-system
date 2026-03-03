/*
  n8n Node 5: "Append Row"
  
  Appends a new row to the Confluence table using:
  - Data from "Build Row" node (jira_id, author, pr, files)
  - AI-generated summary from the AI Agent node
  - Current page body + version from the GET Page node
*/

const items = $input.all();
const item = items[0];

// ── From GET Confluence page ──────────────────────────────
const currentVersion = item.json.version?.number ?? 1;
const currentBody = item.json.body?.storage?.value ?? '';

// ── From "Build Row" node ─────────────────────────────────
const buildRow = $('Build Row').item.json;
const pageId = buildRow.page_id ?? '688129';
const jiraId = buildRow.jira_id ?? 'NO-ID';
const author = buildRow.author ?? 'Unknown';
const reviewer = buildRow.reviewer ?? 'Morgan Housel';
const prNumber = buildRow.pr_number ?? '';
const prTitle = buildRow.pr_title ?? '';
const prUrl = buildRow.pr_url ?? '#';
const filesChanged = buildRow.files_changed ?? '';
const fileCount = buildRow.file_count ?? '?';

// ── AI Agent output ───────────────────────────────────────
// Tries multiple output paths depending on which AI node is used
let aiSummary = '';
try {
  aiSummary = (
    item.json.output                                                    // n8n AI Agent
    ?? item.json.text                                                   // Basic LLM Chain  
    ?? item.json.choices?.[0]?.message?.content                        // OpenAI direct
    ?? item.json.candidates?.[0]?.content?.parts?.[0]?.text           // Gemini direct
    ?? ''
  ).toString().trim().replace(/\n+/g, ' ');
} catch (e) { aiSummary = ''; }

// Fallback if AI didn't return anything
const summaryCell = aiSummary
  ? aiSummary
  : `Changed ${fileCount} file(s): ${filesChanged.substring(0, 150)}`;

// ── Build new table row ──────────────────────────────────
const prShortTitle = prTitle.substring(0, 60);
const newRow = `<tr>
  <td><p><strong>${jiraId}</strong></p></td>
  <td><p>${author}</p></td>
  <td><p><a href="${prUrl}">PR #${prNumber}: ${prShortTitle}</a></p></td>
  <td><p>${summaryCell}</p></td>
  <td><p>${reviewer}</p></td>
</tr>`;

// ── Append to existing table or create new one ────────────
let updatedBody;

if (currentBody.includes('<table')) {
  if (currentBody.includes('</tbody>')) {
    updatedBody = currentBody.replace('</tbody>', `${newRow}\n</tbody>`);
  } else {
    updatedBody = currentBody.replace('</table>', `${newRow}\n</table>`);
  }
} else {
  updatedBody = `
<h2>PR Changes Log — AI Summaries</h2>
<p>Auto-maintained by the Agentic Documentation System. Every merged PR adds a row.</p>
<table>
  <tbody>
    <tr>
      <th><p><strong>Story</strong></p></th>
      <th><p><strong>Author</strong></p></th>
      <th><p><strong>Pull Request</strong></p></th>
      <th><p><strong>AI Summary of Changes</strong></p></th>
      <th><p><strong>Reviewer</strong></p></th>
    </tr>
    ${newRow}
  </tbody>
</table>
<p><em>Powered by GitHub Actions + n8n + AI Agent</em></p>`;
}

// ── Build the final PUT payload ───────────────────────────
item.json.put_body = {
  id: pageId,
  status: 'current',
  title: 'PR Changes Log - AI Automated',
  body: {
    representation: 'storage',
    value: updatedBody
  },
  version: {
    number: currentVersion + 1,
    message: `PR #${prNumber} merged by ${author}: ${jiraId}`
  }
};

return items;
