#!/usr/bin/env bash
# Build the Obsidian vault into a static site with Quartz, next to the Documenter site.
#
#   docs/site/build.sh               # -> docs/vault-build/
#   docs/site/build.sh --serve       # local preview on http://localhost:8080
#
# Layout:
#   docs/site/quartz.config.ts      our config    (committed)
#   docs/site/quartz.layout.ts      our layout    (committed)
#   docs/site/.tikz-cache/          rendered TikZ diagrams (committed)
#   docs/quartz/                    MathStruct's Quartz (gitignored; cloned on first run)
#   docs/quartz/content/            staged copy of the vault (regenerated every run; inside the
#                                   checkout because Quartz skips what this repository gitignores)
#   docs/vault-build/               output — deployed as the site's front page by
#                                   docs/site/deploy_vault.sh
#
# Environment (set by docs/make.jl): VAULT_BASEURL (default mathstruct.org/LenticulumLM) and
# VAULT_API_URL (where the API docs are; default <site>/api/dev/).
#
# The vault is the whole repository (see "vault/Start Here.md"), but its notes live in two places:
# vault/ and the *.md files beside src/*.jl. Quartz wants one content directory, so this script
# stages them together. Wikilinks resolve by basename ("shortest"),
# exactly as Obsidian does, so the staged directory structure is only for breadcrumbs.
set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$HERE/../.." && pwd)"
QUARTZ="$ROOT/docs/quartz"
OUT="${VAULT_OUT:-$ROOT/docs/vault-build}"
API_URL="${VAULT_API_URL:-https://mathstruct.org/LenticulumLM/api/dev/}"
SERVE=0
[[ "${1:-}" == "--serve" ]] && SERVE=1

# --- 1. MathStruct's Quartz --------------------------------------------------------
# Quartz plus the plugins and fixes all MathStruct sites share (TikZ with dark-mode variants,
# tabs, Typst, ...): https://github.com/MathStruct/quartz. It is cloned into docs/quartz/
# (gitignored) and moved to QUARTZ_REF on every build. QUARTZ_DIR=<your checkout of it> builds
# with that checkout as it is, to try out a change to the shared Quartz.
QUARTZ_REF="${QUARTZ_REF:-main}"
if [[ -n "${QUARTZ_DIR:-}" ]]; then
  QUARTZ="$QUARTZ_DIR"
else
  # an older checkout of stock Quartz is replaced
  if [[ -d "$QUARTZ" && ! -f "$QUARTZ/mathstruct/site.sh" ]]; then rm -rf "$QUARTZ"; fi
  [[ -d "$QUARTZ/.git" ]] || git clone -q --depth 1 https://github.com/MathStruct/quartz.git "$QUARTZ"
  if git -C "$QUARTZ" fetch -q --depth 1 origin "$QUARTZ_REF"; then
    git -C "$QUARTZ" checkout -q -f --detach FETCH_HEAD
  else
    echo ">> offline: building with docs/quartz as it is ($(git -C "$QUARTZ" rev-parse --short HEAD))"
  fi
fi
# docs/site/ holds our quartz.config.ts, quartz.layout.ts and .tikz-cache/ (committed: the
# rendered diagrams, keyed by content hash, so CI only renders new ones); mathstruct/site.sh
# puts them in place. A preview build (docs/make.jl off master) sets VAULT_BASEURL, which
# quartz.config.ts reads.

# --- 3. stage the vault ----------------------------------------------------------
CONTENT="$QUARTZ/content"
rm -rf "$CONTENT"
mkdir -p "$CONTENT"

# the bibliography note is generated from docs/src/refs.bib, so the vault and the docs agree,
# and so is the reference list of CITATION.cff (GitHub's citation button, the Zenodo archive)
python3 "$ROOT/docs/site/bib2vault.py" > /dev/null
python3 "$ROOT/docs/site/bib2cff.py" > /dev/null

# the theory notes (meta/ is local working material, ignored by git and never published)
cp -r "$ROOT/vault/." "$CONTENT/"

# the implementation notes that sit beside the Julia source
mkdir -p "$CONTENT/src" && cp "$ROOT"/src/*.md "$CONTENT/src/"
# and the notes of the experiments, one directory each (vault/Design/Environment and Experiments.md)
for ex in "$ROOT"/experiments/*/; do
  [[ -d "$ex" ]] || continue
  if compgen -G "$ex*.md" > /dev/null; then
    mkdir -p "$CONTENT/experiments/$(basename "$ex")"
    cp "$ex"*.md "$CONTENT/experiments/$(basename "$ex")/"
  fi
done

