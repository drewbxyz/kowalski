---
name: wiki-query
description: Answer questions using the wiki. Reads hot.md first, then index.md, then relevant pages, and synthesizes an answer with [[wikilink]] citations. Triggers on: what do you know about, query, search the wiki, based on the wiki, find in wiki.
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

## 2. Read order

Always follow this order, stopping as soon as the current mode's page budget is spent:

1. **`${user_config.wiki_root}/hot.md`** — recent context and session seed. Read this first, always, in every mode. It often already answers freshness questions ("what's the status of X right now") on its own.
2. **`${user_config.wiki_root}/index.md`** — master catalog. Use it to identify which hub page(s) and folder(s) are relevant to the question.
3. **Relevant folder `_index.md`** — e.g. `${user_config.wiki_root}/areas/_index.md`, `${user_config.wiki_root}/resources/_index.md`. Use these to find the long tail of pages the top-level index doesn't list (sources, recipes, books, one-off entity pages).
4. **Individual pages** — the hub page(s) plus any linked entity/people/source pages the question actually needs. Cap this at **3–5 pages** in standard mode.

Do not skip straight to grepping the vault or guessing a filename — walk the hierarchy in order so you pick up the same hub pages a human would land on.

## 3. Modes

Pick a mode from the phrasing of the request; default to standard when unclear.

- **Quick** — for freshness/status checks ("what's the status of X", "where are we on X"). Read only `${user_config.wiki_root}/hot.md` and `${user_config.wiki_root}/index.md`. Do not open individual pages. If those two files don't fully answer the question, say so and offer to go deeper rather than silently escalating to standard mode.
- **Standard** (default) — full read order above, capped at 3–5 individual pages beyond hot.md/index.md/folder `_index.md`. This is the right mode for most "what do you know about X" and "query the wiki for X" requests.
- **Deep** — triggered by phrasing like "everything we know about X" or an explicit "deep" request. Read 10+ pages as needed, and `grep -ri "<term>" ${user_config.wiki_root}/` sweeps across the whole `${user_config.wiki_root}/` tree are allowed to find pages the index and folder catalogs missed (e.g. a mention buried in a source summary or a people page). Still start with the standard read order first — grep is a supplement to catch what indexing missed, not a replacement for it.

## 4. Synthesis rules

- Cite every page a claim came from with a `[[wikilink]]`, inline, near the claim it supports — not just as a trailing "sources" list.
- Volatile running stats (life-list counts, PRs, project metrics, etc.) must be quoted **only** from their single hub page (per the Single source of truth rule in section 1). If a non-hub page restates a stale version of the same number, prefer the hub's number and do not repeat the stale one as if current.
- Never present a stale snapshot as the current state. If `hot.md` or the hub page contradicts an older page, the newer/hub source wins — say so explicitly if the discrepancy is material to the answer (e.g. "as of [[Birding]] the life list is at 1,312; an earlier trip note says 1,229 but that's a historical snapshot, not current").
- If pages disagree and it isn't a simple staleness issue, surface the conflict rather than picking one silently.

## 5. Close-out behavior

- After answering, name any gaps explicitly rather than staying silent about them: "the wiki has nothing on X — want me to autoresearch it?" (hand off to the `autoresearch` skill if the user says yes).
- If the answer is substantial (synthesized multiple pages into new insight, not just a quote-and-cite lookup), offer to file it back into the wiki via the `wiki-save` skill so future queries can read it directly instead of re-synthesizing.
- Keep the offer proportional: a one-line quick-mode answer doesn't need a save offer; a multi-page deep-mode synthesis usually does.
