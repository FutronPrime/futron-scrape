<p align="center">
  <img src="docs/logo.png" alt="futron-scrape logo" width="180">
</p>

<h1 align="center">futron-scrape</h1>

<p align="center">
  <b>Universal free OSS web-scraping cascade.</b><br>
  Drop-in replacement for paid Firecrawl / billed <code>WebFetch</code> in any Claude Code, Codex, or agent harness.
</p>

<p align="center">
  <a href="LICENSE"><img alt="MIT License" src="https://img.shields.io/badge/license-MIT-22d3ee?style=flat-square"></a>
  <img alt="9-tier cascade" src="https://img.shields.io/badge/cascade-9_tiers-8b5cf6?style=flat-square">
  <img alt="No keys required" src="https://img.shields.io/badge/keys-optional-84cc16?style=flat-square">
  <a href="docs/DESIGN.md"><img alt="DESIGN.md" src="https://img.shields.io/badge/DESIGN.md-included-14b8a6?style=flat-square"></a>
</p>

---

A single

A single `futron-scrape <url>` walks 9 tiers in priority order and returns clean markdown (or JSON, or raw HTML) the moment one tier produces useful content. Works on:

- 🟢 **Public APIs the open web already exposes** — Reddit, Hacker News, Bluesky, Mastodon, GitHub, Stack Exchange, Wikipedia, npm, PyPI, Substack
- 🟢 **X / Twitter posts** without login (publish.twitter.com oembed)
- 🟢 **YouTube videos** with full description + auto-caption transcripts (yt-dlp)
- 🟢 **PDFs** (poppler `pdftotext`) and **images** (tesseract OCR)
- 🟢 **Generic blogs / docs / articles** via the free `r.jina.ai` reader
- 🟢 **Paywalled / dead pages** via Wayback + archive.is + 12ft.io
- 🟢 **JS-heavy SPAs** via headless Playwright
- 🟢 **Login-walled / fingerprinted sites** via macOS osascript driving your already-logged-in Chrome or Safari

When every OSS path is exhausted (real auth wall + no logged-in browser available), `futron-scrape` writes a structured queue file and returns exit `3` so a parent agent with a browser MCP (Claude-in-Chrome, Playwright MCP, computer-use MCP) can take over.

## Why?

- **Cost.** Firecrawl credits cost money. WebFetch in Claude Code is metered.
- **Auth.** Half the sites that matter sit behind login walls. The cleanest answer is the user's *already-open browser*.
- **Coverage.** "Just use jina" only takes you so far — Reddit, X, GitHub all return better data via their public APIs than via a generic reader.
- **Agent-friendly.** Single binary, predictable exit codes, JSON mode, structured agent-handoff queue. Drop into any harness.

## Install

```bash
git clone https://github.com/<your-org>/futron-scrape.git
cd futron-scrape
./install.sh
```

`install.sh` symlinks the four binaries into `~/.local/bin/` (creating it if needed) and prints which optional system deps you should install:

```bash
brew install yt-dlp poppler tesseract       # YouTube + PDF + image OCR (optional)
pip install playwright && playwright install chromium    # T8 headless browser (optional)
```

Each is **optional** — its tier just gets skipped if missing.

## Quick start

```bash
# Standard fetch — auto-cascades
futron-scrape https://news.ycombinator.com/item?id=39000000
futron-scrape https://en.wikipedia.org/wiki/Model_Context_Protocol
futron-scrape https://x.com/karpathy/status/1234567890

# Force JS-rendered fetch (skip cheap tiers)
futron-scrape --browser https://some-spa.example.com

# Allow paywall bypass
futron-scrape --paywall https://nytimes.com/article-url

# JSON output {url, source, length, body}
futron-scrape --json https://github.com/anthropics/anthropic-sdk-python

# Probe — which tier WOULD work, no body fetch
futron-scrape --probe https://example.com

# Pipe URL via stdin
echo "https://en.wikipedia.org/wiki/AI" | futron-scrape -
```

## Tier order

| # | Path | Best for |
|---|------|----------|
| T1 | Site-specific public APIs (Reddit `.json`, HN Algolia, Bluesky AT proto, Mastodon `/api/v1`, GitHub REST, Stack Exchange, Wikipedia, npm, PyPI, Substack) | Social posts + structured docs |
| T2 | `publish.twitter.com/oembed` | X / Twitter |
| T3 | `yt-dlp` (description + auto-captions) | YouTube |
| T4 | `pdftotext` / `tesseract` | PDFs + images |
| T5 | `r.jina.ai` reader | Generic blogs / docs / JS pages |
| T6 | Wayback / archive.is / 12ft.io (`--paywall`) | Paywalls + dead pages |
| T7 | Raw curl + HTML strip | Static HTML last resort |
| T8 | Playwright headless (`--browser`) | JS that jina can't render |
| T9 | osascript-driven logged-in Chrome / Safari (`futron-cua-fetch`) | macOS, login walls, fingerprinting |

