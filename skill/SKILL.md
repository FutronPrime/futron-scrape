---
name: futron-scrape
description: Free OSS web scraping cascade — replaces Firecrawl/WebFetch with a 9-tier strategy that picks the right path automatically (site-specific public APIs → X-oembed → yt-dlp → PDF/OCR → jina reader → archive proxies → raw curl → Playwright headless → osascript-driven logged-in browser). Use when ANY of: WebFetch returns 402, Firecrawl runs out of credits, the URL needs login, the page is JS-heavy, the URL is a PDF/image, or you just want a free alternative. Also bundles `futron-mcp-discover` for finding open-source MCPs covering trouble sites (LinkedIn, Slack, Notion, Reddit, Discord, Threads, etc.).
---

# futron-scrape — Universal Free Web Scraper

## When to use this skill
Trigger any time you need to fetch a URL and any of these are true:
- Default `WebFetch` failed or is unavailable.
- The URL is auth-walled, JS-heavy, paywalled, or a PDF / image.
- You explicitly want a free / OSS path (no API credits, no billing).
- You want to **discover an open-source MCP** for a "trouble" site (LinkedIn, Slack, Notion, Discord, Threads, etc.).

## What it does
A bash CLI at `futron-scrape <url>` that walks 9 tiers, stopping at the first that returns useful content:

| Tier | Path | Best for |
|------|------|----------|
| T1 | Site-specific public APIs (Reddit `.json`, HN Algolia, Bluesky AT proto, Mastodon `/api/v1`, GitHub REST, StackExchange, Wikipedia, npm, PyPI, Substack RSS) | Social posts + structured docs |
| T2 | `publish.twitter.com/oembed` | X / Twitter posts (no auth) |
| T3 | `yt-dlp` (title + description + auto-captions) | YouTube videos |
| T4 | `pdftotext` (poppler) / `tesseract` OCR | PDFs + images |
| T5 | `r.jina.ai` reader | Generic blogs, docs, articles, JS-rendered pages |
| T6 | Wayback (`archive.org`), `archive.is`, `12ft.io` (with `--paywall`) | Paywalls + dead pages |
| T7 | Raw curl + HTML strip | Static HTML last resort |
| T8 | Playwright headless (with `--browser`; `pip install playwright`) | JS that jina can't render |
| T9 | `futron-cua-fetch` — osascript-driven logged-in Chrome/Safari (macOS) | Login walls, fingerprinting, session cookies |
| exit 3 | Queue request at `${FUTRON_SCRAPE_STATE:-~/.config/futron-scrape}/scrape-requests/<hash>.json` | Agent escalation needed |

## Calling it

```bash
# Standard fetch (cascades automatically)
futron-scrape https://news.ycombinator.com/item?id=39000000

# Force a JS-rendered fetch (skip cheap tiers)
futron-scrape --browser https://some-spa.example.com

# Allow paywall bypass (12ft.io)
futron-scrape --paywall https://nytimes.com/article

# Structured JSON output {url, source, length, body}
futron-scrape --json https://github.com/anthropics/anthropic-sdk-python

# Probe (which tier WOULD work — no body fetch)
futron-scrape --probe https://example.com

# Pipe URL via stdin
echo "https://en.wikipedia.org/wiki/AI" | futron-scrape -
```

## Exit codes
- `0` — body printed
- `1` — all OSS tiers exhausted (page genuinely empty or unreachable)
- `2` — usage error
- `3` — login wall / browser-needed; a queue file was written. **You should escalate** by:
  1. If you have `claude_in_chrome` MCP available, navigate to the URL there (uses live cookies).
  2. If you have `playwright_mcp` / `computer-use` MCP, use those.
  3. Otherwise, prompt the user to fetch it themselves and paste the body.

## Auth-wall escalation pattern (for agents)

When `futron-scrape` exits 3:

```
1. Read the queue file: cat ${FUTRON_SCRAPE_STATE:-~/.config/futron-scrape}/scrape-requests/<hash>.json
2. Use whatever browser MCP is available:
   - claude_in_chrome: navigate(url) → javascript_tool(...) to extract content
   - playwright_mcp: browser_navigate, browser_snapshot
   - computer-use: open_application "Google Chrome", navigate, screenshot, OCR
3. Save the result and update the queue file's "status" to "fulfilled".
```

## Companion: `futron-mcp-discover`
Finds open-source MCP servers + npm/PyPI packages for any "trouble site":

```bash
futron-mcp-discover linkedin       # ranked GitHub repos + npm + curated FUTRON tip
futron-mcp-discover slack          # same for Slack
futron-mcp-discover notion --install   # also stage top GitHub repo to ~/.openclaw/integrations/staged/
futron-mcp-discover --list         # full curated trouble-site map
futron-mcp-discover --json reddit  # JSON output for piping
```

The curated map flags `INTERNAL:` for tools the user already has installed (e.g. the optional internal tools (if you have them)) so the recommendation is "use what's already there" before suggesting an external package.

## Companion: `futron-bookmark-watcher`
Polls a Dewey public bookmark folder hourly via launchd, classifies new finds, writes per-tweet markdown to memory. Optional `--install-safe` clones recognized Skills + stages other repos. See `~/Library/LaunchAgents/com.futron.bookmark-watcher.plist`.

## Prereqs (graceful degradation — missing tools just skip their tier)
```bash
brew install yt-dlp poppler tesseract
pip install playwright && playwright install chromium     # optional, T8
```

## Scripts on disk (when used inside FUTRON)
- `futron-scrape` — main cascade
- `futron-cua-fetch` — T9 osascript driver + agent queue
- `futron-mcp-discover` — registry / GitHub / npm / PyPI search
- `futron-bookmark-watcher` — Dewey poller daemon

