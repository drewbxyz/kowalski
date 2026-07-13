# kowalski

Claude Code plugin for LLM-maintained Obsidian wiki operations ("Kowalski Wiki Ops"): **ingest** sources, **query** the wiki, **lint** its health, **save** conversation insights, and **autoresearch** web topics — with parallel worker agents for batch ingest and large lints, and hooks that keep the wiki's hot cache (`hot.md`) loaded and fresh.

Converted from the vault-carried `tools/claude/` symlink setup per the *Kowalski Plugin Conversion Spec* (2026-07-12). This repo is both the plugin and its own single-plugin marketplace.

> **Scope:** built for the author's vault, but usable by others. To adopt it, customize three things: (a) the shared **Vault Context** block that appears verbatim in all 5 skills and both agents (the folder tree and life-area names like FRC/Birding/Coffee), (b) any inline example page references in the skill bodies, and (c) the `wiki_root`/`sources_dir` paths via `/plugin configure kowalski`. The workflow logic ports as-is.

## Contents

```
.claude-plugin/
├── plugin.json        # manifest + userConfig (wiki_root, sources_dir)
└── marketplace.json   # self-hosting marketplace ("drewbeamer") listing this plugin
skills/                # wiki-ingest, wiki-query, wiki-lint, wiki-save, autoresearch
agents/                # ingest-worker, lint-worker (dispatched as kowalski:<name>)
hooks/hooks.json       # SessionStart (cat hot.md), PostCompact + Stop (prompt hooks)
```

## Configurable paths

On enable, Claude Code prompts for two directories (persisted per machine in `settings.json → pluginConfigs`):

| Option | Default | Meaning |
|---|---|---|
| `wiki_root` | `wiki` | The wiki folder, relative to the vault root |
| `sources_dir` | `sources` | The synced source drop-zone, relative to the vault root |

`${user_config.*}` placeholders in skill/agent content and the hook command are substituted **before the model reads them**, so the skills' bash commands carry the literal configured paths. Sub-hubs (`areas/`, `engineering/`, …) are fixed names under `wiki_root` by design — only the two roots are configurable.

**Known limitation:** the PostCompact/Stop hooks are `prompt`-type, where `${user_config.*}` substitution is not documented to apply — they are worded generically ("the configured wiki root, `wiki/` by default"). With a non-default `wiki_root`, the model resolves the actual path from session context.

## Install

The vault is deliberately not a git repo, so the plugin is installed per machine from this repo (it no longer rides Obsidian Sync — update via `git pull` + plugin update instead).

```
# from a local clone
/plugin marketplace add ~/repos/kowalski

# or from GitHub once pushed
/plugin marketplace add <github-user>/kowalski

/plugin install kowalski@drewbeamer
```

Answer the two config prompts (defaults fit the standard vault layout), then launch Claude Code **from the vault root** — all skill commands are vault-root-relative.

**Recommended: enable kowalski per-project, not globally.** Its hooks fire in *every* project where the plugin is enabled, so a global enablement runs the SessionStart/PostCompact/Stop hooks in unrelated repos too. Scope it to the vault by enabling it in the vault's `.claude/settings.json` (project-level) rather than in your user-level settings — that way the hooks only run when you launch Claude Code from the vault.

Usage after install: natural-language triggers work unchanged ("ingest X", "lint the wiki", "save this"); explicit slash form is namespaced: `/kowalski:wiki-lint`, `/kowalski:wiki-ingest`, etc. Worker agents resolve as `kowalski:ingest-worker` / `kowalski:lint-worker`.

## Cutover from the vault-carried setup (per machine, once)

Do these **after** installing the plugin — the old symlinks take precedence over same-named plugin skills/agents, so leaving them means the plugin appears active but the symlinks actually run:

0. **Disable or uninstall the `claude-obsidian` plugin first.** Its skills (`wiki-ingest`, `wiki-lint`, `wiki-query`, `autoresearch`, `save`) collide with kowalski's on natural-language triggers — with both enabled, a plain "ingest this" or "lint the wiki" dispatches nondeterministically to whichever the harness resolves first. Turn it off before enabling kowalski so dispatch is unambiguous.
1. Remove the symlinks `setup.sh` created: `.claude/skills` and `.claude/agents` in the vault.
2. Remove the three hook blocks (`SessionStart`, `PostCompact`, `Stop`) from the vault's `.claude/settings.json` — the plugin's `hooks/hooks.json` replaces them.
3. Retire `tools/claude/` in the vault (its contents now live here).
4. Update the vault's `CLAUDE.md` Operations section to point at this plugin.
5. Verify:
   - New session shows the hot cache on start, and `lint the wiki` fans out to `kowalski:lint-worker`.
   - `/plugin configure kowalski` shows both config options (`wiki_root`, `sources_dir`).
   - Ending a session (Stop) in a non-vault project does nothing to any `wiki/` directory there (the Stop hook is gated on an existing `hot.md` at the configured wiki root, so it never touches unrelated repos).

For the headless Pi, confirm the plugin + marketplace trust flow works non-interactively; if it doesn't, `claude --plugin-dir ~/repos/kowalski` is the fallback load mechanism.

## Development notes

- The **Vault Context** block (structure diagram + MUST rules) is shared verbatim across all 5 skills and both agents — edit all 7 copies together.
- Skill behavior is intentionally identical to the pre-plugin `tools/claude/` versions; only paths were parameterized and worker-agent references namespaced.
- Bump `version` in `plugin.json` when changing anything — installed copies update from this repo, not from Obsidian Sync.
- `displayName` is deliberately omitted (needs Claude Code ≥ 2.1.143; the Pi may lag).
