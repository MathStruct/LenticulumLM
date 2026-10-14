# ---------------------------------------------------------------------------
# A language model assembled from implicit learners. Each window of n consecutive positions
# is one implicit relation; windows that overlap are joined by a separator on the overlap,
#
#     p(x_1, …, x_L) = Π_k p_win(x_k, …, x_{k+n-1}) / Π_k p_sep(x_{k+1}, …, x_{k+n-1}),
#
# which is exactly an (n-1)-th order Markov chain when the windows are its n-gram marginals.
# One relation then answers every query: continuation, backward prediction, infilling. The
# answers of a query are its stable roots; read per position they are categorical beliefs.
#
# See `sequence.md`.
# ---------------------------------------------------------------------------

"""
    window_relation(v::Vocabulary, P; s = 0.05, schedule = VPSDE(), nodes = nothing) -> (relation, ps, st)

The closed-form implicit relation of an ``n``-gram table: `P` is an ``n``-dimensional array of
size ``V \\times \\cdots \\times V`` whose entry `P[a₁, …, aₙ]` is the probability of the window
``(a_1, \\dots, a_n)``. The relation is a `GaussianMixtureEps` with one component of width `s` at
the codes of every window with positive probability, weighted by it. It is the relation a
diffusion model trained on these windows would converge to, with every derivative in closed
form. `nodes` default to `field_nodes` with 8 antithetic pairs per level; the field is scaled by
`density_lambda`, so its energy is a calibrated negative log-density.
"""
function window_relation(v::Vocabulary, P::AbstractArray; s::Real = 0.05, schedule = VPSDE(), nodes = nothing)
    V, n = nsymbols(v), ndims(P)
    all(==(V), size(P)) || throw(DimensionMismatch("an n-gram table over $V symbols has size $V × … × $V, got $(size(P))"))
    all(≥(0), P) && sum(P) > 0 || throw(ArgumentError("an n-gram table holds nonnegative probabilities, not all zero"))
    keep = [I for I in CartesianIndices(P) if P[I] > 0]
    C = codes(v)
    μ = reduce(hcat, [reduce(vcat, [C[:, I[j]] for j in 1:n]) for I in keep])
    w = Float64[P[I] for I in keep]
    nodes === nothing && (nodes = field_nodes(Xoshiro(1), n * V; samples = 8))
    pred = NoisePredictor(GaussianMixtureEps(schedule, μ; s, weights = w ./ sum(w)), schedule)
    ps, st = LuxCore.setup(Xoshiro(0), pred)
    return ImplicitDiffusion(pred, nodes; λ = density_lambda(schedule, nodes)), ps, st
end

"""
    sequence_relation(v::Vocabulary, window, separator, L) -> (relation, ps, st)

The relation of a sequence of `L` tokens assembled from one window relation, applied at every
offset (shared parameters, as a stationary model shares them), and one separator on every
overlap of two consecutive windows, with weight ``-1``:

```math
p(x_1, \\dots, x_L) = \\frac{\\prod_{k=1}^{L-n+1} p_{\\mathrm{win}}(x_k, \\dots, x_{k+n-1})}
                           {\\prod_{k=2}^{L-n+1} p_{\\mathrm{sep}}(x_k, \\dots, x_{k+n-2})} .
```

`window` and `separator` are `(relation, ps, st)` triples, e.g. from [`window_relation`](@ref)
of an ``n``-gram table and of its ``(n-1)``-gram marginal. `separator = nothing` leaves the
separators out (and so counts each overlap's marginal once per window that covers it). The
result is a `ProductRelation` with its parameter and state tuples.
"""
function sequence_relation(v::Vocabulary, window, separator, L::Integer)
    V = nsymbols(v)
    wrel, wps, wst = window
    nw = size(wrel.nodes.ε, 1)
    nw % V == 0 || throw(DimensionMismatch("the window relation has $nw coordinates, not a whole number of positions of $V"))
    n = nw ÷ V
    L ≥ n || throw(ArgumentError("a sequence of $L tokens is shorter than the window ($n)"))
    pos(ks) = reduce(vcat, [collect(block(v, k)) for k in ks])
    parts = Any[wrel => pos(k:(k + n - 1)) for k in 1:(L - n + 1)]
    ps, st = Any[wps for _ in parts], Any[wst for _ in parts]
    weights = ones(length(parts))
    if separator !== nothing && n > 1
        srel, sps, sst = separator
        size(srel.nodes.ε, 1) == (n - 1) * V ||
            throw(DimensionMismatch("the separator must cover the $(n - 1) positions two windows share"))
        for k in 2:(L - n + 1)
            push!(parts, srel => pos(k:(k + n - 2))); push!(ps, sps); push!(st, sst); push!(weights, -1)
        end
    end
    return ProductRelation(parts...; weights, dim = L * V), Tuple(ps), Tuple(st)
end

"""
    position_marginals(v::Vocabulary, mix, ρ) -> (positions, P)

The answers of a sequence query read per position: `mix` is the `MixtureBelief` of
`implicit_mixture` over the free coordinates (its default), `ρ` the query's precisions. Each
answer is decoded to its nearest codes, and its weight is added to the symbol it gives at every
free position. Returns the free `positions` and a ``V \\times`` (number of free positions) matrix
`P` whose columns are categorical distributions.
"""
function position_marginals(v::Vocabulary, mix, ρ::AbstractVector)
    V = nsymbols(v)
    L = length(ρ) ÷ V
    positions = [i for i in 1:L if !all(isinf, ρ[block(v, i)])]
    w = exp.(mix.logw .- maximum(mix.logw))
    w ./= sum(w)
    P = zeros(V, length(positions))
    for (c, wc) in zip(mix.components, w)
        m = belief_mean(c)
        for j in eachindex(positions)
            P[argmax(view(m, ((j - 1) * V + 1):(j * V))), j] += wc
        end
    end
    return positions, P
end

"""
    position_beliefs(v::Vocabulary, P) -> Vector{CategoricalBelief}

The columns of [`position_marginals`](@ref)' matrix as LenticulumCore `CategoricalBelief`s
labelled with the vocabulary's symbols: the per-position beliefs a factor graph passes along.
"""
position_beliefs(v::Vocabulary, P::AbstractMatrix) = [CategoricalBelief(c; labels = v.symbols) for c in eachcol(P)]

"""
    token_marginals(v::Vocabulary, relation, ps, st, tokens; nstarts = 16V^u, spread = 1.0, kwargs...)
        -> (positions, P, mix)

Answer a partly known sequence: `tokens` holds a symbol or `nothing` at each position
([`sequence_query`](@ref)). Every answer of the query is found by `implicit_mixture` (from
`nstarts` starts, by default 16 per possible completion of the ``u`` unknown positions; `kwargs`
go to it) and read per position by [`position_marginals`](@ref). The same relation answers a
continuation (`[a, b, nothing]`), a backward prediction (`[nothing, b, c]`) and an infilling
(`[a, nothing, c]`).
"""
function token_marginals(v::Vocabulary, relation, ps, st, tokens::AbstractVector;
                         nstarts::Integer = 16 * nsymbols(v)^count(isnothing, tokens), spread = 1.0, kwargs...)
    z₀, ρ = sequence_query(v, tokens)
    mix, _ = implicit_mixture(relation, z₀, ρ, ps, st; nstarts, spread, kwargs...)
    positions, P = position_marginals(v, mix, ρ)
    return positions, P, mix
end
