{
  # LenticulumLM is a workspace for experiments, not a library to install: this flake does not
  # build a package. It sets up the tools every experiment needs, in shells:
  #
  #   nix develop              Julia, the docs toolchain (Node, Python), git-lfs, the
  #                            Hugging Face CLI: run the experiments, build the docs and vault,
  #                            move data and checkpoints
  #   nix develop .#gpu        the same, with the host's NVIDIA driver libraries visible to
  #                            CUDA.jl (on a non-NixOS host)
  #   nix develop .#lean       + elan (Lean toolchains are fetched per project by elan)
  #   nix develop .#metamath   + metamath
  #   nix develop .#isabelle   + Isabelle (large)
  #   nix develop .#provers    + all three provers
  #
  # Julia: a `julia` already on the PATH (e.g. from juliaup) is used as it is. Only without one
  # does the shell build and use this flake's Julia 1.12 (`nix build .#julia`), on first entry.
  #
  # Every shell sets LENTICULUMLM_ROOT, the Julia project, and where data and checkpoints live
  # (outside the repository, see vault/Design/Environment and Experiments.md).
  description = "LenticulumLM: experiments assembling diffusion language models from implicit learners";

  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

  outputs = { self, nixpkgs }:
    let
      systems = [ "x86_64-linux" "aarch64-linux" "aarch64-darwin" ];
      forAllSystems = f: nixpkgs.lib.genAttrs systems (system: f nixpkgs.legacyPackages.${system});
    in
    {
      # Julia 1.12, as Lenticulum.jl is tested with (nixpkgs' julia-bin is already 1.13). Not in
      # the binary cache, so it is built locally, and its install check runs Julia's whole test
      # suite (twenty minutes and more): switched off.
      packages = forAllSystems (pkgs: {
        julia = pkgs.julia_112-bin.overrideAttrs (_: { doInstallCheck = false; });
      });

      devShells = forAllSystems (pkgs:
        let
          base = [
            pkgs.git
            pkgs.git-lfs
            pkgs.jq
            pkgs.nodejs_22 # the Quartz build of the vault (docs/site/build.sh)
            (pkgs.python3.withPackages (ps: [ ps.huggingface-hub ])) # bib scripts; the `hf` CLI
          ];

          # Large files stay outside the repository, beside Lenticulum's logs and models in
          # ~/.cache/lenticulum; set the variables before entering the shell to move them.
          # the host's Julia if there is one, else this flake's (built only when needed)
          juliaHook = ''
            if command -v julia >/dev/null 2>&1; then
              v="$(julia --startup-file=no -e 'print(VERSION >= v"1.11" ? "" : VERSION)' 2>/dev/null)"
              [ -n "$v" ] && echo "warning: the Julia on the PATH is $v; LenticulumLM needs 1.11 or later" >&2
            else
              echo "no Julia on the PATH: using the flake's (built on first use)" >&2
              jl="$(nix build --no-link --print-out-paths "$LENTICULUMLM_ROOT#julia")" && export PATH="$jl/bin:$PATH"
            fi
          '';

          env = ''
            export LENTICULUMLM_ROOT="$PWD"
            export JULIA_PROJECT="$PWD"
            export LENTICULUMLM_CACHE="''${LENTICULUMLM_CACHE:-$HOME/.cache/lenticulum/lm}"
            export LENTICULUMLM_DATA="''${LENTICULUMLM_DATA:-$LENTICULUMLM_CACHE/data}"
            export LENTICULUMLM_MODELS="''${LENTICULUMLM_MODELS:-$LENTICULUMLM_CACHE/models}"
            mkdir -p "$LENTICULUMLM_DATA" "$LENTICULUMLM_MODELS"
          '';

          shell = { name, extra ? [ ], hook ? "" }: pkgs.mkShell {
            inherit name;
            packages = base ++ extra;
            shellHook = env + juliaHook + hook + ''
              echo "LenticulumLM (${name}): $(julia --version) at $(command -v julia), data in $LENTICULUMLM_DATA, checkpoints in $LENTICULUMLM_MODELS"
            '';
          };

          # On a non-NixOS host the NVIDIA driver lives in the host's /usr/lib. Putting that
          # directory on LD_LIBRARY_PATH would mix the host's glibc into the shell, so only the
          # driver's own libraries are linked into a private directory and that is exposed.
          gpuHook = ''
            if [ ! -e /run/opengl-driver/lib/libcuda.so.1 ]; then
              drv="$LENTICULUMLM_CACHE/driver-libs"
              mkdir -p "$drv"
              for d in ''${LENTICULUMLM_DRIVER_DIR:-/usr/lib /usr/lib64 /usr/lib/x86_64-linux-gnu}; do
                for f in "$d"/libcuda.so* "$d"/libnvidia-*.so* "$d"/libnvidia-ml.so*; do
                  [ -e "$f" ] && ln -sf "$f" "$drv/"
                done
              done
              export LD_LIBRARY_PATH="$drv''${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}"
            fi
          '';
        in
        {
          default = shell { name = "default"; };
          gpu = shell { name = "gpu"; hook = gpuHook; };
          lean = shell { name = "lean"; extra = [ pkgs.elan ]; };
          metamath = shell { name = "metamath"; extra = [ pkgs.metamath ]; };
          isabelle = shell { name = "isabelle"; extra = [ pkgs.isabelle ]; };
          provers = shell { name = "provers"; extra = [ pkgs.elan pkgs.metamath pkgs.isabelle ]; };
        });

      formatter = forAllSystems (pkgs: pkgs.nixfmt-rfc-style);
    };
}
