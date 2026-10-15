# LenticulumLM

[![CI](https://github.com/MathStruct/LenticulumLM/actions/workflows/CI.yml/badge.svg?branch=master)](https://github.com/MathStruct/LenticulumLM/actions/workflows/CI.yml?query=branch%3Amaster)
[![Docs](https://github.com/MathStruct/LenticulumLM/actions/workflows/Docs.yml/badge.svg?branch=master)](https://MathStruct.github.io/LenticulumLM/dev/)

**A diffusion language model assembled from implicit learners.** A language model is usually
one network that runs one way. LenticulumLM builds one from parts: each part is a *relation*
over a few token positions, the model is their product, and every query is answered by root
finding with the known tokens clamped. Continuation, backward prediction and infilling are the
same model asked with different clamps.

It builds on [Lenticulum.jl](https://github.com/MathStruct/Lenticulum.jl), which provides the
implicit learners (diffusion models read as relations), their products, and their beliefs.

> **Status: research prototype.** Julia, not registered, one author. What is here is exact
> against closed forms; learned windows, a discrete learner and scale are open
> ([roadmap](vault/Design/Open%20Problems%20in%20Assembling%20Language%20Models.md)).

## The idea

Text of $L$ tokens over a vocabulary of $V$ symbols is a point of $\mathbb R^{VL}$, one block
of coordinates per position, each token its one-hot code. A relation on a window of $n$
positions is an implicit learner on $nV$ coordinates. Windows at every offset, joined by
separators on their overlaps,

$$
p(x_1, \dots, x_L) = \frac{\prod_k p_{\mathrm{win}}(x_k, \dots, x_{k+n-1})}{\prod_k p_{\mathrm{sep}}(x_{k+1}, \dots, x_{k+n-1})},
$$

are an $n$-gram model when the windows are its $n$-gram marginals, and a query clamps whatever
is known:

| query | clamped | answered |
|---|---|---|
| continuation | the first tokens | the distribution of each later position |
| backward prediction | the last tokens | the distribution of each earlier position |
| infilling | both ends | the middle |

Every answer of a query is a stable root of the model's field, with a Laplace weight, and the
roots read per position are categorical beliefs.

## A minimal example

```julia
using LenticulumLM
v = Vocabulary(['x', 'y'])
T = [0.9 0.1; 0.4 0.6]                     # a bigram chain, stationary π = (0.8, 0.2)
π₀ = [0.8, 0.2]
model, ps, st = sequence_relation(v, window_relation(v, π₀ .* T), window_relation(v, π₀), 3)
pos, P, _ = token_marginals(v, model, ps, st, ['x', nothing, 'y'])    # fill in the middle
P                                           # (0.6, 0.4) = T(x, ·) .* T(·, y), normalised
```

On a three-symbol chain, continuation, backward prediction and infilling all agree with the
closed form to $10^{-4}$, with every completion found as its own answer
([`src/sequence.md`](src/sequence.md) §3).

## Layout

The repository mirrors Lenticulum.jl's:

| where | what |
|---|---|
| `src/` | the package; an implementation note (`.md`) beside each `.jl` file |
| `test/` | the test suite, against closed forms |
| `vault/` | the Obsidian vault: design, roadmap, bibliography ([Start Here](vault/Start%20Here.md)) |
| `docs/` | Documenter pages, Literate tutorials, and the Quartz build of the vault (`docs/site/`) |
| `flake.nix` | the development shells: every tool the experiments need |
| `experiments/` | one directory per experiment, each with its own environment (planned) |

## Setting up

LenticulumLM is a workspace for experiments rather than a library to install. The Nix flake
sets up everything: Julia (yours if it is on the PATH, else its own 1.12), the docs toolchain,
the Hugging Face CLI, and on request Lean, Metamath or Isabelle
([plan](vault/Design/Environment%20and%20Experiments.md)):

```sh
nix develop               # Julia, Node, Python with the hf CLI, git-lfs
nix develop .#gpu         # the same, with the host's NVIDIA driver visible to CUDA.jl
nix develop .#lean        # + elan; also .#metamath, .#isabelle, .#provers
```

Data and checkpoints live outside the repository, in `$LENTICULUMLM_DATA` and
`$LENTICULUMLM_MODELS` (default `~/.cache/lenticulum/lm/`). With direnv, `.envrc` enters the
default shell on `cd`.

### Without Nix

Neither LenticulumLM nor Lenticulum.jl is registered. `Project.toml` takes Lenticulum's
packages from GitHub, so a clone instantiates on its own:

```julia
using Pkg
Pkg.activate("path/to/LenticulumLM")
Pkg.instantiate()
Pkg.test()
```

### Developing against a local Lenticulum

To change both repositories at once, develop the local Lenticulum packages into the
environment. This overrides the GitHub sources in the (untracked) manifest:

```julia
Pkg.develop([PackageSpec(path = "../Lenticulum.jl"),
             PackageSpec(path = "../Lenticulum.jl/lib/LenticulumCore.jl"),
             PackageSpec(path = "../Lenticulum.jl/lib/Mycelium.jl"),
             PackageSpec(path = "../Lenticulum.jl/lib/VariationalDiffusion.jl")])
```

## Reading the theory

- The **vault**, on the web beside the [documentation](https://MathStruct.github.io/LenticulumLM/dev/),
  or in Obsidian: open the repository root and start at `vault/Start Here.md`.
- **Lenticulum's vault**, for the implicit learners themselves:
  [mathstruct.org/Lenticulum.jl](https://mathstruct.org/Lenticulum.jl/).
- The **CT-ML wiki**, for the general category theory both build on:
  [mathstruct.org/CategoryTheory-ML-Wiki](https://mathstruct.org/CategoryTheory-ML-Wiki/).

## License

MIT, see [LICENSE](LICENSE).
