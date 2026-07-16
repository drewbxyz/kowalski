---
name: wiki-lint
description: Health check the Obsidian wiki vault. Finds orphan pages, dead wikilinks, stale claims, missing cross-references, frontmatter gaps, and empty sections. Triggers on: lint, health check, wiki audit, find orphans, clean up wiki.
---

## 1. Vault Context

<!-- Vault Context: shared verbatim across all kowalski plugin skills and agents — edit all copies together -->

Vault root: the Obsidian vault directory — the one containing `${user_config.wiki_root}/` and `${user_config.sources_dir}/`. Claude Code is launched from here; run every command from the vault root.

**Plugin contract** — fixed paths the machinery depends on:

```
<vault-root>/
├── ${user_config.sources_dir}/             # synced source drop zone (visible so Obsidian Sync carries it)
│   └── manifest.json    # delta-tracking: hash + ingested_at per source
└── ${user_config.wiki_root}/
    ├── index.md         # master catalog
    ├── log.md           # append-only operations log (new entries at TOP)
    ├── hot.md           # hot cache: recent context + session seed (~500 words)
    ├── overview.md      # stable vault shape (status lives in hot.md)
    ├── sources/         # one summary page per ${user_config.sources_dir}/ source
    └── meta/            # dashboard, lint reports, LLM Wiki Schema reference
        └── archive/     # superseded lint reports (keep latest 2 in meta/)
```

Every wiki folder has an `_index.md` catalog page. `${user_config.wiki_root}/index.md` links the curated highlights; folder `_index.md` files carry the long tails.

**Discovery rule (MUST):** the vault's content structure is its own. To learn where content lives, read `overview.md` and the folder `_index.md` catalogs, and look at where similar pages already live. File new pages alongside their peers; never invent a parallel folder for a type the vault already files somewhere.

**No precedent?** If the vault has no existing home for a content type (fresh vault, or a genuinely new kind of content), do not invent one silently and do not assume any particular taxonomy — propose a structure to the user based on who they are and what the content is, and confirm before creating folders. When a new folder is agreed, create its `_index.md` and link it from `${user_config.wiki_root}/index.md`.

**MUST rules (Kowalski conventions):**

- Every page has YAML frontmatter with at minimum: `type`, `status`, `created`, `updated`, `tags`. Bump `updated` on every edit to that page.
- No blank line between the closing `---` of frontmatter and the `# Title` heading — write them on adjacent lines.
- Wikilinks use `[[Note Name]]` format. Filenames are Title Case with spaces and unique vault-wide.
- `${user_config.wiki_root}/log.md` is append-only — new entries go at the TOP. Never edit or rewrite old entries.
- `${user_config.wiki_root}/index.md` is the master catalog — update it on every ingest and whenever a page is added or renamed.
- **Single source of truth for volatile stats**: running numbers (counts, tallies, project metrics) live on exactly ONE hub page; every other page links there instead of restating the number. Historical snapshots ("ended the year at 47") are fine anywhere.
- **Close the loop on events**: when something concludes (trip, move, meetup), update the event's own page and every page that referenced it as upcoming — not just the hubs. Grep for the event name before finishing.
- **Third-party privacy**: don't record other people's medical, financial, or similarly private details. If context requires it, one neutral line at most (e.g., "away for medical treatment") — no diagnoses, prognoses, or treatment plans.
- `${user_config.sources_dir}/` contains source documents — never modify them, except `${user_config.sources_dir}/manifest.json`.
- Never wikilink files under `${user_config.sources_dir}/` — reference them with inline-code paths only (e.g. `` `${user_config.sources_dir}/articles/foo.md` ``); their basenames collide with `${user_config.wiki_root}/sources/` pages.
<!-- /Vault Context -->

## 2. Step 1 (mandatory): carry-forward check

**"Lint carries forward" is the defining principle of this skill**: a finding that stays open across two consecutive reports is a process failure, not a routine note — the point of every lint run is to drive prior findings to closure, not just to accumulate new ones. Run this before any fresh scanning.

