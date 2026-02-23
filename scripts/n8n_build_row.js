/* 
  n8n Code Node — "Build Confluence Table Row"
  
  Place this BEFORE the HTTP Request GET node.
  It prepares all the data for the table row append.
  
  Input: Webhook payload from GitHub Actions
  Output: Structured data ready to build the XHTML row
*/

const items = $input.all();
const item = items[0];

// Extract fields from webhook payload
const jiraId = item.json.body?.jira_id || item.json.jira_id || 'NO-ID';
const author = item.json.body?.author || item.json.author || 'Unknown';
const reviewer = item.json.body?.reviewer || item.json.reviewer || 'Morgan Housel';
const prNumber = item.json.body?.pr_number || item.json.pr_number || '';
const prTitle = item.json.body?.pr_title || item.json.pr_title || '';
const prUrl = item.json.body?.pr_url || item.json.pr_url || '#';
const dbFiles = item.json.body?.db_files || item.json.db_files || 'No DB scripts changed';
const pageId = item.json.body?.page_id || item.json.page_id || '688129';
const timestamp = item.json.body?.timestamp || item.json.timestamp || new Date().toISOString();

// Build the new XHTML table row
const newRow = `<tr>
  <td><p><strong>${jiraId}</strong></p></td>
  <td><p>${author}</p></td>
  <td><p><a href="${prUrl}">Pull request ${prNumber}: ${prTitle.substring(0, 50)}</a></p></td>
  <td><p>${dbFiles}</p></td>
  <td><p>${reviewer}</p></td>
</tr>`;

item.json.new_row = newRow;
item.json.page_id = pageId;
item.json.jira_id = jiraId;
item.json.pr_link = `<a href="${prUrl}">PR #${prNumber}</a>`;

return items;
