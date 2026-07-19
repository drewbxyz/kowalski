---
name: wiki-lint
description: Health check the Obsidian wiki vault. Finds orphan pages, dead wikilinks, stale claims, missing cross-references, frontmatter gaps, and empty sections. Triggers on: lint, health check, wiki audit, find orphans, clean up wiki.
---

## 1. Vault Context

<!-- Vault Context: generated from shared/vault-context.md — edit that file and run scripts/sync-shared-blocks.sh -->

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

## 2. Step 1 (mandatory): carry-forward gate

**"Lint carries forward" is the defining principle of this skill**: the point of every run is to drive prior findings to closure, not to accumulate new ones. This is a hard gate — run it in full, before any fresh scanning, and let its output open the report. A finding that survives unresolved across consecutive reports must get louder each run, never blend back in with first-time findings.

### 2a. Read the prior report and rebuild the open set

1. Find the newest report: `ls ${user_config.wiki_root}/meta/lint-report-*.md | sort | tail -1` (dates sort lexicographically). Read it in full. If none exists, this is the first run — write `## Carried Findings` followed by `None — first run, no prior report.` in the new report and continue to Section 3.
2. Collect every finding that was **open** in the prior report. In a report written by this skill, open findings live in exactly two places:
   - the `## Carried Findings` callouts — each callout is one open finding, its carry count in the callout title;
   - the body `## Errors` / `## Warnings` / `## Info` finding lines — each first-time-open, tagged `[new YYYY-MM-DD]`.

   EXCLUDE `## Resolved Since Last Run` (already closed) and `## Waived` (intentionally accepted — see 2d). Nothing else counts as open.
3. Legacy fallback: if the newest report predates this format (no `## Carried Findings` section), extract open items the old way — any Errors/Warnings/Info line not prefixed ✅ and not sitting under a "Fixes Applied"/"Resolved" heading — and treat each as carry 0 with `since` = that report's date.

### 2b. Identity key and carry count

Give each open finding a stable identity key so it matches run-to-run:

```
key = <relative-file-path> | <finding-category> | <short normalized summary>
```

`finding-category` is the check name: `dead-link`, `dead-source-path`, `orphan`, `frontmatter-gap`, `updated-staleness`, `empty-section`, `adjacency`, `volatile-stat`, `missing-index-entry`. Normalized summary = the finding's core claim, lowercased and whitespace-collapsed, with line numbers and dates stripped — anchor line numbers drift between runs, so NEVER key on line number. Matching is fuzzy: a candidate this run and a prior open finding are the same finding if they share file + category and their summaries clearly describe the same defect. When genuinely unsure, treat it as new — a false "new" is cheaper than a false "resolved".

Read each prior open finding's carry count and first-seen date from its tag (match case-insensitively):

- callout `> [!warning] Carried x1 (since 2026-07-12)` → carry 1, since 2026-07-12
- callout `> [!failure] PROCESS FAILURE — carried x2 (open since 2026-07-04)` → carry 2, since 2026-07-04
- body tag `[new 2026-07-12]` → carry 0, since 2026-07-12
- body tag `[carried x1, since 2026-07-12]` (legacy inline form, if a prior run used it) → carry 1, since 2026-07-12

### 2c. Recompute this run

Run the Section 3 checks, then reconcile each prior open finding against this run's results by identity key:

- **Still open** (found again this run) → `carry = prior_carry + 1`, keep the original `since` date. Goes in `## Carried Findings` (2e), NOT in the body.
- **Resolved** (not found this run) → record under `## Resolved Since Last Run` with its key and how long it was open; drop from the open set.
- **New** (no prior-open match) → `carry = 0`, `since = today`. Stays in the normal body section for its severity, tagged `[new <today>]`.

### 2d. Waivers

A finding can be intentionally accepted rather than fixed (e.g. historical dead links in `log.md`, already exempt in Section 3, or any finding the owner consciously chooses to live with). Waiving is a deliberate, owner-approved act — never a silent drop:

- When the owner approves waiving a finding, write it under `## Waived` with its identity key and a one-line reason.
- `## Waived` is sticky: re-emit every entry from the prior report's `## Waived` section into the new report, plus any newly waived this run — a waiver persists across rotation because it lives inline in every report.
- Waived keys count as **closed**: exclude them from the open set (2a) and never re-flag them as new. If the underlying condition genuinely no longer exists, retire the waiver and note it under `## Resolved Since Last Run`.

### 2e. Escalation (the gate)

Every finding with `carry >= 1` is surfaced as a callout at the TOP of the report, under `## Carried Findings`, above all first-time findings — never mixed into the body. Order callouts most-escalated first.

- **carry == 1** (open in two consecutive reports) → `[!warning]`, and name the next run as the failure point:

```markdown
> [!warning] Carried x1 (since 2026-07-12)
> `wiki/engineering/Foo.md` — missing `updated` bump. Flagged last run, still open. If it is still open next run this is a PROCESS FAILURE.
```

