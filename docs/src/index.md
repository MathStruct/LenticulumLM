```@meta
CurrentModule = LenticulumLM
```

# LenticulumLM

A **diffusion language model assembled from implicit learners**. Each part is a relation over a
few token positions, learned or given in closed form; the model is their product; and every
query, whether continuation, backward prediction, infilling or a constrained completion, is
root finding with the known tokens clamped. It builds on
[Lenticulum.jl](https://github.com/MathStruct/Lenticulum.jl), which provides the implicit
learners, their products and their beliefs.

!!! warning "Under development"
    A research prototype. What is here is exact against closed forms; learned windows, a
    discrete learner and scale are open. The roadmap is in the
    [theory vault](@ref theory).

## What is here

- **Tokens as coordinates** ([`Vocabulary`](@ref)): one block of coordinates per position, each
  token a one-hot code; a partly known sequence is a query ([`sequence_query`](@ref)).
- **A model assembled from relations** ([`window_relation`](@ref), [`sequence_relation`](@ref)):
  one relation per window, separators on the overlaps. With the windows of an ``n``-gram chain
  this is that chain exactly.
- **Answers as beliefs** ([`token_marginals`](@ref), [`position_beliefs`](@ref)): every answer
  of a query, read per position as a categorical distribution.

The [tutorial](@ref tutorial-bigram) asks one bigram model three questions in three directions.
