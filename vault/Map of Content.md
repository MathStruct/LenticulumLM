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
- [[Incremental Next-Token Prediction]]: an idea. Grow the graph a token at a time (as iSAM does)
  and denoise ahead with noise rising with recency; its precedents and open questions

## 1b. Background

- [[Diffusion Language Models]]: the variants (continuous, uniform, masked, score-based, block) and
  what each offers a relational model
- [[How a Diffusion Language Model Generates]]: the sampler step by step; parallel decoding and its
  price; conditioning as clamping
- [[Meaning as a Relation over Text]]: meaning as a relation between texts and meanings; a
  diffusion model as such a relation; composition by product
- [[Embeddings in a Diffusion Language Model]]: why learned embeddings in the state collapse, why
  drifting per-variable embeddings break a factor graph, and the embedding-free precedent
- [[Factor Graphs against Mixtures of Experts and Agent Chains]]: points against beliefs; a mixture
  of experts as a switch, a product as an overlay, an agent chain as point maps

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
