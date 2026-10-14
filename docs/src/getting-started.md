# [Getting started](@id getting-started)

## Install

LenticulumLM is not registered, and neither is Lenticulum.jl, which it depends on. Its
`Project.toml` takes Lenticulum's packages from GitHub, so a clone instantiates on its own:

```julia
using Pkg
Pkg.activate("/path/to/LenticulumLM")
Pkg.instantiate()
```

To work against a local checkout of Lenticulum.jl instead (to change both at once), develop
its packages into the environment; this replaces the GitHub sources in the (untracked) manifest:

```julia
Pkg.develop([PackageSpec(path = "/path/to/Lenticulum.jl"),
             PackageSpec(path = "/path/to/Lenticulum.jl/lib/LenticulumCore.jl"),
             PackageSpec(path = "/path/to/Lenticulum.jl/lib/Mycelium.jl"),
             PackageSpec(path = "/path/to/Lenticulum.jl/lib/VariationalDiffusion.jl")])
```

## A first query

A bigram model over two symbols, assembled from two window relations and a separator, asked
what lies between a known first and last token:

```julia
using LenticulumLM
v = Vocabulary(['x', 'y'])
T = [0.9 0.1; 0.4 0.6]                     # transition matrix, stationary π = (0.8, 0.2)
π₀ = [0.8, 0.2]
model, ps, st = sequence_relation(v, window_relation(v, π₀ .* T), window_relation(v, π₀), 3)
pos, P, _ = token_marginals(v, model, ps, st, ['x', nothing, 'y'])
P                                          # ∝ T(x, ·) .* T(·, y) = (0.09, 0.06) / 0.15
```

## Where to go next

- The [tutorial](@ref tutorial-bigram): one model, three query directions, checked against the
  closed form.
- The [theory vault](@ref theory): the design, the implementation notes and the roadmap.
