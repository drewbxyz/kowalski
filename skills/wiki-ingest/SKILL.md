---
name: wiki-ingest
description: Ingest sources into the wiki. Reads a source from the sources drop-zone, extracts entities and concepts, creates/updates wiki pages, cross-references, logs. Triggers on: ingest, ingest all new, process this source, batch ingest, add this to the wiki.
---

## 1. Vault Context

<!-- Vault Context: shared verbatim across all kowalski plugin skills and agents — edit all copies together -->

Vault root: the Obsidian vault directory — the one containing `${user_config.wiki_root}/` and `${user_config.sources_dir}/`. Claude Code is launched from here; run every command from the vault root.

```
<vault-root>/
├── ${user_config.sources_dir}/             # synced source drop zone (visible so Obsidian Sync carries it)
│   ├── articles/
│   ├── journal/
│   ├── notes/
│   ├── recipes/
│   └── manifest.json    # delta-tracking: hash + ingested_at per source
├── ${user_config.wiki_root}/
│   ├── index.md         # master catalog
│   ├── log.md           # append-only operations log (new entries at TOP)
│   ├── hot.md            # hot cache: recent context + session seed (~500 words)
│   ├── overview.md      # stable vault shape (status lives in hot.md)
│   ├── areas/            # life-area hubs: Engineering, Work, FRC, Fitness, Life, Birding, Coffee, Travel, Cooking, Reading, Wishlist, …
│   │   └── travel/       # one page per trip
│   ├── engineering/      # engineering craft notes (TypeScript, Next.js, …)
│   │   └── effect-ts/    # Effect-TS sub-series
│   ├── goals/            # personal and professional goals
│   ├── learning/         # self-directed study paths
│   ├── people/           # relationships, shared context
│   ├── resources/        # tools, orgs, projects
│   │   ├── books/
│   │   └── recipes/
│   ├── sources/           # one summary page per ${user_config.sources_dir}/ source
│   └── meta/              # dashboard, lint reports, LLM Wiki Schema reference
│       └── archive/       # superseded lint reports (keep latest 2 in meta/)
├── _templates/            # Templater templates
├── _attachments/          # images and PDFs referenced by wiki pages
├── archive/               # retired working docs (not wiki pages)
└── projects/              # working project files (not wiki pages)
```

Every wiki folder has an `_index.md` catalog page. `${user_config.wiki_root}/index.md` links the curated highlights; folder `_index.md` files carry the long tails (sources, recipes, books).

**MUST rules (Kowalski conventions):**

- Every page has YAML frontmatter with at minimum: `type`, `status`, `created`, `updated`, `tags`. Bump `updated` on every edit to that page.
- No blank line between the closing `---` of frontmatter and the `# Title` heading — write them on adjacent lines.
- Wikilinks use `[[Note Name]]` format. Filenames are Title Case with spaces and unique vault-wide.
- `${user_config.wiki_root}/log.md` is append-only — new entries go at the TOP. Never edit or rewrite old entries.
- `${user_config.wiki_root}/index.md` is the master catalog — update it on every ingest and whenever a page is added or renamed.
- **Single source of truth for volatile stats**: running numbers (life-list counts, PRs, project metrics) live on exactly ONE hub page; every other page links there instead of restating the number. Historical snapshots ("ended the trip at 1,229") are fine anywhere.
- **Close the loop on events**: when something concludes (trip, move, meetup), update the event's own page and every page that referenced it as upcoming — not just the hubs. Grep for the event name before finishing.
- **Third-party privacy**: don't record other people's medical, financial, or similarly private details. If context requires it, one neutral line at most (e.g., "away for medical treatment") — no diagnoses, prognoses, or treatment plans.
- `${user_config.sources_dir}/` contains source documents — never modify them, except `${user_config.sources_dir}/manifest.json`.
- Never wikilink files under `${user_config.sources_dir}/` — reference them with inline-code paths only (e.g. `` `${user_config.sources_dir}/articles/foo.md` ``); their basenames collide with `${user_config.wiki_root}/sources/` pages.

