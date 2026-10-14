using LenticulumLM
using LinearAlgebra
using LenticulumCore: probabilities
using Test

# ---------------------------------------------------------------------------
# The reference model: a stationary bigram chain over three symbols,
#
#     p(x_1, …, x_L) = π(x_1) Π_k T(x_k, x_{k+1}),     π T = π,
#
# assembled from one window relation (the bigram table π(a) T(a, b)) and one separator (π).
# Every query has a closed-form answer, which the assembled relation must reproduce without
# being told it: forward, backward and infilling are the same model with different clamps.
# ---------------------------------------------------------------------------
const T = [0.6 0.3 0.1; 0.2 0.5 0.3; 0.3 0.2 0.5]
const π₀ = let e = eigen(Matrix(T')); p = real.(e.vectors[:, argmax(real.(e.values))]); p ./ sum(p) end
const V3 = Vocabulary(['a', 'b', 'c'])
idx(s) = symbol_index(V3, s)

@testset "LenticulumLM" begin

@testset "tokens: codes, blocks, queries" begin
    @test nsymbols(V3) == 3 && codes(V3) == Matrix(1.0I, 3, 3)
    @test block(V3, 2) == 4:6
    @test encode(V3, ['a', 'c']) == [1, 0, 0, 0, 0, 1]
    @test decode(V3, encode(V3, ['b', 'c', 'a'])) == ['b', 'c', 'a']
    @test decode(V3, [0.1, 0.9, 0.2, 0.7, 0.0, 0.3]) == ['b', 'a']
    z₀, ρ = sequence_query(V3, ['a', nothing, 'c'])
    @test z₀ == [1, 0, 0, 0, 0, 0, 0, 0, 1]
    @test ρ[1:3] == fill(Inf, 3) && ρ[4:6] == zeros(3) && ρ[7:9] == fill(Inf, 3)
    @test codes(Vocabulary([1, 2]; scale = 2.0)) == [2.0 0; 0 2.0]
    @test_throws ArgumentError Vocabulary(['a', 'a'])
    @test_throws ArgumentError encode(V3, ['z'])
    @test_throws DimensionMismatch decode(V3, zeros(4))
end

@testset "a bigram chain assembled from implicit learners, queried in every direction" begin
    @test π₀' * T ≈ π₀'
    win = window_relation(V3, π₀ .* T)                        # P[a, b] = π(a) T(a, b)
    sep = window_relation(V3, π₀)
    @test_throws DimensionMismatch window_relation(V3, ones(2, 2))
    rel, ps, st = sequence_relation(V3, win, sep, 3)
    @test length(ps) == 3                                     # two windows, one separator
    @test_throws ArgumentError sequence_relation(V3, win, sep, 1)

    # continuation: x₁ = a, the distribution of x₃ is row a of T²
    pos, P, mix = token_marginals(V3, rel, ps, st, ['a', nothing, nothing])
    @test pos == [2, 3]
    @test length(mix.components) == 9                         # every completion is an answer
    @test P[:, 1] ≈ T[idx('a'), :] atol = 1e-3
    @test P[:, 2] ≈ (T^2)[idx('a'), :] atol = 1e-3
    # backward prediction: x₃ = c, the distribution of x₁ is ∝ π(a) T²(a, c)
    _, Pb, _ = token_marginals(V3, rel, ps, st, [nothing, nothing, 'c'])
    back = π₀ .* (T^2)[:, idx('c')]
    @test Pb[:, 1] ≈ back ./ sum(back) atol = 1e-3
    # infilling: x₁ = a, x₃ = c, the middle is ∝ T(a, b) T(b, c)
    _, Pi, _ = token_marginals(V3, rel, ps, st, ['a', nothing, 'c'])
    mid = T[idx('a'), :] .* T[:, idx('c')]
    @test Pi[:, 1] ≈ mid ./ sum(mid) atol = 1e-3
    @test decode(V3, [1.0, 0, 0, Pi[:, 1]..., 0, 0, 1.0]) == ['a', V3.symbols[argmax(mid)], 'c']
    b = only(position_beliefs(V3, Pi))
    @test probabilities(b) ≈ Pi[:, 1] && b.labels == ['a', 'b', 'c']

    # without separators the inner marginal counts twice: the continuation is off
    rel0, ps0, st0 = sequence_relation(V3, win, nothing, 3)
    _, P0, _ = token_marginals(V3, rel0, ps0, st0, ['a', nothing, nothing])
    @test maximum(abs.(P0[:, 2] .- (T^2)[idx('a'), :])) > 0.01
end

end