# the root-level note the vault links to as [[README]].
# It is written for GitHub, so its repo-relative links are rewritten for the site:
# any vault/<path>.md link becomes a site-relative link (Quartz slugs spaces to hyphens),
# and links to other files in the repository go to GitHub.
sed -e 's#](vault/\([^)]*\)\.md)#](\1)#' \
    -e 's#](docs/src/assets/\([^)]*\))#](https://raw.githubusercontent.com/MathStruct/LenticulumLM/master/docs/src/assets/\1)#' \
    -e 's#](\(docs/[^)]*\|meta/[^)]*\))#](https://github.com/MathStruct/LenticulumLM/blob/master/\1)#' \
    -e '/](https:/!s#%20#-#g' \
    "$ROOT/README.md" > "$CONTENT/README.md"

# the site's front page
cat > "$CONTENT/index.md" <<'MD'
---
title: LenticulumLM — theory vault
---

[LenticulumLM](https://github.com/MathStruct/LenticulumLM) assembles a **diffusion language
model from implicit learners**: relations over a few token positions each, combined by product
into one model whose every query (continue, predict backwards, fill in) is root finding with the
known tokens clamped. It builds on [Lenticulum.jl](https://github.com/MathStruct/Lenticulum.jl),
whose [theory vault](https://mathstruct.org/Lenticulum.jl/) explains the implicit
learners themselves. This vault records what is specific to language: the design, the
implementation, and what does not work yet.

## Where to start

1. [[Assembling a Language Model from Implicit Learners]]: the plan, and the decisions ahead
2. [[tokens]] and [[sequence]]: text as a joint space, and an $n$-gram chain assembled from
   relations, exact in every query direction
3. [[Open Problems in Assembling Language Models]]: the roadmap, step by step

## Everything else

- **[[Map of Content]]**: every note, in reading order.
- **[[Start Here]]**: how the vault is organised, its conventions, and how to read it in Obsidian.
- **[[README]]**: the project pitch.
- **[API documentation](@API@)**: the Julia package itself, built with Documenter.
- **[Lenticulum's vault](https://mathstruct.org/Lenticulum.jl/)** and the
  **[CT-ML wiki](https://mathstruct.org/CategoryTheory-ML-Wiki/)**: the theory this builds on.
MD

sed -i "s#@API@#$API_URL#g" "$CONTENT/index.md"

# --- 3b. lint: display math that Obsidian accepts but remark-math truncates on -----------
# A `$$` block opened with content on the fence line and closed with `$$` at the end of a
# later content line is an *unclosed fence* to remark-math: everything after it vanishes from
# the rendered page, silently. Obsidian renders it fine, so nothing else catches this.
# Fences must sit on their own lines. Refuse to build rather than publish truncated pages.
python3 - "$CONTENT" <<'PY'
import sys, glob, os
root = sys.argv[1]; bad = []
for f in glob.glob(os.path.join(root, "**", "*.md"), recursive=True):
    lines = open(f, encoding="utf-8").read().split("\n"); i = 0
    while i < len(lines):
        # strip blockquote / list prefixes so math inside callouts and list items is seen too
        r = lines[i].rstrip().lstrip("> ").lstrip()
        if r.startswith("$$") and len(r) > 2 and not (r.endswith("$$") and len(r) > 4):
            j = i + 1
            while j < len(lines) and not lines[j].rstrip().endswith("$$"): j += 1
            if j < len(lines) and lines[j].strip() != "$$": bad.append((os.path.relpath(f, root), i + 1))
            i = j
        i += 1
if bad:
    print("!! display-math blocks that would truncate their page (put the $$ fences on their own lines):")
    for f, n in bad: print(f"   {f}:{n}")
    sys.exit(1)
PY

# --- 3c. dates: each page as old as its source's last change, not as new as this copy ----
python3 "$HERE/git_dates.py" "$CONTENT"

# --- 4. build ---------------------------------------------------------------------
if [[ $SERVE -eq 1 ]]; then
  exec "$QUARTZ/mathstruct/site.sh" "$HERE" "$CONTENT" "$OUT" --serve
else
  "$QUARTZ/mathstruct/site.sh" "$HERE" "$CONTENT" "$OUT"
  echo ">> vault built into ${OUT#$ROOT/} ($(find "$OUT" -name '*.html' | wc -l) pages)"
  # KaTeX renders with throwOnError:false, so a bad formula becomes red text rather than a
  # failed build. Surface them here (e.g. \tag in a single-line $$...$$, which remark-math
  # parses as *inline* math — put such fences on their own lines).
  if grep -rl 'katex-error' "$OUT" --include='*.html' >/dev/null; then
    echo "!! KaTeX parse errors in:"
    grep -rho 'katex-error" title="[^"]*"' "$OUT" --include='*.html' | sort | uniq -c
    grep -rl 'katex-error' "$OUT" --include='*.html' | sed "s#^$OUT/#   #"
    exit 1
  fi
fi
