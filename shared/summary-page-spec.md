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
