"""
    LenticulumLM

A diffusion language model assembled from implicit learners. A sequence of tokens is a point
of a joint space, one block of coordinates per position; windows of consecutive positions are
implicit relations ([Lenticulum.jl](https://github.com/MathStruct/Lenticulum.jl)'s diffusion
learners), and the sequence is their product, joined by separators on the overlaps. One model
then answers every query by root finding, whichever tokens are given: continuation, backward
prediction and infilling are the same query with different clamps.

## What is here so far

- `tokens.jl` — [`Vocabulary`](@ref): tokens as scaled one-hot codes, one block of
  coordinates per position; [`encode`](@ref), [`decode`](@ref), and [`sequence_query`](@ref),
  which turns a partly known sequence into clamps.
- `sequence.jl` — [`window_relation`](@ref) (the closed-form relation of an ``n``-gram table),
  [`sequence_relation`](@ref) (windows and separators assembled into one relation), and
  [`token_marginals`](@ref) / [`position_marginals`](@ref) / [`position_beliefs`](@ref) (every
  answer of a query, read as a categorical belief per position).

Exact against an ``n``-gram chain's closed form; learned windows, a discrete learner and scale
are the open part (`Open Problems in Assembling Language Models.md`).
"""
module LenticulumLM

using LinearAlgebra: I
using Random: Xoshiro
using LuxCore: LuxCore
using LenticulumCore: belief_mean, CategoricalBelief
using VariationalDiffusion: VPSDE, NoisePredictor, GaussianMixtureEps, ImplicitDiffusion, ProductRelation,
    field_nodes, density_lambda, implicit_mixture

include("tokens.jl")
include("sequence.jl")

export Vocabulary, nsymbols, codes, block, symbol_index, encode, decode, sequence_query
export window_relation, sequence_relation, position_marginals, position_beliefs, token_marginals

end # module
