#!/usr/bin/env bash
# Sync the shared instruction blocks from shared/*.md into every carrier file.
#
# Each carrier keeps its marker lines; everything between the start marker and
# the end marker (exclusive) is replaced with the canonical content from the
# shared file, re-indented to match the indentation of the carrier's start
# marker line. Idempotent: running twice produces no further changes.
#
# Canonical sources:
#   shared/vault-context.md     -> <!-- Vault Context: ... --> blocks
#   shared/summary-page-spec.md -> <!-- Summary Page Spec: ... --> blocks
set -euo pipefail

cd "$(dirname "$0")/.."

sync_block() {
  local shared="$1" start="$2" end="$3" carrier="$4"
  local tmp
  tmp="$(mktemp)"
  if awk -v shared="$shared" -v start="$start" -v endm="$end" '
    inblock && index($0, endm) { inblock = 0; print; next }
    inblock { next }
    index($0, start) {
      found = 1
      print
      match($0, /^[ \t]*/)
      indent = substr($0, 1, RLENGTH)
      while ((getline line < shared) > 0) {
        if (line == "") print ""
        else print indent line
      }
      close(shared)
      inblock = 1
      next
    }
    { print }
    END {
      if (!found) exit 2
      if (inblock) exit 3
    }
  ' "$carrier" > "$tmp"; then
    mv "$tmp" "$carrier"
  else
    status=$?
    rm -f "$tmp"
    case "$status" in
      2) echo "ERROR: start marker '$start' not found in $carrier" >&2 ;;
      3) echo "ERROR: end marker '$end' not found in $carrier" >&2 ;;
      *) echo "ERROR: failed to sync $carrier (exit $status)" >&2 ;;
    esac
    exit 1
  fi
}

# Vault Context: carried by every skill and agent.
for f in skills/*/SKILL.md agents/*.md; do
  sync_block shared/vault-context.md \
    '<!-- Vault Context:' '<!-- /Vault Context -->' "$f"
done

# Summary Page Spec: carried by the wiki-ingest skill and the ingest worker.
for f in skills/wiki-ingest/SKILL.md agents/ingest-worker.md; do
  sync_block shared/summary-page-spec.md \
    '<!-- Summary Page Spec:' '<!-- /Summary Page Spec -->' "$f"
done

echo "Shared blocks synced."
