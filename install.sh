#!/usr/bin/env bash
# futron-scrape installer — symlinks bins into ~/.local/bin and reports optional deps.
set -euo pipefail

SRC="$(cd "$(dirname "$0")" && pwd)/bin"
DEST="${PREFIX:-$HOME/.local/bin}"
mkdir -p "$DEST"

echo "Installing futron-scrape binaries to: $DEST"
for bin in futron-scrape futron-mcp-discover futron-cua-fetch futron-bookmark-watcher; do
  if [[ -L "$DEST/$bin" || -f "$DEST/$bin" ]]; then
    rm -f "$DEST/$bin"
  fi
  ln -s "$SRC/$bin" "$DEST/$bin"
  echo "  + $bin"
done

# Skill install
SKILL_DEST="${CLAUDE_SKILLS_DIR:-$HOME/.claude/skills}/futron-scrape"
if [[ -d "$(dirname "$SKILL_DEST")" ]] && [[ -f "$SRC/../skill/SKILL.md" ]]; then
  mkdir -p "$SKILL_DEST"
  cp "$SRC/../skill/SKILL.md" "$SKILL_DEST/SKILL.md"
  echo "  + skill at $SKILL_DEST"
fi

echo ""
echo "Make sure $DEST is on your PATH:"
echo "  echo 'export PATH=\"$DEST:\$PATH\"' >> ~/.zshrc"
echo ""
echo "Optional system deps (each tier skips if its dep is missing):"

for tool in yt-dlp pdftotext tesseract; do
  if command -v "$tool" >/dev/null 2>&1; then
    echo "  ✓ $tool"
  else
    case "$tool" in
      yt-dlp)     echo "  ✗ $tool      — brew install yt-dlp           (T3 YouTube)" ;;
      pdftotext)  echo "  ✗ $tool   — brew install poppler          (T4 PDFs)"   ;;
      tesseract)  echo "  ✗ $tool   — brew install tesseract        (T4 image OCR)" ;;
    esac
  fi
done

if python3 -c 'import playwright' 2>/dev/null; then
  echo "  ✓ playwright"
else
  echo "  ✗ playwright  — pip install playwright && playwright install chromium  (T8 JS rendering)"
fi

echo ""
echo "Smoke test:"
echo "  futron-scrape https://en.wikipedia.org/wiki/Model_Context_Protocol"