When all 9 fail, exit code `3` is returned and a queue file is written at `${FUTRON_SCRAPE_STATE:-~/.config/futron-scrape}/scrape-requests/<hash>.json` containing `{url, mode, created, status: "pending"}`. A parent agent with a browser MCP (Claude-in-Chrome, Playwright MCP, computer-use MCP) can pick it up and fulfil it.

## Companion tools

### `futron-mcp-discover` — find an MCP server for any "trouble" site

```bash
futron-mcp-discover linkedin       # ranked GitHub repos + npm + curated tip
futron-mcp-discover slack          # same for Slack
futron-mcp-discover notion --install     # also stage top GitHub repo to ~/.config/futron-scrape/staged/
futron-mcp-discover --list         # full curated trouble-site map
futron-mcp-discover --json reddit  # JSON output
```

Searches the GitHub Search API (uses `GITHUB_TOKEN` if set), the npm registry, and a curated list of well-known OSS MCPs / clients per topic.

### `futron-bookmark-watcher` — poll a Dewey public bookmark folder hourly

If you use [Dewey](https://getdewey.co) for your X bookmarks, point this watcher at any public folder URL:

```bash
export FUTRON_BOOKMARK_URL="https://getdewey.co/users/<your-handle>/<folder-slug>/"
futron-bookmark-watcher                  # one-shot scan
futron-bookmark-watcher --install-safe   # also clone safe Skill repos
futron-bookmark-watcher --watch 3600     # continuous (or use launchd / cron)
```

Diffs against `${FUTRON_BOOKMARK_STATE:-~/.config/futron-scrape/bookmark-watcher}/seen.json`, classifies new tweets (`skill / mcp / cli-tool / repo / model / other`), writes per-tweet markdown to `${FUTRON_BOOKMARK_DIR:-~/.config/futron-scrape/bookmarks}/<date>/`.

### `futron-cua-fetch` — drive your logged-in browser via osascript

```bash
futron-cua-fetch <url>                 # markdown of body innerText
futron-cua-fetch --raw <url>           # outerHTML
futron-cua-fetch --queue <url>         # write request file only, agent picks up
futron-cua-fetch --browser chrome <url>
```

macOS only. Uses your live Chrome / Safari session — works on any login-walled site you're already signed into.

## Environment variables

All optional:

```
FUTRON_SCRAPE_TIMEOUT     per-source timeout in seconds (default 12)
FUTRON_SCRAPE_LOG         log path (default /tmp/futron-scrape.log)
FUTRON_SCRAPE_STATE       state dir (default ~/.config/futron-scrape)
FUTRON_BOOKMARK_URL       Dewey public folder URL (required by watcher)
FUTRON_BOOKMARK_DIR       memory output dir (watcher)
FUTRON_BOOKMARK_STATE     watcher state dir
GITHUB_TOKEN              raises GitHub rate to 5000/hr (T1 + discover)
TELEGRAM_BOT_TOKEN        watcher --notify
TELEGRAM_CHAT_ID          watcher --notify
```

No keys are required to start. Set what you have; the rest skips gracefully.

## Agent integration

For Claude Code / Codex / any harness, drop the included **Skill** into `~/.claude/skills/futron-scrape/` (see `skill/SKILL.md`). The agent will then call `futron-scrape` automatically when it needs to fetch a URL and your default fetch tool is unavailable / billed / blocked.

When `futron-scrape` exits 3, the agent should:

1. Read the queue file under `${FUTRON_SCRAPE_STATE}/scrape-requests/`.
2. Use whatever browser MCP is available (Claude-in-Chrome MCP for the user's live cookies, Playwright MCP, computer-use MCP).
3. Save the result and update the queue file's `status` to `"fulfilled"`.

## Exit codes

| Code | Meaning |
|------|---------|
| 0 | Body printed |
| 1 | All OSS tiers exhausted (page genuinely empty / unreachable) |
| 2 | Usage error |
| 3 | Login wall or fingerprinting — queue file written, agent should escalate via a browser MCP |

## License

MIT. See `LICENSE`.

## Origin

Extracted and sanitized from the FUTRON / OpenClaw stack. Designed to be drop-in elsewhere.
