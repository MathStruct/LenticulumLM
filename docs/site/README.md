# The vault as a website

The Obsidian vault is rendered to a static site with [MathStruct's Quartz](https://github.com/MathStruct/quartz)
(Quartz v4 plus the plugins all MathStruct sites share)
and is the **front page** of the project's site, [mathstruct.org/LenticulumLM](https://mathstruct.org/LenticulumLM/);
the Documenter site (the API docs and tutorials) is under `api/dev/`. `docs/make.jl` builds both
and deploys the API docs (`deploydocs(dirname = "api")`); the Docs workflow then deploys the
vault with `deploy_vault.sh`, which also rewrites `dev/`, the site's address until October 2026,
as redirect stubs to the new addresses (`redirects.py`). The two sites link to each other:
Documenter's "Theory vault" page points here, and this site's footer points back.

## Building locally

```sh
docs/site/build.sh             # builds into docs/vault-build/
docs/site/build.sh --serve     # live preview at http://localhost:8080
```

Needs git and Node ≥ 22. The first run clones MathStruct's Quartz into `docs/quartz/`
(gitignored) and installs its dependencies; later runs move it to the latest `main`.
`QUARTZ_DIR=<your checkout of MathStruct/quartz>` builds with that checkout instead, to try a
change to the shared Quartz on this vault before pushing it. `docs/make.jl` calls this script automatically when `npx` is on the path, so a
normal Documenter build produces both sites.

## How it is put together

| file | is |
|---|---|
| `quartz.config.ts` | our Quartz configuration: a call to the shared preset (title, address, dates) |
| `quartz.layout.ts` | our layout: the shared one, plus a footer link back to the API docs |
| `.tikz-cache/` | the rendered TikZ diagrams, keyed by content hash — **committed** |
| `build.sh` | fetches MathStruct's Quartz, stages the vault, lints it, builds |

The vault is the whole repository, so the notes live in two places, `vault/` and the
`*.md` beside each `src/*.jl`. Quartz wants one directory, so the script
copies them together. Wikilinks resolve by basename, exactly as in Obsidian, so the staged
directory structure only affects breadcrumbs.

## TikZ

The shared Quartz renders ```` ```tikz ```` blocks (the Obsidian Inline TikZ format:
`\usepackage` lines, then `\begin{document} … \end{document}`) with
[`node-tikzjax`](https://www.npmjs.com/package/node-tikzjax), each with a dark-mode variant
whose colours are remapped, and caches the SVG under its content hash in `.tikz-cache/`.
Because the cache is committed, a fresh clone — and CI — only renders diagrams that are new or
changed. A block that fails to compile is emitted as its source in a `<pre class="tikz-error">`
and the failure is printed at build time; it does not break the build.

## The one thing to know about `$$`

Obsidian accepts a display-math block written as

```
$$a = b
c = d$$
```

remark-math (what Quartz uses) does not: it reads the first line as an unclosed fence and
**silently drops everything after it from the page**. Thirty notes were being truncated this
way before it was caught. `build.sh` now refuses to build if the pattern is present. Put the
fences on their own lines:

```
$$
a = b
c = d
$$
```

## What does not render

- **`meta/`** is excluded — local working material, not tracked in git and not vault content.
