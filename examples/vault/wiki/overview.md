---
type: overview
status: evergreen
created: 2026-07-10
updated: 2026-07-10
tags: [overview]
---
# Vault Overview

Stable shape of this vault (current status lives in [[hot]]).

This is a minimal example vault demonstrating the kowalski plugin contract with
the default configuration (`wiki_root: wiki`, `sources_dir: sources`).

## Layout

- `sources/` — raw source drop zone, organized by category subfolder (currently just `articles/`). Tracked by `sources/manifest.json`. Raw files are never modified and never wikilinked.
- `wiki/index.md`, `hot.md`, `log.md`, `overview.md` — contract files.
- `wiki/sources/` — one summary page per raw source.
- `wiki/topics/` — this vault's single content folder, holding baking and fermentation topic pages. **This layout is this vault's own choice**: kowalski prescribes no content taxonomy — the skills discover each vault's structure from this file and the folder `_index.md` catalogs, and a real vault might instead grow `people/`, `projects/`, `recipes/`, or anything else its owner needs.
- `wiki/meta/` — dashboard and lint reports; superseded reports rotate into `meta/archive/`.

## Filing conventions here

Topic pages about baking and fermentation concepts go in `topics/`, alongside
their peers, and are cataloged in the folder's `_index.md`.
