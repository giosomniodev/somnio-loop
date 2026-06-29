#!/usr/bin/env bash
# Build somnio-loop.plugin from the source tree.
# Usage: ./scripts/build-plugin.sh [output-path]
# Default output: ./somnio-loop.plugin

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
OUTPUT="${1:-${REPO_ROOT}/somnio-loop.plugin}"
PLUGIN_NAME=$(grep -m1 '"name"' "${REPO_ROOT}/.claude-plugin/plugin.json" | sed -E 's/.*"name"[[:space:]]*:[[:space:]]*"([^"]+)".*/\1/')
PLUGIN_VERSION=$(grep -m1 '"version"' "${REPO_ROOT}/.claude-plugin/plugin.json" | sed -E 's/.*"version"[[:space:]]*:[[:space:]]*"([^"]+)".*/\1/')

if [[ "${PLUGIN_NAME}" != "somnio-loop" ]]; then
  echo "warning: plugin name in .claude-plugin/plugin.json is '${PLUGIN_NAME}', expected 'somnio-loop'" >&2
fi

echo "Building ${PLUGIN_NAME}@${PLUGIN_VERSION} → ${OUTPUT}"

# Clean previous build
rm -f "${OUTPUT}"

# Zip everything except files matching .gitignore patterns we care about for the plugin
cd "${REPO_ROOT}"
zip -rq "${OUTPUT}" . \
  -x "*.DS_Store" \
  -x "*.git/*" \
  -x ".github/*" \
  -x "scripts/*" \
  -x "CHANGELOG.md" \
  -x "CONTRIBUTING.md" \
  -x "LICENSE" \
  -x ".gitignore" \
  -x "*.plugin" \
  -x "node_modules/*" \
  -x "__pycache__/*" \
  -x "run-report.md"

# Sanity check
echo ""
echo "Contents:"
unzip -l "${OUTPUT}" | tail -5

echo ""
echo "Size: $(du -h "${OUTPUT}" | cut -f1)"
echo "Done."
