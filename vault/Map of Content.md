#overview

> Every note of the LenticulumLM vault, in reading order. How the vault is organised and what
> its conventions are: [[Start Here]]. The implicit learners, products and beliefs this builds
> on are explained in [Lenticulum's vault](https://mathstruct.org/Lenticulum.jl/), and the
> general category theory in the [CT-ML wiki](https://mathstruct.org/CategoryTheory-ML-Wiki/);
> links to both are ordinary web links, links within this vault are wikilinks.

## 1. The idea

- [[Assembling a Language Model from Implicit Learners]]: a language model whose parts are
  relations over token positions, assembled by product; what is built, and the decisions ahead
- [[README]]: the project pitch
- [[Environment and Experiments]]: the Nix shells, the layout experiments will take, and where
  data, teacher models and checkpoints live

## 2. Implementation

- [[tokens]]: tokens as one-hot codes, one block of coordinates per position; queries as clamps
- [[sequence]]: windows and separators assembled into one relation; an $n$-gram chain, exact in
  every query direction

## 3. Verdict

- [[Open Problems in Assembling Language Models]]: the roadmap, from the closed-form chain to
  learned, scalable, long-range models

## Orientation

- [[Start Here]]: conventions
- [[Bibliography]]: every cited work
- Lenticulum's [Language Models](https://mathstruct.org/Lenticulum.jl/Applications/Language-Models)
  note: products of diffusion language models, and why the graph only pays off when it has structure
