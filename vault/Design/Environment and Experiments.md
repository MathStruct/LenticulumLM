#design

> **How the repository is meant to grow.** LenticulumLM is a workspace for experiments, not a
> library to install. A Nix flake sets up every tool they need, in shells. The Julia code in
> `src/` is the toolkit the experiments share, each experiment lives in its own directory with
> its own environment, and large files (corpora, teacher models, checkpoints) live outside the
> repository, pinned by a manifest and published to Hugging Face when they are worth sharing.
> This note is the plan; only the flake and the toolkit exist so far.

> Sources: original to this vault (design); code: `flake.nix`

## 1. What the flake does

`flake.nix` builds no package. It provides development shells, all with the same base:

| shell | adds | for |
|---|---|---|
| `nix develop` | Julia (the host's, else the flake's 1.12), git, git-lfs, jq, Node 22, Python with `huggingface_hub` (the `hf` CLI) | the experiments, the docs and vault build, moving data and checkpoints |
| `nix develop .#gpu` | the host's NVIDIA driver libraries, made visible to CUDA.jl | training on a GPU on a non-NixOS host |
| `nix develop .#lean` | elan | Lean 4 and Mathlib |
| `nix develop .#metamath` | metamath | `set.mm` and its proofs |
| `nix develop .#isabelle` | Isabelle | the Archive of Formal Proofs |
| `nix develop .#provers` | all three provers | |

Every shell sets `LENTICULUMLM_ROOT`, makes the repository the Julia project, and points
`LENTICULUMLM_DATA` and `LENTICULUMLM_MODELS` at `~/.cache/lenticulum/lm/{data,models}`, next to
Lenticulum's logs and models. Set them before entering to put the files elsewhere.

Some choices and their reasons:

