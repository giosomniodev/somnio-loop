#!/usr/bin/env bash
# push-to-github.sh — one-shot upload to GitHub.
#
# Prerequisites on YOUR Mac (not the sandbox):
#   - `gh` CLI installed         (brew install gh)
#   - Authenticated              (gh auth login — choose SSH)
#   - git installed              (default on macOS)
#
# Usage:
#   chmod +x push-to-github.sh
#   ./push-to-github.sh                          # uses defaults: somnio/somnio-loop, public
#   ./push-to-github.sh <owner>                  # use a different GitHub owner/org
#   ./push-to-github.sh <owner> private          # create as private
#   ./push-to-github.sh <owner> public no-tag    # skip the v0.7.0 tag

set -euo pipefail

OWNER="${1:-somnio}"
VISIBILITY="${2:-public}"
TAG_MODE="${3:-tag}"
REPO_NAME="somnio-loop"
VERSION="v0.7.0"
DESCRIPTION="Autonomous agentic loop plugin for Claude Code. Ticket in, deliverable out."

# Sanity checks
command -v gh >/dev/null 2>&1 || { echo "ERROR: gh CLI not installed. Run: brew install gh"; exit 1; }
command -v git >/dev/null 2>&1 || { echo "ERROR: git not installed."; exit 1; }
gh auth status >/dev/null 2>&1 || { echo "ERROR: not authenticated. Run: gh auth login"; exit 1; }

# Verify we're in the right directory
[ -f .claude-plugin/plugin.json ] || { echo "ERROR: must be run from the somnio-loop repo root."; exit 1; }
[ -d .git ] || { echo "ERROR: not a git repo. Was it initialized? Try: git init -b main"; exit 1; }

echo "=========================================="
echo "Pushing somnio-loop ${VERSION} to GitHub"
echo "=========================================="
echo "  Owner:       ${OWNER}"
echo "  Repo:        ${REPO_NAME}"
echo "  Visibility:  ${VISIBILITY}"
echo "  Tag:         ${TAG_MODE} (${VERSION})"
echo "  Description: ${DESCRIPTION}"
echo "=========================================="
echo

# Confirm
read -p "Continue? [y/N] " -r
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
  echo "Aborted."
  exit 1
fi

# 1) Create the repo and push main
echo
echo "[1/3] Creating GitHub repo ${OWNER}/${REPO_NAME}..."
if [[ "${VISIBILITY}" == "private" ]]; then
  gh repo create "${OWNER}/${REPO_NAME}" \
    --private \
    --description "${DESCRIPTION}" \
    --source=. \
    --remote=origin \
    --push
else
  gh repo create "${OWNER}/${REPO_NAME}" \
    --public \
    --description "${DESCRIPTION}" \
    --source=. \
    --remote=origin \
    --push
fi

# 2) Create tag (optional)
if [[ "${TAG_MODE}" == "tag" ]]; then
  echo
  echo "[2/3] Tagging ${VERSION} (dispara release workflow)..."
  git tag -a "${VERSION}" -m "${VERSION} — initial public release as somnio-loop"
  git push origin "${VERSION}"
else
  echo
  echo "[2/3] Skipping tag (TAG_MODE=${TAG_MODE})."
fi

# 3) Open the repo in browser
echo
echo "[3/3] Opening the repo in your browser..."
gh repo view --web "${OWNER}/${REPO_NAME}"

echo
echo "=========================================="
echo "Done."
echo
echo "Next steps:"
echo "  - The release workflow at .github/workflows/release.yml is now running"
echo "    (if you tagged ${VERSION}). It builds somnio-loop.plugin and attaches it"
echo "    to the GitHub release."
echo "  - Watch it: gh run watch --repo ${OWNER}/${REPO_NAME}"
echo "  - Once green, the .plugin artifact will be at:"
echo "    https://github.com/${OWNER}/${REPO_NAME}/releases/tag/${VERSION}"
echo "=========================================="