## 2. Delta check (always first)

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
   source_type: <Web article | Journal entry | Book | Notes>  # web-published recipes use "Web article" (live precedent) — there is no separate Recipe value
   source_url: <URL — omit if none>
   author: <author — omit if unknown>
   publisher: <site or publication — omit if none>
   published: <YYYY-MM-DD — omit if unknown>
   date: <YYYY-MM-DD — journal entries only>
   ingested: <YYYY-MM-DD>
   confidence: <high|medium|low>
   key_claims:            # optional enrichment
     - <claim 1>
     - <claim 2>
   tags:
     - source
     - <category: articles|journal|notes|recipes>
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
3. **Create or update entity/people/area/resource pages** touched by the source's content — new `[[People]]`, `[[Areas]]`, or `[[Resources]]` pages, or edits to existing ones. Apply the Mode-D filing map (section 4) to decide where. Watch for contradictions with existing pages: if the source conflicts with a claim already in the wiki, add a `> [!contradiction]` callout to **both** the new and the existing page, describing the conflict — don't silently overwrite.
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
     "hash": "<md5 hash from step 2 of the delta check>",
     "ingested_at": "<YYYY-MM-DD>",
     "pages_created": ["${user_config.wiki_root}/sources/<Title>.md", "..."],
     "pages_updated": ["${user_config.wiki_root}/areas/....md", "..."]
   }
   ```

## 4. Mode-D filing map

- **Recipes** → `${user_config.wiki_root}/resources/recipes/`, plus a link from `[[Cooking]]`.
- **Books** → `${user_config.wiki_root}/resources/books/`, plus a link from `[[Reading]]`.
- **Journal entries** → the `${user_config.wiki_root}/sources/` summary page, plus updates to any areas/people mentioned in the entry.
- **Engineering articles** → `${user_config.wiki_root}/engineering/` (Effect-TS pieces go in `${user_config.wiki_root}/engineering/effect-ts/`).
- **Trips** → `${user_config.wiki_root}/areas/travel/` (one page per trip).
- **Tools, orgs, projects** → `${user_config.wiki_root}/resources/`.
- **People** → `${user_config.wiki_root}/people/`.

## 5. Batch mode

When 2 or more sources are pending ingest:

1. List the pending sources (from the delta check) and confirm with the user before dispatching.
2. Dispatch one `kowalski:ingest-worker` agent per source, in parallel. Each worker processes its source's single-source flow (section 3) **except** the shared files — workers do not touch `${user_config.wiki_root}/index.md`, `${user_config.wiki_root}/log.md`, `${user_config.wiki_root}/hot.md`, `${user_config.sources_dir}/manifest.json`, **or any folder `_index.md`** (two workers filing into the same folder would race on its `_index.md`). Each worker returns: pages created, pages updated, proposed `_index.md` lines (folder → line), its proposed manifest entry (with hash), a key insight, and any contradictions found.
3. Once all workers report back, the orchestrator does one cross-reference pass across the newly created/updated pages (link related entities to each other, resolve any contradictions flagged by multiple workers) and applies every worker's proposed `_index.md` lines to the relevant folder catalogs.
4. The orchestrator then performs a **single** update to `${user_config.wiki_root}/index.md`, `${user_config.wiki_root}/log.md` (one log entry per source, or a combined batch entry — orchestrator's call), `${user_config.wiki_root}/hot.md`, and `${user_config.sources_dir}/manifest.json` (merging in every worker's proposed entry).

**Single-writer rule: only the orchestrator writes `${user_config.wiki_root}/index.md`, `${user_config.wiki_root}/log.md`, `${user_config.wiki_root}/hot.md`, `${user_config.sources_dir}/manifest.json`, and — in batch mode — all folder `_index.md` files. Workers never write these files, even when running in parallel — this is what prevents concurrent writers from corrupting the shared catalogs, log, cache, and manifest.**
