---
name: wiki-ingest
description: Ingest sources into the wiki. Reads a source from the sources drop-zone, extracts entities and concepts, creates/updates wiki pages, cross-references, logs. Triggers on: ingest, ingest all new, process this source, batch ingest, add this to the wiki.
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

## 2. Delta check (always first)

**First run / fresh vault:** if `${user_config.wiki_root}/` has no content folders yet beyond the contract files, treat this as vault setup, not just an ingest — have a short conversation about who the user is and what they want the vault to hold, propose a minimal starting structure drawn from their answers (not from a template), confirm it, then proceed. Likewise, `${user_config.sources_dir}/` contains whatever category subfolders the user keeps — discover them by listing the directory; the plugin does not prescribe a set.

Before touching any source, compute its hash and compare against `${user_config.sources_dir}/manifest.json`:

```bash
h=$(md5 -q "$f" 2>/dev/null || md5sum "$f" | cut -d' ' -f1)
```

(`$f` is the path to the source file, e.g. `${user_config.sources_dir}/articles/foo.md`.) Look up `sources["$f"].hash` in `${user_config.sources_dir}/manifest.json`:

- Hash matches → the source is unchanged. Skip it and say so ("already ingested, unchanged").
- Hash differs or the key is absent → the source is new or updated. Proceed to ingest.

**"Ingest all new"**: walk `${user_config.sources_dir}/**/*.md` (excluding `manifest.json` itself), run the delta check on each, and report the full delta list (new / changed / unchanged) before processing anything.

**Sync-divergence warning**: if `${user_config.sources_dir}/manifest.json` lists a file path that does not exist on disk, warn the user before proceeding — this is a possible sync divergence (a source was ingested on another device but hasn't synced down yet). Tell them to check "Sync all other types" is enabled on all devices, in case Obsidian Sync is excluding the `${user_config.sources_dir}/` folder somewhere.

## 3. Single-source flow

For one confirmed-new-or-changed source, in order:

1. **Read the source fully** (not a partial read) from its `${user_config.sources_dir}/<cat>/<file>` path.
2. **Write the summary page** to `${user_config.wiki_root}/sources/<Title>.md`. New pages must match the schema of the existing `${user_config.wiki_root}/sources/*.md` pages — open a live page of the same category first if unsure. Frontmatter (omit fields marked "omit if" when not applicable):
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
3. **Create or update entity and concept pages** touched by the source's content — new pages or edits to existing ones. Apply the filing procedure (section 4) to decide where. Watch for contradictions with existing pages: if the source conflicts with a claim already in the wiki, add a `> [!contradiction]` callout to **both** the new and the existing page, describing the conflict — don't silently overwrite.
4. **Update touched folders' `_index.md`** — add a line for each new page in the relevant folder catalog(s). If the index is stats-based rather than a page list (e.g. `${user_config.wiki_root}/sources/_index.md`), RECOMPUTE each touched count from the actual files/tags — never increment the prior value blindly.
5. **Update `${user_config.wiki_root}/index.md`** — add or adjust the curated link for the new/updated content.
6. **Append a log entry to the TOP of `${user_config.wiki_root}/log.md`**, exactly this shape:
   ```markdown
   ## [YYYY-MM-DD] ingest | <Title>

   - Source: `${user_config.sources_dir}/<cat>/<file>`
   - Summary: <one-line summary>
   - Pages created: [[Page A]], [[Page B]]
   - Pages updated: [[Page C]]
   - Key insight: <one sentence>
   ```
7. **Update `${user_config.wiki_root}/hot.md`** if this ingest changes current/active context worth surfacing in the session seed.
8. **Write the manifest entry** in `${user_config.sources_dir}/manifest.json` under `sources["<full source path>"]`:
   ```json
   {
     "hash": "<md5 hash computed during the delta check (section 2)>",
     "ingested_at": "<YYYY-MM-DD>",
     "pages_created": ["${user_config.wiki_root}/sources/<Title>.md", "..."],
     "pages_updated": ["${user_config.wiki_root}/<folder>/....md", "..."]
   }
   ```

## 4. Filing: discover, or ask

Filing is a two-step decision, per the Vault Context discovery rule:

1. **Identify the content type** (recipe, book, journal entry, article, trip, tool/org/project, person, …).
2. **Discover where this vault files that type** — read `${user_config.wiki_root}/overview.md`, the folder `_index.md` catalogs, and where existing pages of the same type live — and file alongside those peers.

If discovery finds no precedent anywhere in the vault, do not pick a location yourself — ask the user. Propose 1–2 sensible options grounded in what the vault already looks like and what the user seems to care about, confirm, then file. When a new folder is agreed, register it (create its `_index.md`, link it from `${user_config.wiki_root}/index.md`).

Journal-style dated entries usually need no page of their own beyond the `${user_config.wiki_root}/sources/` summary — they update the pages of whatever they mention.

Whichever folder a page lands in, link it from the closest hub page the vault already has.

## 5. Batch mode

When 2 or more sources are pending ingest:

1. List the pending sources (from the delta check) and confirm with the user before dispatching.
2. Dispatch one `kowalski:ingest-worker` agent per source, in parallel. Each worker processes its source's single-source flow (section 3) **except** the shared files — workers do not touch `${user_config.wiki_root}/index.md`, `${user_config.wiki_root}/log.md`, `${user_config.wiki_root}/hot.md`, `${user_config.sources_dir}/manifest.json`, **or any folder `_index.md`** (two workers filing into the same folder would race on its `_index.md`). Each worker returns: pages created, pages updated, proposed `_index.md` lines (folder → line), its proposed manifest entry (with hash), a key insight, any contradictions found, and any needs-filing items (content the vault has no precedent for — workers never create new folders).
3. Once all workers report back, the orchestrator does one cross-reference pass across the newly created/updated pages (link related entities to each other, resolve any contradictions flagged by multiple workers) applies every worker's proposed `_index.md` lines to the relevant folder catalogs, and consolidates all needs-filing items into one question to the user — proposing 1–2 options per item, grounded in the vault's existing shape — then files them and registers any agreed new folders.
4. The orchestrator then performs a **single** update to `${user_config.wiki_root}/index.md`, `${user_config.wiki_root}/log.md` (one log entry per source, or a combined batch entry — orchestrator's call), `${user_config.wiki_root}/hot.md`, and `${user_config.sources_dir}/manifest.json` (merging in every worker's proposed entry).

**Single-writer rule: only the orchestrator writes `${user_config.wiki_root}/index.md`, `${user_config.wiki_root}/log.md`, `${user_config.wiki_root}/hot.md`, `${user_config.sources_dir}/manifest.json`, and — in batch mode — all folder `_index.md` files. Workers never write these files, even when running in parallel — this is what prevents concurrent writers from corrupting the shared catalogs, log, cache, and manifest.**
