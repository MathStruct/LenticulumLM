# # [A language model in every direction: a bigram chain](@id tutorial-bigram)
#
# A language model usually runs one way: given the tokens so far, the next one. A diffusion
# language model such as [nie2025llada](@citet) or [sahoo2024mdlm](@citet) can fill in any masked
# positions, but is one network over the whole sequence. This tutorial assembles a language
# model from **implicit relations** instead, one per window of two positions, and asks it three
# different questions with the same model:
#
# 1. continuation: given the first token, what comes two positions later?
# 2. backward prediction: given the last token, what came first?
# 3. infilling: given the first and the last token, what is in between?
#
# The windows here are the exact relations of a known bigram table, so every answer can be
# checked against the closed form. A learned window would replace them without changing the rest.

using LenticulumLM, LinearAlgebra, Printf

# ## The language
#
# Three symbols and a transition matrix ``T``, with its stationary distribution ``\pi``
# (``\pi T = \pi``): the chain ``p(x_1, \dots, x_L) = \pi(x_1)\prod_k T(x_k, x_{k+1})``.

v = Vocabulary(['a', 'b', 'c'])
T = [0.6 0.3 0.1; 0.2 0.5 0.3; 0.3 0.2 0.5]
e = eigen(Matrix(T'))
π₀ = real.(e.vectors[:, argmax(real.(e.values))]); π₀ ./= sum(π₀)
round.(π₀; digits = 3)

# ## Tokens as coordinates
#
# Each position is a block of three coordinates, and a token is its one-hot code there. A
# sequence of three tokens is a point of ``\mathbb R^9``:

encode(v, ['a', 'c', 'b'])

# ## The model: windows and separators
#
# One relation sees a window of two positions: a diffusion relation whose data are the codes of
# the bigrams ``(a, b)``, weighted by ``\pi(a)T(a, b)``. It is used at every offset. Where two
# windows overlap, a separator (the relation of ``\pi``, with weight ``-1``) keeps the shared
# position from being counted twice:
#
# ```math
# p(x_1, x_2, x_3) = \frac{p_{\mathrm{win}}(x_1, x_2)\,p_{\mathrm{win}}(x_2, x_3)}{p_{\mathrm{sep}}(x_2)} .
# ```

window = window_relation(v, π₀ .* T)
separator = window_relation(v, π₀)
model, ps, st = sequence_relation(v, window, separator, 3)
nothing #hide

# ## Three questions, one model
#
# A query is a sequence with `nothing` at the unknown positions. `token_marginals` finds every
# answer of the query (every completion is a separate stable root of the model's field, with a
# Laplace weight) and reads them per position as categorical distributions.

function show_query(tokens, column, exact)
    pos, P, mix = token_marginals(v, model, ps, st, tokens)
    @printf("%s  position %d: %s   exact: %s   (%d answers)\n", join(something.(tokens, '_')), pos[column],
            string(round.(P[:, column]; digits = 3)), string(round.(exact; digits = 3)), length(mix.components))
end

show_query(['a', nothing, nothing], 2, (T^2)[1, :])                      # continuation: row a of T²
back = π₀ .* (T^2)[:, 3]
show_query([nothing, nothing, 'c'], 1, back ./ sum(back))                 # backward: ∝ π(x₁) T²(x₁, c)
mid = T[1, :] .* T[:, 3]
show_query(['a', nothing, 'c'], 1, mid ./ sum(mid))                       # infilling: ∝ T(a, x₂) T(x₂, c)

# The model was never told which way it would be asked. The direction of each question is
# only which positions are clamped.
#
# ## What this does not show yet
#
# The windows here are exact. A learned window (an energy network trained on the windows of a
# corpus) plugs into `sequence_relation` the same way; training one, and the smoothing bias that
# comes with it, is the next step in the
# [roadmap](https://mathstruct.org/LenticulumLM/Design/Open-Problems-in-Assembling-Language-Models).
# Enumerating every answer is also exponential in the number of unknown positions: a real model
# will pass per-position beliefs between windows instead.

#
# ## References
#
# ```@bibliography
# Pages = [@__FILE__]
# Canonical = false
# ```
