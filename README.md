# kowalski

Claude Code plugin for LLM-maintained Obsidian wiki operations ("Kowalski Wiki Ops"): **ingest** sources, **query** the wiki, **lint** its health, **save** conversation insights, and **autoresearch** web topics — with parallel worker agents for batch ingest and large lints, and hooks that keep the wiki's hot cache (`hot.md`) loaded and fresh.

This repo is both the plugin and its own single-plugin marketplace.

> **Scope:** works with any vault structure — the skills discover the vault's content layout at runtime (via `overview.md`, the folder `_index.md` catalogs, and where existing pages already live). The only hard requirements are the plugin-contract paths: `index.md`, `hot.md`, `log.md`, `overview.md`, `sources/`, and `meta/` under `wiki_root`; an `_index.md` catalog per wiki folder; and `sources_dir` with its `manifest.json`. Where no structure exists yet — a fresh vault, or a genuinely new kind of content — the skills design one with the user rather than applying a template. Adopters set `wiki_root`/`sources_dir` via `/plugin configure kowalski`.

## Contents

```
.claude-plugin/
├── plugin.json        # manifest + userConfig (wiki_root, sources_dir)
└── marketplace.json   # self-hosting marketplace ("drewbeamer") listing this plugin
skills/                # wiki-ingest, wiki-query, wiki-lint, wiki-save, autoresearch
agents/                # ingest-worker, lint-worker (dispatched as kowalski:<name>)
hooks/hooks.json       # SessionStart + PostCompact (cat hot.md), Stop (command hook: hot.md staleness check)
```

## Configurable paths

On enable, Claude Code prompts for two directories (persisted per machine in `settings.json → pluginConfigs`):

| Option | Default | Meaning |
|---|---|---|
| `wiki_root` | `wiki` | The wiki folder, relative to the vault root |
| `sources_dir` | `sources` | The synced source drop-zone, relative to the vault root |

`${user_config.*}` placeholders in skill/agent content and the hook commands are substituted **before the model reads them**, so the skills' bash commands carry the literal configured paths. Content folders under `wiki_root` are discovered at runtime rather than fixed (see the skills' Vault Context block) — only the two roots are configurable.

## Install

```
# from GitHub
/plugin marketplace add drewbxyz/kowalski

# or from a local clone
/plugin marketplace add <path-to-clone>

/plugin install kowalski@drewbeamer
```

Answer the two config prompts, then launch Claude Code **from the vault root** — all skill commands are vault-root-relative. The hooks themselves anchor their paths on `$CLAUDE_PROJECT_DIR` (the project root Claude Code passes to hook commands), so they resolve correctly regardless of the shell's current working directory; the skills, however, still expect a launch from the vault root.

**Recommended: enable kowalski per-project, not globally.** Its hooks fire in *every* project where the plugin is enabled, so a global enablement runs the SessionStart/PostCompact/Stop hooks in unrelated repos too. Scope it to the vault by enabling it in the vault's `.claude/settings.json` (project-level) rather than in your user-level settings — that way the hooks only run when you launch Claude Code from the vault.

Usage after install: natural-language triggers work unchanged ("ingest X", "lint the wiki", "save this"); explicit slash form is namespaced: `/kowalski:wiki-lint`, `/kowalski:wiki-ingest`, etc. Worker agents resolve as `kowalski:ingest-worker` / `kowalski:lint-worker`.

**If another wiki/knowledge-base plugin with similar skills is enabled** (ingest, lint, query, save), disable it — overlapping natural-language triggers dispatch nondeterministically to whichever the harness resolves first.

Verify the install:

- A new session launched from the vault root shows the hot cache on start, and `lint the wiki` fans out to `kowalski:lint-worker` on large vaults.
- `/plugin configure kowalski` shows both config options (`wiki_root`, `sources_dir`).
- Ending a session (Stop) in a non-vault project does nothing (the Stop hook exits immediately unless a `hot.md` exists at the configured wiki root, so it never touches unrelated repos). In the vault, editing a wiki page and then stopping without rewriting `hot.md` blocks the stop with a rewrite instruction.

### Optional dependency: defuddle CLI

The **autoresearch** skill fetches sources with [Defuddle](https://github.com/kepano/defuddle) (`defuddle parse <url> --md`), which returns clutter-stripped article markdown. Install it for cleaner source extraction:

```
npm install -g defuddle-cli
```

Without it, autoresearch degrades gracefully to WebFetch — everything still works, extraction is just noisier.

## Example vault

`examples/vault/` is a minimal vault built with the default config (`wiki_root: wiki`, `sources_dir: sources`). It serves two purposes:

- **Reference layout** — every plugin-contract file populated the way the skills expect: `index.md`, `hot.md`, `log.md`, `overview.md`, `sources/` summary pages, `meta/` with a dashboard, plus a `sources/` drop zone with one ingested sample source tracked in `manifest.json`.
- **Smoke-test target** — launch Claude Code from `examples/vault/` (with the plugin enabled) and try the skills against known-good content: `lint the wiki` should come back clean; `ingest all new` should report the sample source as already ingested and unchanged.

The `wiki/topics/` folder is illustrative only — it is one example layout this vault happens to use, not a template. The skills discover each vault's own content structure at runtime (via `overview.md` and the folder `_index.md` catalogs) rather than prescribing one.

## Development notes

- The **Vault Context** block (plugin contract + MUST rules) is shared verbatim across all 5 skills and both agents — edit all 7 copies together. CI fails if the copies diverge.
- Bump `version` in `plugin.json` when changing plugin content (`skills/`, `agents/`, `hooks/`, `.claude-plugin/`) — installed copies update from this repo, and CI enforces the bump.
- Releases are automatic: when a new `plugin.json` version lands on `main`, CI tags it `v<version>` and publishes a GitHub release with generated notes. No manual tagging.
- `displayName` is deliberately omitted (needs Claude Code ≥ 2.1.143).