- **The host's Julia first.** A `julia` already on the PATH (juliaup's launcher, say) is used as
  it is, so the shell adds nothing to a machine that has one; it warns below 1.11. Only without
  one does the shell use the flake's Julia (`nix build .#julia`), built on first entry. That is
  nixpkgs' 1.12 (`julia_112-bin`, 1.12.7) rather than its default 1.13: it is not in the binary
  cache, and its build runs Julia's whole test suite, more than twenty minutes, so the flake
  switches the check off and the build takes ten seconds. Julia packages are pinned by each
  project's `Manifest.toml` through Pkg, not by Nix, and the shared `~/.julia` depot serves
  both Julias. A manifest resolved under one minor version needs `Pkg.instantiate()` under the
  next, for its artifacts (the MNIST environment of Lenticulum, resolved under 1.12, misses
  LLVMExtra's 1.13 artifact).
- **elan, not a Lean toolchain**: every Lean project pins its toolchain in a `lean-toolchain`
  file, and elan fetches it; Mathlib's compiled cache comes from `lake exe cache get`. Putting
  a toolchain in Nix would pin it twice. The same holds for Mathlib.
- **The GPU shell links only the driver's libraries** (`libcuda`, `libnvidia-*`) into a private
  directory. Putting the host's `/usr/lib` on `LD_LIBRARY_PATH` would mix the host's C library
  into the shell. CUDA.jl brings its own CUDA toolkit as Julia artifacts; it needs only the
  driver. It matters for the flake's Julia, which does not search the host's library paths:
  with it, CUDA.jl is functional in `.#gpu` (RTX 3080) and not in the default shell. The host's
  own Julia finds the driver either way. On NixOS the driver is at `/run/opengl-driver` and
  nothing is linked.

## 2. Layout as it grows

| where | what | tracked |
|---|---|---|
| `src/`, `test/` | the shared toolkit (`LenticulumLM`) with its notes and tests | yes |
| `experiments/NN-name/` | one experiment: its own `Project.toml` (the toolkit by path, Lenticulum from GitHub), scripts, and a note `NN-name.md` with what was run and what came out | yes |
| `experiments/NN-name/Manifest.toml` | the exact package versions of a run | yes, for experiments (see §5) |
| `data/manifest.toml` | every corpus, teacher model and checkpoint an experiment uses: where it comes from, its revision or hash, its licence | yes |
| `$LENTICULUMLM_DATA`, `$LENTICULUMLM_MODELS` | the files themselves | no |
| `vault/` | design notes, the roadmap, and a note per experiment's findings | yes |

An experiment's note follows the implementation-note practice: what it set out to measure,
what it measured, what did not work. Its numbers go into the vault when they change a
conclusion, as the MNIST notes do in Lenticulum.

## 3. Large files: data, teacher models, checkpoints

**Pinned by a manifest, not by Nix.** Corpora and models are gigabytes. Nix's fixed-output
derivations would pin them by hash, but would also copy them into the store and keep them
there per version. Instead `data/manifest.toml` lists each file or repository with its source
and an exact revision:

```toml
[datasets.tinystories]
source = "hf:roneneldan/TinyStories"
revision = "<commit sha>"
licence = "CDLA-Sharing-1.0"
path = "tinystories"                     # under $LENTICULUMLM_DATA
```

A fetch script (Julia, or `hf download --revision`) reads it and fills `$LENTICULUMLM_DATA`;
a check verifies hashes. Small, stable inputs (a single `set.mm`, a word list) may still be
fixed-output derivations, where the store copy costs nothing.

**Published to Hugging Face.** Checkpoints worth keeping (`.jld2` files of trained windows,
distilled relations) go to a Hugging Face repository under the MathStruct organisation, with a
model card that names the experiment, the commit of this repository that produced it, and the
data it saw. `hf upload` and `hf download` are in every shell; `.jld2` is a binary file and is
stored with Git LFS on the Hugging Face side, never in this repository. Whether Julia's JLD2 is
the right exchange format (versus safetensors, which Python tools read) is a decision to make
when the first checkpoint is published.

## 4. What is planned, and what each needs

| addition | shell | data | open questions |
|---|---|---|---|
| **learned windows on a character corpus** (roadmap L2) | default, gpu | a small text corpus (TinyStories, text8) | the corpus and window size; the training budget |
| **a teacher model to distil** (roadmap L8) | a Python shell (§5) | a small open-weight model, e.g. a TinyStories model, Pythia-70M or SmolLM2-135M, or a small masked diffusion LM | which teacher; what is distilled (logits, hidden states, or relations between positions) |
| **formal mathematics as a corpus** | lean, metamath, isabelle | Mathlib, `set.mm`, the Archive of Formal Proofs | whether proofs are text to model or relations to learn (a proof step as a relation between goals) |
| **checkpoints on Hugging Face** | default | the experiments' outputs | format (§3), naming, licences of what they were trained on |

## 5. Decisions still open

- **A Python shell for teacher models.** Running a pretrained model means PyTorch and
  `transformers`. In Nix that is `python3Packages.torch` (with CUDA, unfree and a long build)
  or a `uv`-managed environment inside a shell, which is quicker but pinned by its own lock file
  rather than by the flake. The likely split: Python extracts what the teacher computes
  (logits, activations) into files; Julia trains the relations on them.
- **Experiment manifests.** Lenticulum.jl ignores every `Manifest.toml`, which suits libraries.
  An experiment's result should be reproducible, so experiments are proposed to commit theirs.
- **The Lenticulum version.** `Project.toml` takes Lenticulum from its `master` branch; an
  experiment's committed manifest pins the exact commit, which is enough. Pinning a tag in
  `[sources]` becomes worth it once Lenticulum has releases.
- **macOS and CUDA.** The shells are declared for `aarch64-darwin` too, without the GPU shell's
  driver handling; only `x86_64-linux` has been entered so far (Arch Linux, with and without a
  host Julia).

Related: [[Assembling a Language Model from Implicit Learners]],
[[Open Problems in Assembling Language Models]], [[Start Here]]
