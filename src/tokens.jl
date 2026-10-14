# ---------------------------------------------------------------------------
# Tokens as coordinates. A sequence of L tokens over a vocabulary of V symbols is a point of
# the joint space Z = ℝ^(V·L): position i owns the block of V coordinates
# (i-1)V+1 … iV, and a token is the scaled one-hot code C·e_a in its block. A query clamps
# the blocks of the known tokens and leaves the others free, so one relation answers
# continuation, backward prediction and infilling alike: the polarity is chosen per query.
#
# See `tokens.md`.
# ---------------------------------------------------------------------------

"""
    Vocabulary(symbols; scale = 1.0)

A finite vocabulary and its codes: symbol `a` is the vector ``C\\,e_a \\in \\mathbb R^V``, with
``C`` = `scale`. A sequence of ``L`` tokens is a point of ``\\mathbb R^{VL}``, position ``i``
owning the coordinates [`block`](@ref)`(v, i)`.

```julia
v = Vocabulary(['a', 'b', 'c'])
z = encode(v, ['a', 'c'])            # [1, 0, 0, 0, 0, 1]
decode(v, z)                         # ['a', 'c']
```
"""
struct Vocabulary{T}
    symbols::Vector{T}
    index::Dict{T,Int}
    scale::Float64
    function Vocabulary(symbols::AbstractVector{T}; scale::Real = 1.0) where {T}
        syms = collect(symbols)
        allunique(syms) || throw(ArgumentError("the symbols of a vocabulary must be distinct"))
        isempty(syms) && throw(ArgumentError("a vocabulary needs at least one symbol"))
        scale > 0 || throw(ArgumentError("the code scale must be positive"))
        return new{T}(syms, Dict(s => i for (i, s) in enumerate(syms)), Float64(scale))
    end
end

"""
    nsymbols(v::Vocabulary) -> Int

The number of symbols ``V``, which is also the number of coordinates per position.
"""
nsymbols(v::Vocabulary) = length(v.symbols)

"""
    codes(v::Vocabulary) -> Matrix

The ``V \\times V`` matrix whose column ``a`` is the code of symbol ``a``: ``C`` times the identity.
"""
codes(v::Vocabulary) = Matrix(v.scale * I, nsymbols(v), nsymbols(v))

"""
    block(v::Vocabulary, i) -> UnitRange

The coordinates of position `i` in the joint space.
"""
block(v::Vocabulary, i::Integer) = ((i - 1) * nsymbols(v) + 1):(i * nsymbols(v))

"""
    symbol_index(v::Vocabulary, s) -> Int

The index of symbol `s` (its code is column `symbol_index(v, s)` of [`codes`](@ref)).
"""
function symbol_index(v::Vocabulary, s)
    i = get(v.index, s, 0)
    i == 0 && throw(ArgumentError("symbol $(repr(s)) is not in the vocabulary"))
    return i
end

"""
    encode(v::Vocabulary, tokens) -> Vector{Float64}

The point of ``\\mathbb R^{VL}`` that holds `tokens`, each as its code in its position's block.
An entry `nothing` (an unknown token) leaves its block at zero, the centre of the codes.
"""
function encode(v::Vocabulary, tokens::AbstractVector)
    V = nsymbols(v)
    z = zeros(V * length(tokens))
    for (i, s) in enumerate(tokens)
        s === nothing && continue
        z[block(v, i)[symbol_index(v, s)]] = v.scale
    end
    return z
end

"""
    decode(v::Vocabulary, z) -> Vector

The symbol of each position: the largest coordinate of its block, i.e. the nearest code.
"""
function decode(v::Vocabulary, z::AbstractVector)
    V = nsymbols(v)
    length(z) % V == 0 || throw(DimensionMismatch("a state of length $(length(z)) is not a whole number of blocks of $V"))
    return [v.symbols[argmax(view(z, block(v, i)))] for i in 1:(length(z) ÷ V)]
end

"""
    sequence_query(v::Vocabulary, tokens) -> (z₀, ρ)

The query of a partly known sequence: `tokens` holds a symbol at each known position and
`nothing` at each unknown one. The known positions are clamped (precision ``\\infty``), the
unknown ones free (precision 0), and `z₀` holds the known codes. Pass both to
`implicit_infer`, `implicit_mixture` or [`position_marginals`](@ref).

```julia
z₀, ρ = sequence_query(v, ['a', nothing, 'c'])      # infill the middle
```
"""
function sequence_query(v::Vocabulary, tokens::AbstractVector)
    ρ = zeros(nsymbols(v) * length(tokens))
    for (i, s) in enumerate(tokens)
        s === nothing || (ρ[block(v, i)] .= Inf)
    end
    return encode(v, tokens), ρ
end
