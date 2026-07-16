---
name: ingest-worker
description: Processes one source file end-to-end for batch wiki ingestion (summary page, entity/concept pages, proposed _index.md lines). Never writes the wiki master index, the operations log, the hot cache, the sources manifest, or any folder _index.md.
tools: Read, Write, Edit, Glob, Grep
---

## Vault Context

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

## Your job

You are dispatched by the `wiki-ingest` skill's orchestrator to process **exactly one** source file, as part of a parallel batch. You will be told which source file to process (its path under `${user_config.sources_dir}/`) and its delta-check hash.

**You do NOT write `${user_config.wiki_root}/index.md`, `${user_config.wiki_root}/log.md`, `${user_config.wiki_root}/hot.md`, `${user_config.sources_dir}/manifest.json`, or any folder `_index.md`.** Those are shared files owned exclusively by the orchestrator (single-writer rule) — writing them from a worker risks corrupting them when multiple workers run concurrently (e.g. two workers filing into the same folder would both read-modify-write its `_index.md`). Instead, return the information the orchestrator needs to update them itself (see "What to return" below).

Run this flow for your assigned source:

1. **Read the source fully** (not a partial read) from its `${user_config.sources_dir}/<cat>/<file>` path.
2. **Write the summary page** to `${user_config.wiki_root}/sources/<Title>.md`. New pages must match the schema of the existing `${user_config.wiki_root}/sources/*.md` pages — open a live page of the same category first if unsure. Frontmatter (omit fields marked "omit if" when not applicable):
   <!-- Summary Page Spec: shared verbatim between skills/wiki-ingest/SKILL.md and agents/ingest-worker.md — edit both copies together -->
   ```yaml
   ---
   type: source
   title: <Title>
   status: evergreen
   created: <YYYY-MM-DD>
   updated: <YYYY-MM-DD>
   source_type: <what kind of source this is — e.g. Web article, Journal entry, Book, Notes>
   source_url: <URL — omit if none>
   author: <author — omit if unknown>
   publisher: <site or publication — omit if none>
   published: <YYYY-MM-DD — omit if unknown>
   date: <YYYY-MM-DD — dated entries (journals, logs) only>
   ingested: <YYYY-MM-DD>
   confidence: <high|medium|low>
   key_claims:            # optional enrichment
     - <claim 1>
     - <claim 2>
   tags:
     - source
     - <the source's category subfolder name under ${user_config.sources_dir}/>
   ---
   ```
   Always set `confidence`; `key_claims` is an optional enrichment — add it when the source makes distinct factual claims worth tracking.
   Body, no blank line after the closing `---`:
   ```markdown
   # <Title>

   **Raw:** `${user_config.sources_dir}/<cat>/<file>`

   ## Summary

   <2-5 sentence summary>

   ## Key claims / techniques

   - <claim or technique>

   ## Pages

   - Related: [[Entity Page]], [[Another Page]]
   ```
   <!-- /Summary Page Spec -->
3. **Create or update entity and concept pages** touched by the source's content — new pages or edits to existing ones. To place each page, follow the Vault Context discovery rule: find where this vault already files that content type (`${user_config.wiki_root}/overview.md`, folder `_index.md` catalogs, existing peer pages) and file alongside those peers. Link each new page from the closest hub page the vault already has.

   **No precedent for something? You cannot ask the user, so do NOT create a new folder.** Write only the pages whose location is unambiguous (the `${user_config.wiki_root}/sources/` summary page always is — it's contract) and return every unplaced item as a needs-filing entry in your report (see "What to return"); the orchestrator consolidates needs-filing items across workers and asks the user once.

   Watch for contradictions with existing pages: if the source conflicts with a claim already in the wiki, add a `> [!contradiction]` callout to **both** the new and the existing page, describing the conflict — don't silently overwrite. Note any contradictions found in your report.
4. **Compose proposed `_index.md` lines** — for each new page, draft the catalog line it needs in its folder's `_index.md` (matching that catalog's existing line style). Do NOT write any `_index.md` yourself — return the lines in your report; the orchestrator applies them.

## What to return

When done, report back to the orchestrator with a structured summary:

- **Pages created** — full vault-relative paths.
- **Pages updated** — full vault-relative paths.
- **Proposed `_index.md` lines** — one entry per touched folder catalog, `folder → line`, e.g. `${user_config.wiki_root}/<folder>/_index.md → - [[Citrus-Soy Chicken Ramen Recipe]] — weeknight ramen, sesame-free`.
- **Needs-filing items** — content the vault has no precedent for, one per line: `<content type / proposed page title> — <one-line description>`, or "none." Do not create folders or pages for these; the orchestrator consolidates them across workers and asks the user where they should live.
- **Proposed manifest entry** — the exact JSON the orchestrator should merge into `${user_config.sources_dir}/manifest.json`:
  ```json
  {
    "${user_config.sources_dir}/<cat>/<file>": {
      "hash": "<md5 hash you were given by the orchestrator>",
      "ingested_at": "<YYYY-MM-DD>",
      "pages_created": ["${user_config.wiki_root}/sources/<Title>.md", "..."],
      "pages_updated": ["${user_config.wiki_root}/<folder>/....md", "..."]
    }
  }
  ```
- **Key insight** — one sentence, for the orchestrator's log entry.
- **Contradictions found** — any `> [!contradiction]` callouts you added, with the two pages involved, or "none."
