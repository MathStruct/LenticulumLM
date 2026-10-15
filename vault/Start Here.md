#overview

> How this vault is organised, the conventions every note follows, and how to read or extend
> it. The notes themselves are indexed, in reading order, in [[Map of Content]].

## What lives where

The vault is the whole repository. Its notes sit beside what they describe:

| where | what | example |
|---|---|---|
| `vault/` | **concept and design notes**, grouped by topic | `vault/Design/Assembling a Language Model from Implicit Learners.md` |
| `src/*.md` | **implementation notes**, one beside each Julia file | `src/sequence.md` beside `sequence.jl` |
| `experiments/*/` | one directory per experiment, with its own environment and a note on what it found (planned) | |
| `meta/` | local working material, not part of the repository (ignored by git) | |

The tools come from the Nix flake (`nix develop`), and data and checkpoints live outside the
repository; both are planned in [[Environment and Experiments]].

LenticulumLM builds on [Lenticulum.jl](https://github.com/MathStruct/Lenticulum.jl), and its
vault builds on Lenticulum's [theory vault](https://mathstruct.org/Lenticulum.jl/dev/vault/):
implicit learners, diffusion relations, products and separators, beliefs and factor graphs are
explained there and **not** repeated here. The general category theory both rest on lives in the
[CT-ML wiki](https://mathstruct.org/CategoryTheory-ML-Wiki/), the root vault. This vault keeps
only what is specific to language models: how text becomes a joint space, how a language model
is assembled from relations, and what does not work yet.

## Conventions

Every note opens the same way:

1. **a tag line**: one or more of `#definition`, `#theorem`, `#derivation`, `#algorithm`,
   `#model`, `#design`, `#implementation`, `#comparison`, `#application`, `#open-problem`,
   `#overview`, `#annotation`, `#example`, `#reference`;
2. **a summary** in a blockquote: the claim of the note in two or three lines;
3. **a sources block**:
   - `> Sources:` the papers with exact definition and theorem numbers, then `code:` the
     Julia files the note describes. A note that is our own analysis says so ("original to
     this vault").
   - `> Lenticulum (vault):` links to the Lenticulum notes the note builds on, and
     `> Theory (CT-ML wiki):` links to the general concepts it uses. Both are ordinary web
     links to the published pages, since they are other vaults.

   Every cited work is collected in [[Bibliography]], generated from `docs/src/refs.bib`;
   new citations go into that file first. `docs/site/link_sources.py` then adds a
   `> Bibliography:` line under each note's sources, linking every recognised work to its entry.

Implementation notes additionally record, as carefully as what the file does, **what it does
not do** and the difficulties met on the way.

Mathematics is written in LaTeX (`$…$`, and `$$` fences **on their own lines**); the website
renders it with KaTeX, and the build refuses notes whose display math would be truncated
(see `docs/site/README.md`). Commutative diagrams are ```` ```tikz ```` blocks, as in
Lenticulum's vault.

**Notation.** A sequence of $L$ tokens over a vocabulary of $V$ symbols is a point
$z \in \mathbb R^{VL}$, one block of $V$ coordinates per position ([[tokens]]). The joint-space
conventions are Lenticulum's: inputs $X$ are clamped, outputs $Y$ solved for, latents $U$ inferred,
$z_0$ is the evidence and $\rho$ the per-coordinate precision.

Links between notes of this vault are `[[wikilinks]]` by note name.

## Reading it

- **On the web**: the vault is rendered with Quartz and deployed beside the API documentation.
- **In Obsidian**: open the repository root as a vault. The *Inline TikZ* community plugin
  renders the diagrams.

## Adding to it

If you implement something, put a markdown file next to the `.jl` file containing the
implementation, with the theory, the implementation, and an extensive description of the
implementation difficulties. A concept that is not specific to language models belongs in
Lenticulum's vault (or, if it is general category theory, in the CT-ML wiki) first, and the note
here links to it.