1. Find the newest report: `ls ${user_config.wiki_root}/meta/lint-report-*.md | sort | tail -1` (dates sort lexicographically). Read it in full. If no `${user_config.wiki_root}/meta/lint-report-*.md` exists, this is the first lint run — write "Carry-Forward Status: first run — no prior report" in the new report and continue to Section 3.
2. Extract its open items — anything the report itself does not mark resolved. Concretely, scan for:
   - Any section titled or containing "Carried Forward", "Open", "Not Fixed", "Needs Human Judgment", "Needs Review", or a Recommended Fix Plan / "Batch B" of undone items.
   - Table rows or bullets under Dead Links / Orphans / Frontmatter Gaps / Empty Sections / Naming that are **not** prefixed with ✅ and not listed under a "Fixes Applied" / "Applied Fixes" / "Verified Clean" / "Resolved" heading.
   - Do not count anything under "Not Checked" — those were explicitly skipped, not left open.
3. For each open item, re-run the matching check from Section 3 against the current vault to see if it is still true today. Drop items that are now resolved (note them in Carry-Forward Status as "resolved since last report" for transparency — don't just silently omit them).
4. For items still open, check whether they were *also* open in the report immediately prior to the newest one (i.e., the report that was newest before this one — usually the next-newest file in `${user_config.wiki_root}/meta/` or `${user_config.wiki_root}/meta/archive/`). If an item appears open in two consecutive reports, its severity is **PROCESS FAILURE**, and it goes at the very top of the new report, above every other finding.
5. Items open for the first time (only in the newest report, not the one before it) are listed in Carry-Forward Status as "carried, first recurrence" — not yet a process failure, but flag it plainly so the next lint run treats it as the second consecutive occurrence if still open then.

## 3. Checks

Run these after the carry-forward pass. Each check states its concrete detection recipe — execute it, don't approximate it.

**Preprocessing note:** before regex-matching wikilinks in any check below, strip fenced code blocks (` ``` `...` ``` `) and inline code spans (`` `...` ``) from the page text first. Backtick-wrapped example links (e.g. a syntax-reference page demonstrating `[[Note Name]]`) are not real links and must not be flagged as dead links or counted as inbound/outbound links. This was a confirmed false-positive source in a prior lint run.

- **Orphans** — a page with no inbound `[[wikilink]]` from any other page. Build the full inbound-link set: `grep -rohE '\[\[[^]|#]+' ${user_config.wiki_root} --include='*.md' | sed -e 's/\[\[//' | sort -u` (after stripping code spans per above), normalizing away `#section` anchors and `|alias` text to get target basenames. A page counts as "linked" if its basename appears in that set — links from a folder's `_index.md` count as inbound, same as any other page. Exempt from the orphan check (by design, not defects): `${user_config.wiki_root}/index.md`, `${user_config.wiki_root}/hot.md`, `${user_config.wiki_root}/log.md`, `${user_config.wiki_root}/overview.md`, `${user_config.wiki_root}/meta/dashboard.md`, every `_index.md` (folder catalogs), files under `${user_config.wiki_root}/meta/archive/`, files under `${user_config.wiki_root}/folds/` if a `folds/` folder exists (created by external tooling — kowalski itself does not produce it), and `${user_config.wiki_root}/meta/lint-report-*.md` themselves.
- **Dead wikilinks** — a `[[Target]]` (or `[[Target|Alias]]`, `[[Target#Section]]`) whose basename `Target` does not match any file in the vault. For each extracted target (anchors/aliases stripped), check `find . -iname "<Target>.md"` (search vault-wide, not just `${user_config.wiki_root}/`) and, for image/PDF embeds, the vault's attachment folder — `find <attachment-folder> -iname "<Target>*"`, using whatever attachment location Obsidian is configured with (commonly `_attachments/`); `[[foo.png]]`-style targets are attachment refs, not page refs, so check there instead of `*.md`. **`${user_config.wiki_root}/log.md` is exempt from this check entirely** — its append-only history is expected to accumulate dead links to since-renamed or since-deleted pages; skip it before scanning. Do not special-case any other file. (This check covers `[[wikilinks]]` only — dangling inline-code source paths like `${user_config.sources_dir}/<category>/...` can't appear here because they're never wikilinked in this vault and the preprocessing step strips code spans; they're caught by the **dead source-path references** check below.)
- **Dead source-path references** — a wiki page referencing a `${user_config.sources_dir}/` file that does not exist on disk. Source files are referenced as inline-code paths (never wikilinked), on `**Raw:**` lines, and in `source_file:`-style frontmatter values. Two extraction passes (source filenames are Title Case with spaces, so the backtick pass is the primary one):
  1. Backtick-delimited: `grep -rnoE '\`${user_config.sources_dir}/[^\`]+\.(md|html|pdf)\`' ${user_config.wiki_root} --include='*.md'`
  2. Bare/frontmatter paths (no spaces): `grep -rnoE '(^|[^A-Za-z/\`])${user_config.sources_dir}/[^\`)"<> ]+\.(md|html|pdf)' ${user_config.wiki_root} --include='*.md'` — the leading `[^A-Za-z/]` boundary prevents substring-matching `resources/...` or `${user_config.wiki_root}/sources/...`; strip the boundary character from each match.

  Strip backticks, drop candidates containing `<` or `>` (template placeholders like `${user_config.sources_dir}/notes/<book>.md`), dedupe, then existence-check each path with `test -f "<path>"` from the vault root. Missing path → **Error** finding (file, line, dangling path). Exempt `${user_config.wiki_root}/log.md`, `${user_config.wiki_root}/meta/lint-report-*.md`, `${user_config.wiki_root}/meta/archive/*`, and — if a `folds/` folder exists (created by external tooling) — `${user_config.wiki_root}/folds/*` (historical records, never rewritten). Note: dangling paths that never existed on disk (as opposed to files that were later moved or renamed) are still real findings; do NOT special-case them away.