- **carry >= 2** (open across three or more consecutive reports) → `[!failure]`, labeled a process failure:

```markdown
> [!failure] PROCESS FAILURE — carried x2 (open since 2026-07-04)
> `wiki/engineering/Foo.md` — missing `updated` bump. Open across three consecutive reports. Fix this run or consciously waive it (Section 2d).
```

If there are no carried findings, write `## Carried Findings` followed by `None — clean carry-forward.` The section's presence is the proof the gate ran.

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

1. **`## Carried Findings`** — the carry-forward gate output (Section 2e): every finding with `carry >= 1` as a callout, `[!warning]` for carry 1 and `[!failure]` process failures for carry >= 2, most-escalated first. Write `None — clean carry-forward.` if there are none. This section replaces the former "Carry-Forward Status" and "PROCESS FAILURES" sections — process failures now appear here as `[!failure]` callouts.
2. **`## Errors`** — carry:0 hard problems: dead links, dead source-path references, frontmatter gaps, `---`/`# Title` violations. Tag each finding line `[new YYYY-MM-DD]` (today's date).
3. **`## Warnings`** — carry:0 softer problems: orphans, staleness, volatile-stat duplication, missing `_index.md` entries. Tag each `[new YYYY-MM-DD]`.
4. **`## Info`** — carry:0 empty sections and anything else worth noting but not actionable on its own. Tag each `[new YYYY-MM-DD]`.
5. **`## Resolved Since Last Run`** — findings that were open in the prior report and are gone this run (Section 2c), each with its key and how long it was open. `None` if none.
6. **`## Waived`** — sticky owner-accepted findings with one-line reasons (Section 2d), re-emitted every run. `None` if none.
7. **`## Stats`** — pages scanned, counts per finding category, comparison to the previous report's counts, plus the carry-forward tally: how many findings carried, and how many escalated to process failure.

Every open finding must carry its inline carry tag so the next run's gate (Section 2b) can read the count back: `[new YYYY-MM-DD]` on carry:0 body lines, and `Carried xN (since …)` in each `## Carried Findings` callout title. Findings under `## Resolved Since Last Run` and `## Waived` are not open and take no tag.

**Rotation (after writing the new report):** list `${user_config.wiki_root}/meta/lint-report-*.md`, sort by date descending, keep the newest 2 in `${user_config.wiki_root}/meta/`, and `mv` every older one into `${user_config.wiki_root}/meta/archive/`. Never rotate or move files already in `${user_config.wiki_root}/meta/archive/`.

**Log entry (after rotation):** add an entry at the TOP of `${user_config.wiki_root}/log.md` shaped `## [YYYY-MM-DD] lint | <n> findings (<severity summary>)` — if any findings are process failures (carry >= 2), name that count in the severity summary, e.g. `## [2026-07-18] lint | 5 findings (1 PROCESS FAILURE)`, followed by a few bullets summarizing scope, key findings, and fixes applied, and a closing `Report: [[lint-report-YYYY-MM-DD]]` line — match the style of existing lint entries already in `${user_config.wiki_root}/log.md`.

**Update `${user_config.wiki_root}/index.md` (after the log entry):** point the "Last health check" line under `## Meta` at the new report — `[[lint-report-YYYY-MM-DD]]` — and shift the previous newest report into its older-reports parenthetical.

## 5. Scale

Count pages first: `find ${user_config.wiki_root} -name '*.md' | wc -l`. If the vault has more than 100 pages, don't scan single-threaded — dispatch one `kowalski:lint-worker` agent per top-level folder that exists under `${user_config.wiki_root}/` (whatever this vault's content folders are, plus `meta/`, and `folds/` if external tooling created it), plus handle the root-level files (`${user_config.wiki_root}/index.md`, `hot.md`, `log.md`, `overview.md`) directly yourself. Each worker returns candidate findings for its folder (see the plugin's agent definition at `${CLAUDE_PLUGIN_ROOT}/agents/lint-worker.md` for what it can and can't determine on its own — orphans and dead links need the full vault-wide link graph, which a single folder can't see, so workers report candidates and the orchestrator confirms them against the complete picture).

**Single-writer rule**: only the orchestrator merges findings, resolves worker-reported candidates against the full link graph, writes the report, and applies any approved fixes. Workers never write files.

## 6. Fixes

Always ask before auto-fixing anything — present the findings and get explicit approval first. Once approved:

- Mechanical fixes are safe to apply automatically: adding missing frontmatter keys, adding missing `_index.md` entries.
- Anything else (rewriting stale content, resolving contradictions, renaming files, deduplicating volatile stats) needs the owner's explicit sign-off per item, not a blanket "fix everything."
- **Never auto-delete a page**, even one confirmed as an orphan or fully superseded. Flag it for the owner to decide.
- **Waiving** a finding (accepting it instead of fixing it) is an explicit, per-item owner decision recorded under `## Waived` in the report with a one-line reason (Section 2d) — never waive silently or in bulk.
