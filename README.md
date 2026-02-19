# 🚀 Agentic Documentation System

An automated pipeline that syncs your code changes to **Confluence** documentation — powered by **GitHub Actions**, **n8n**, and **AI**.

## How It Works

```
Git Push → GitHub Actions → n8n Webhook → AI (XHTML) → Confluence API
                                                            ↑
                                        Cursor IDE (MCP) ───┘
```

1. You push code with a `[DocUpdate: PAGE_ID]` commit tag
2. GitHub Actions extracts the diff and sends it to n8n
3. n8n uses AI to convert the diff into Confluence XHTML
4. n8n updates the Confluence page via REST API
5. Cursor IDE reads Confluence pages via MCP for context-aware coding

## Quick Start

### Prerequisites
- [Atlassian Cloud account](https://www.atlassian.com/try/cloud/signup) (free tier)
- [n8n account](https://app.n8n.cloud/register) (Cloud or self-hosted)
- [GitHub account](https://github.com)
- [Cursor IDE](https://cursor.sh)
- [OpenAI API key](https://platform.openai.com/api-keys)

### Setup

1. **Clone & configure:**
   ```bash
   git clone https://github.com/YOUR_USERNAME/agentic-doc-system.git
   cd agentic-doc-system
   cp .env.example .env
   # Edit .env with your actual values
   ```

2. **Add GitHub Secrets** (Settings → Secrets → Actions):
   - `N8N_WEBHOOK_URL` — your n8n webhook production URL
   - `N8N_AUTH_TOKEN` — your webhook auth token
   - `CONFLUENCE_PAGE_ID` — default page ID (`688129`)

3. **Build the n8n workflow** — see the [Implementation Plan](docs/SETUP_GUIDE.md)

4. **Test the webhook:**
   ```powershell
   .\scripts\test-webhook.ps1 -WebhookUrl "YOUR_URL" -AuthToken "YOUR_TOKEN"
   ```

5. **Push with doc tag:**
   ```bash
   git commit -m "feat: add feature [DocUpdate: 688129]"
   git push origin main
   ```

## Project Structure

```
├── .cursor/
│   └── mcp.json              # Cursor MCP config for Atlassian
├── .cursorrules               # AI coding rules & doc conventions
├── .github/
│   └── workflows/
│       └── doc-sync.yml       # CI/CD pipeline
├── scripts/
│   └── test-webhook.ps1       # Manual webhook tester
├── src/
│   └── auth.py                # Sample application code
├── tests/
│   └── test_auth.py           # Unit tests
├── .env.example               # Environment variable template
└── README.md
```

## Commit Convention

Include `[DocUpdate: PAGE_ID]` in your commit message to trigger doc sync:

```bash
git commit -m "feat: updated auth logic [DocUpdate: 688129]"
```

Without the tag, the CI/CD pipeline skips the webhook call.

## Configuration

| Variable | Description |
|----------|-------------|
| `CONFLUENCE_SITE` | `pikachu28.atlassian.net` |
| `CONFLUENCE_SPACE_KEY` | `ED1` |
| `CONFLUENCE_PAGE_ID` | `688129` |
| `N8N_WEBHOOK_URL` | n8n webhook production URL |
| `N8N_AUTH_TOKEN` | Webhook authentication token |
| `OPENAI_API_KEY` | For AI diff-to-XHTML conversion |

## License

MIT
