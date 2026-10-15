# AGENTS.md

Instructions for AI coding agents working in this repository. It follows the practices of
[Lenticulum.jl](https://github.com/MathStruct/Lenticulum.jl), whose
[AGENTS.md](https://github.com/MathStruct/Lenticulum.jl/blob/master/AGENTS.md) applies here too;
what differs is below.

## Read this first

The author moved fast and did not check everything. The code and notes were written quickly,
much of it with AI agents, and not all of it has been reviewed by a person. Treat a claim in a
note as unverified unless a test or a measurement backs it; fix or flag what you find wrong;
label anything you have not checked.

Development happens directly on `master` for now. Do not commit or push unless asked.

## What this repository is

A workspace for experiments that assemble diffusion language models from Lenticulum's implicit
learners, not a library for others to install. `vault/Design/Environment and Experiments.md` is
the plan; `vault/Design/Open Problems in Assembling Language Models.md` is the roadmap.

| where | what |
|---|---|
| `flake.nix` | the development shells: `nix develop` (Julia, docs toolchain, `hf`), `.#gpu`, `.#lean`, `.#metamath`, `.#isabelle`, `.#provers` |
| `src/`, `test/` | the toolkit the experiments share (`LenticulumLM`), an implementation note beside each file |
| `experiments/NN-name/` | one experiment each, with its own environment and a note on what it found (planned) |
| `vault/` | design notes and the roadmap |
| `$LENTICULUMLM_DATA`, `$LENTICULUMLM_MODELS` | corpora, teacher models and checkpoints, outside the repository (default `~/.cache/lenticulum/lm/`) |

## Working conventions

- Enter a shell first: `nix develop`. It uses the Julia on the PATH if there is one.
- Tests: `julia --project=. -e 'using Pkg; Pkg.test()'`. They compare against closed forms.
- Lenticulum's packages come from GitHub through `[sources]`. A change that belongs in
  Lenticulum (an implicit learner, a product, a belief type) is made there, not copied here; to
  work on both at once, develop the local checkout into the environment (README).
- Never commit data, models or checkpoints. Record what an experiment uses in
  `data/manifest.toml` (source, revision, licence) once it exists.
- Notes, citations and the docs build follow Lenticulum's conventions (`vault/Start Here.md`):
  `docs/src/refs.bib` first, then `docs/site/link_sources.py` and `docs/site/bib2vault.py`;
  `docs/site/build.sh` must pass.
