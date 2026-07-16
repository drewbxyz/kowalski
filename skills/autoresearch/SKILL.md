---
name: autoresearch
description: Research an explicit web topic and file the results into the wiki as structured pages. Triggers on: autoresearch, research X, deep dive into X, investigate X, build a wiki on X.
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

## 2. Topic must be explicit

**Never auto-select a topic.** If the user's request doesn't name a concrete topic (e.g. "autoresearch" with nothing after it, or "research something interesting"), stop and ask what to research — do not infer or pick one yourself.

This is a hard rule, not a preference: an earlier version of this tool picked topics automatically by scoring "boundary" gaps in the wiki's link graph (concepts mentioned but never fleshed out). That produced research nobody asked for and drifted from what the vault owner actually wanted the vault to know. The fix was to require a human-named topic every time. Do not reintroduce graph-driven topic selection.

If the user gives a topic that's really a whole domain ("coffee"), narrow it with one clarifying question before planning (e.g. "home espresso machine maintenance, or roasting, or something else?") rather than guessing scope.

## 3. Plan before searching

Once the topic is confirmed, decompose it into **3–6 sub-questions** that together cover the topic at a useful depth — specific enough to search well, broad enough that answering all of them tells a complete story. Examples of the right grain: for "home espresso machine maintenance" — descaling frequency and method, backflushing/group-head cleaning, water quality and filtration, gasket/seal replacement intervals, troubleshooting common failure symptoms.

**Show this plan to the user before running any searches.** State it as a short numbered list and let them trim, add, or reorder sub-questions. If the user doesn't respond (e.g. running non-interactively or has already said "just go"), proceed with the plan as drafted — but always show it in the transcript so the reasoning is visible.

## 4. Research loop

Work through the sub-questions from the confirmed plan, one at a time:

1. **WebSearch** the sub-question. Read the result snippets to pick the most relevant, authoritative-looking sources — prefer primary/official sources (manufacturer docs, standards bodies, established outlets) over SEO content farms and forum posts, but a forum thread with genuine specifics beats a thin blog rewrite.
2. **Fetch the top 2–3 sources** for that sub-question with the Defuddle CLI: run `defuddle parse <url> --md`. Defuddle takes the URL directly and returns clutter-stripped markdown — it *replaces* WebFetch for these fetches (it cannot clean text you've already fetched some other way). Fall back to WebFetch only for a URL where defuddle fails or on a machine where it isn't installed.
3. **Extract claims**, each tagged with which source it came from. A claim is a single factual statement worth keeping ("descale every 3 months with citric acid solution, per Breville's official manual"), not a paragraph summary. Keep the sub-question, the claim, the source URL, and a rough confidence read (does the source seem authoritative and current, or thin/dated/contradicted elsewhere) together as you go — this is what frontmatter and body will be built from in section 5.
4. If two sources disagree, keep both claims and note the disagreement — don't silently pick a winner.

Move to the next sub-question and repeat.

**Stop conditions — check these after every sub-question, and stop the loop the moment one is met:**

- All sub-questions in the confirmed plan have at least one round of search + extraction. This is the normal, expected exit.
- **Two consecutive searches** (within a sub-question or across sub-questions) surface no new claims beyond what's already been extracted — the same handful of sources and facts keep resurfacing. Stop there rather than search a third time hoping for something new.
- The user set a round or search cap when confirming the plan (e.g. "keep it to 2 rounds"). Stop at the cap even if sub-questions remain uncovered — note what got dropped in the close-out.

Do not keep searching past these conditions "just to be thorough." No open-ended crawling.

## 5. File the results

Structure:

- **One research hub page** for the topic. Place it per the Vault Context discovery rule — find where this vault keeps hub pages for that kind of topic (`overview.md`, folder `_index.md` catalogs, existing peers) and file alongside them; if the vault has no obvious home for this topic, ask the user where research pages should live before writing (propose 1–2 options grounded in the vault's existing shape), and register any agreed new folder (create its `_index.md`, link it from `${user_config.wiki_root}/index.md`). Match the structure and tone of an existing research/hub page in the destination folder — open a live page there first if unsure. Shape: a clear intro paragraph stating scope and any constraints, then one section per sub-question / theme, callouts (`> [!tip]`, `> [!warning]`, `> [!gap]`) for caveats and open questions, and a `## Sources` section listing every URL used with a one-line confidence note per source (`high (official docs)`, `medium (dated blog)`, etc.).
- **Per-facet pages only when a facet is independently substantial** — enough content that it would bloat the hub or that it's likely to be searched/linked on its own (e.g. a specific product or technique that deserves its own entity page). Most autoresearch runs should produce just the one hub page; don't split reflexively.

Frontmatter for every page created or touched by this skill carries provenance in addition to the standard MUST fields:

```yaml
sources:
  - "<URL 1>"
  - "<URL 2>"
confidence: <high|medium|low>   # overall confidence in the page, not just one claim
```

Use the existing `sources:` frontmatter convention — open a live page that already carries a `sources:` list first if unsure of the shape — a flat list of URLs (or `${user_config.sources_dir}/...` paths when a source doubles as an ingested document). Where individual claims within the body carry differing confidence or conflicting sources, call that out inline (a `> [!contradiction]` or a parenthetical attribution) rather than only in frontmatter — frontmatter `confidence` is the page-level summary, not a substitute for per-claim attribution built during the research loop.

After writing the page(s):

1. **Update the relevant folder's `_index.md`** — add a line for each new page.
2. **Update `${user_config.wiki_root}/index.md`** — add or adjust the curated link.
3. **Append a log entry to the TOP of `${user_config.wiki_root}/log.md`**:
   ```markdown
   ## [YYYY-MM-DD] autoresearch | <Topic>

   - Rounds: <n> | Searches: <n>
   - Pages created: [[Page A]], [[Page B]]
   - Pages updated: [[Page C]]
   - Key finding: <one or two sentences>
   - Not covered: <dropped sub-questions or thin areas, or "none">
   ```
4. **Update `${user_config.wiki_root}/hot.md`** if this research is current/active context worth surfacing in the session seed (it usually is, right after filing).

## 6. Close-out summary in chat

End every run with a summary in the chat response — don't rely on the log entry alone:

- Every page **created** and every page **updated**, each with a one-line rationale for why it exists or changed.
- What was **not** covered: sub-questions dropped due to a stop condition or round cap, and any areas that came out thin (few sources, low confidence, disagreement unresolved).
