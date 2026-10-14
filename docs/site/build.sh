#!/usr/bin/env bash
# Build the Obsidian vault into a static site with Quartz, next to the Documenter site.
#
#   docs/site/build.sh               # -> docs/build/vault/
#   docs/site/build.sh --serve       # local preview on http://localhost:8080
#
# Layout:
#   docs/site/quartz.config.ts      our config    (committed)
#   docs/site/quartz.layout.ts      our layout    (committed)
#   docs/quartz/                    Quartz v4 checkout (gitignored; cloned on first run)
#   docs/quartz/content/            staged copy of the vault (regenerated every run)
#   docs/build/vault/               output — deployed by Documenter as <site>/dev/vault/
#
# The vault is the whole repository (see "vault/Start Here.md"), but its notes live in two places:
# vault/ and the *.md files beside src/*.jl. Quartz wants one content directory, so this script
# stages them together. Wikilinks resolve by basename ("shortest"),
# exactly as Obsidian does, so the staged directory structure is only for breadcrumbs.
set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$HERE/../.." && pwd)"
QUARTZ="$ROOT/docs/quartz"
OUT="$ROOT/docs/build/vault"
SERVE=0
[[ "${1:-}" == "--serve" ]] && SERVE=1

# --- 1. a Quartz checkout -----------------------------------------------------
if [[ ! -f "$QUARTZ/package.json" ]]; then
  echo ">> cloning Quartz v4 into docs/quartz"
  git clone --depth 1 --branch v4 https://github.com/jackyzha0/quartz.git "$QUARTZ"
fi
if [[ ! -d "$QUARTZ/node_modules" ]]; then
  echo ">> npm ci"
  (cd "$QUARTZ" && npm ci --no-audit --no-fund)
  # npm >= 12 blocks install scripts by default; esbuild and sharp need theirs to fetch
  # their native binaries, so approve them and rebuild.
  (cd "$QUARTZ" && npm install-scripts approve esbuild sharp @parcel/watcher >/dev/null 2>&1 \
     && npm rebuild esbuild sharp @parcel/watcher --no-audit --no-fund) || true
fi

# --- 2. our configuration over the stock one ----------------------------------
cp "$HERE/quartz.config.ts" "$QUARTZ/quartz.config.ts"
cp "$HERE/quartz.layout.ts" "$QUARTZ/quartz.layout.ts"

# --- 2b. the TikZ plugin (renders ```tikz blocks to SVG at build time) -------------
# Ported from MathStruct/CategoryTheory-ML-Wiki. The stock checkout has neither the plugin
# nor its dependency, so both are added here; the render cache lives in this directory and
# is committed, so a fresh clone only renders diagrams that are new.
if [[ ! -d "$QUARTZ/node_modules/node-tikzjax" ]]; then
  echo ">> npm install node-tikzjax"
  (cd "$QUARTZ" && npm install --no-save --no-audit --no-fund node-tikzjax@^1.0.5)
fi
cp "$HERE/tikz.ts" "$QUARTZ/quartz/plugins/transformers/tikz.ts"
grep -q 'from "./tikz"' "$QUARTZ/quartz/plugins/transformers/index.ts" || \
  echo 'export { TikZ } from "./tikz"' >> "$QUARTZ/quartz/plugins/transformers/index.ts"
mkdir -p "$HERE/.tikz-cache"
rm -rf "$QUARTZ/.tikz-cache" && ln -s "$HERE/.tikz-cache" "$QUARTZ/.tikz-cache"

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
whose [theory vault](https://mathstruct.org/Lenticulum.jl/dev/vault/) explains the implicit
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
- **[API documentation](../)**: the Julia package itself, built with Documenter.
- **[Lenticulum's vault](https://mathstruct.org/Lenticulum.jl/dev/vault/)** and the
  **[CT-ML wiki](https://mathstruct.org/CategoryTheory-ML-Wiki/)**: the theory this builds on.
MD

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
cd "$QUARTZ"
if [[ $SERVE -eq 1 ]]; then
  exec npx quartz build --serve -o "$OUT"
else
  npx quartz build -o "$OUT"
  echo ">> vault built into docs/build/vault ($(find "$OUT" -name '*.html' | wc -l) pages)"
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
