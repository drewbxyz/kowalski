---
name: wiki-save
description: Save the current conversation or a specific insight into the wiki vault as a structured note. Triggers on: save this, file this, save to wiki, keep this.
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

## 2. What this skill is for

wiki-save files something from **this conversation** — an answer, an insight, a decision, an update the user just told you — into the wiki. There is no source document to read; the content already exists in the chat transcript. (If the user instead hands you a file, URL, or other artifact to process, that's `wiki-ingest`'s job — hand off to it instead.)

Identify what's being saved before doing anything else:

- **A specific insight** the user names ("save that answer about X") — save just that.
- **The whole conversation** ("save this session") — save the durable takeaways, not a transcript dump. Compress: pull out conclusions, decisions, and facts worth remembering; drop exploratory back-and-forth that didn't land anywhere.

## 3. Mandatory first step: search before you file

Never create a page on reflex. Before deciding where content goes, run:

```bash
grep -ril '<topic keyword>' ${user_config.wiki_root}/
```

Try a couple of keyword variants if the first grep comes up empty (e.g. both "espresso" and "Coffee" for a dial-in note). Also open `${user_config.wiki_root}/index.md` and skim the curated links for the relevant area. Then decide:

- **An existing page already covers this topic** → update it (see section 5). This is the default outcome for anything touching a life area (health, work, travel, hobbies, …), since those hubs already exist in the vault.
- **Nothing existing fits** → create a new page (see section 4). When you create, name in your response which existing pages you checked and ruled out (e.g. "checked [[Coffee]] and [[Cooking]] — this is a new roaster comparison, not a dial-in update, so it gets its own resource page linked from both").

## 4. Detecting note type → destination (when creating new)

First discover where this vault files the content shape, per the Vault Context discovery rule (`overview.md`, folder `_index.md` catalogs, where existing peer pages live), and file alongside those peers. Two shape notes:

- **An answer to a question**, synthesized from the wiki or general knowledge and worth keeping, is a source-less page — no `${user_config.sources_dir}/` entry and no `${user_config.wiki_root}/sources/` summary page, because there is no raw source.
- **A life/admin update about something already tracked** (a trip detail, a status change, a running log entry) updates the relevant existing hub page — do not create a new page for this case.

If no precedent exists anywhere, do not pick a location yourself — propose 1–2 sensible options to the user, grounded in what the vault already looks like and what they seem to care about, confirm, then file. When a new folder is agreed, register it (create its `_index.md`, link it from `${user_config.wiki_root}/index.md`).

This guidance only applies once section 3's search comes up empty. A "life/admin update" almost never creates a new page — it updates the hub that already exists.

## 5. Updating an existing page

- Add or revise the relevant section in place; don't duplicate content that's already there.
- Bump `updated:` in the frontmatter to today's date.
- If the update closes something out that was previously "upcoming" or "in progress" elsewhere in the vault, grep for it and close the loop on those references too (per the Vault Context MUST rules above).
- If the new content conflicts with an existing claim on the page, add a `> [!contradiction]` callout rather than silently overwriting.

## 6. Creating a new page

Only after section 3 confirms nothing fits. Full frontmatter, matching the shape of live pages in the same folder (open one to confirm the schema if unsure):

```yaml
---
type: <note|source|resource|... — match sibling pages in the destination folder>
title: <Title>
status: <evergreen|active|... — match sibling pages>
created: <YYYY-MM-DD>
updated: <YYYY-MM-DD>
tags:
  - <relevant tags>
---
```

No blank line between the closing `---` and the `# Title` heading. Link the new page from whatever hub page is topically closest (e.g. a new coffee-adjacent resource page still gets linked from [[Coffee]]).

## 7. Third-party privacy (applies here too)

Saved conversations are the highest-risk path for this: chats casually mention what's going on with other people. Before writing anything, check every sentence that names someone other than the vault owner for medical, financial, or similarly private detail. Keep at most one neutral line (e.g., "away for medical treatment") — no diagnoses, prognoses, treatment plans, financial figures, or similar specifics about third parties, even if the user stated them plainly in the conversation.

## 8. Shared-file updates, in order

After the page-level write (sections 5 or 6), always work through these in order:

1. **Touched folder `_index.md`** — add or update the line for the page you created or edited.
2. **`${user_config.wiki_root}/index.md`** — only when a page was created or renamed. A pure content update to an existing page (section 5) does not need an index.md edit unless the curated link's description text is now stale.
3. **`${user_config.wiki_root}/log.md`** — append a new entry at the TOP, exactly this shape:
   ```markdown
   ## [YYYY-MM-DD] save | <Title>

   - Saved: <what was captured — insight, answer, update>
   - Pages created: [[Page A]]
   - Pages updated: [[Page B]]
   - Key insight: <one sentence>
   ```
   Omit "Pages created" or "Pages updated" if empty rather than leaving them blank.
4. **`${user_config.wiki_root}/hot.md`** — update only if this save changes what's currently active/recent enough to belong in the session seed (~500 words). Most single-fact saves don't need this; a save that shifts what's "in progress" right now does.