- **Frontmatter gaps** — for every `${user_config.wiki_root}/**/*.md`, read the YAML block between the first two `---` lines and confirm keys `type`, `status`, `created`, `updated`, `tags` are all present (non-empty). Report the file and the specific missing key(s).
- **`updated` staleness** — for every page whose frontmatter has `status: developing`, parse `updated: YYYY-MM-DD` and compare to today's date. If the gap exceeds 30 days, flag it as a Warning with the exact day count. Exempt from this check: `${user_config.wiki_root}/meta/lint-report-*.md` and files under `${user_config.wiki_root}/meta/archive/` — these are point-in-time records, never expected to be re-updated, so flagging them as stale would make old lint reports report themselves.
- **Empty sections** — for every `##`/`###`/etc. heading, check whether the text before the next heading of equal-or-higher level is blank. Known false positive to filter out: a heading immediately followed only by deeper sub-headings that themselves hold content (e.g. `## Foo` with content living under `### Attempt 1` beneath it) — that is populated, not empty; don't flag it.
- **Volatile-stat duplication** — running numbers (counts, tallies, project build/version numbers, etc.) must live on exactly one hub page per the Single-Source-of-Truth convention. Identify each hub's current figures from its page, build a regex from the number(s) found there, then `grep -rn` for that same number across the rest of `${user_config.wiki_root}/` (excluding `${user_config.wiki_root}/log.md` and dated/historical phrasing like "ended the year at 47"). Any other page stating the number as a current fact (not a dated snapshot, not a link to the hub) is a finding.
- **Missing `_index.md` entries** — for each wiki folder, list its markdown files (`ls ${user_config.wiki_root}/<folder>/*.md`, excluding `_index.md` itself and recursing into subfolders that have their own `_index.md`), and list the wikilink targets referenced in that folder's `_index.md`. Any file present on disk but not referenced in `_index.md` is a finding.
- **`---`/`# Title` adjacency** — for every page, confirm the line immediately following the closing `---` of frontmatter is a `# Title` line, with no blank line between them. Concretely: find the second `---` line in the file, check line N+1 starts with `# `.

## 4. Report

Write `${user_config.wiki_root}/meta/lint-report-YYYY-MM-DD.md` (today's date). Frontmatter per vault conventions:

```yaml
---
type: meta
title: "Lint Report YYYY-MM-DD"
created: YYYY-MM-DD
updated: YYYY-MM-DD
tags: [meta, lint]
status: developing
---
```

No blank line between the closing `---` and the `# Title` heading. Body sections, in this exact order:

1. **Carry-Forward Status** — what Section 2 found: items resolved since last report, items still open (with recurrence count), and which of those are process failures.
2. **PROCESS FAILURES** — items open in 2+ consecutive reports, promoted here from Carry-Forward Status. Empty section (state "None") if there are none.
3. **Errors** — hard problems: dead links, frontmatter gaps, `---`/`# Title` violations.
4. **Warnings** — softer problems: orphans, staleness, volatile-stat duplication, missing `_index.md` entries.
5. **Info** — empty sections and anything else worth noting but not actionable on its own.
6. **Stats** — pages scanned, counts per finding category, comparison to previous report's counts.

**Rotation (after writing the new report):** list `${user_config.wiki_root}/meta/lint-report-*.md`, sort by date descending, keep the newest 2 in `${user_config.wiki_root}/meta/`, and `mv` every older one into `${user_config.wiki_root}/meta/archive/`. Never rotate or move files already in `${user_config.wiki_root}/meta/archive/`.

**Log entry (after rotation):** add an entry at the TOP of `${user_config.wiki_root}/log.md` shaped `## [YYYY-MM-DD] lint | <n> findings (<severity summary>)`, e.g. `## [2026-07-08] lint | Wiki health check + fixes applied — lint-report-2026-07-08`, followed by a few bullets summarizing scope, key findings, and fixes applied, and a closing `Report: [[lint-report-YYYY-MM-DD]]` line — match the style of existing lint entries already in `${user_config.wiki_root}/log.md`.

**Update `${user_config.wiki_root}/index.md` (after the log entry):** point the "Last health check" line under `## Meta` at the new report — `[[lint-report-YYYY-MM-DD]]` — and shift the previous newest report into its older-reports parenthetical.

## 5. Scale

Count pages first: `find ${user_config.wiki_root} -name '*.md' | wc -l`. If the vault has more than 100 pages, don't scan single-threaded — dispatch one `kowalski:lint-worker` agent per top-level folder that exists under `${user_config.wiki_root}/` (whatever this vault's content folders are, plus `meta/`, and `folds/` if external tooling created it), plus handle the root-level files (`${user_config.wiki_root}/index.md`, `hot.md`, `log.md`, `overview.md`) directly yourself. Each worker returns candidate findings for its folder (see the plugin's agent definition at `${CLAUDE_PLUGIN_ROOT}/agents/lint-worker.md` for what it can and can't determine on its own — orphans and dead links need the full vault-wide link graph, which a single folder can't see, so workers report candidates and the orchestrator confirms them against the complete picture).

**Single-writer rule**: only the orchestrator merges findings, resolves worker-reported candidates against the full link graph, writes the report, and applies any approved fixes. Workers never write files.

## 6. Fixes

Always ask before auto-fixing anything — present the findings and get explicit approval first. Once approved:

- Mechanical fixes are safe to apply automatically: adding missing frontmatter keys, adding missing `_index.md` entries.
- Anything else (rewriting stale content, resolving contradictions, renaming files, deduplicating volatile stats) needs the owner's explicit sign-off per item, not a blanket "fix everything."
- **Never auto-delete a page**, even one confirmed as an orphan or fully superseded. Flag it for the owner to decide.
