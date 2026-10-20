using Documenter
using DocumenterCitations
using Literate
using SHA: sha1

# --- Tutorials: docs/literate/*.jl → a page and a Jupyter notebook each --------------------
# Each tutorial is executed once by Literate (outputs and plots written into plain Markdown),
# and the result is cached under docs/cache/tutorials, keyed by a hash of the script, the docs
# environment and the source of LenticulumLM. An unchanged tutorial is
# copied from the cache instead of re-run, so the slow ones (they train networks) only run
# when they or the code they exercise change. CI keeps docs/cache between runs
# (.github/workflows/Docs.yml). Set LENTICULUM_RERUN_TUTORIALS=1 to ignore the cache.
# (Lenticulum's own packages come from GitHub and are not hashed: after a change there that a
# tutorial depends on, rerun with the variable set.)
# The notebook is written unexecuted, for download, and linked from the top of the page.
const ROOT = dirname(@__DIR__)
const LITERATE = joinpath(@__DIR__, "literate")
const TUTORIALS = joinpath(@__DIR__, "src", "tutorials")
const CACHE = joinpath(@__DIR__, "cache", "tutorials")
const PKGDIRS = Dict("LenticulumLM" => ROOT)

function sources(dir)
    files = String[]
    for sub in ("src", "ext")
        isdir(joinpath(dir, sub)) || continue
        for (root, _, fs) in walkdir(joinpath(dir, sub)), f in fs
            endswith(f, ".jl") && push!(files, joinpath(root, f))
        end
    end
    return sort(files)
end

# script + docs environment + the source of LenticulumLM
function tutorial_key(script)
    src = read(script, String)
    used = Set(["LenticulumLM"])
    for m in eachmatch(r"^(?:using|import)\s+([^\n]+)"m, src), w in eachmatch(r"\w+", m[1])
        haskey(PKGDIRS, w.match) && push!(used, w.match)
    end
    io = IOBuffer()
    write(io, src, read(joinpath(@__DIR__, "Project.toml")))
    for pkg in sort(collect(used)), f in sources(PKGDIRS[pkg])
        write(io, relpath(f, ROOT), read(f))
    end
    return bytes2hex(sha1(take!(io)))[1:16]
end

# notebooks have no bibliography: [key](@cite) becomes "(key)", and the @bibliography block goes
uncite(s) = replace(replace(s, r"\[([^\]]+)\]\(@cite[tp]?\)" => s"(\1)"),
                    r"^# ```@bibliography\n(?:# .*\n)*?# ```\n"m => "# See the references page of the documentation.\n")

# Literate's plain-Markdown flavour strips Documenter's (@ref) and (@id …) links; protect them
protect(s) = replace(s, "(@" => "(LITERATE-AT-")
restore(s) = replace(s, "(LITERATE-AT-" => "(@")

rm(TUTORIALS; force = true, recursive = true)
mkpath(TUTORIALS)
tutorial_pages = String[]
for file in sort(filter(endswith(".jl"), readdir(LITERATE)))
    name = splitext(file)[1]
    script = joinpath(LITERATE, file)
    badge(content) = replace(content, r"^(# # .*\n)"m =>
        SubstitutionString("\\1#\n#md # [Download as a Jupyter notebook]($(name).ipynb)\n" *
            "#nb # *Setup:* run this in a Julia environment with LenticulumLM and Lenticulum's packages\n" *
            "#nb # (see the README) and the other packages of the first code cell.\n"); count = 1)
    cached = joinpath(CACHE, "$(name)-$(tutorial_key(script))")
    if isdir(cached) && get(ENV, "LENTICULUM_RERUN_TUTORIALS", "0") != "1"
        @info "Tutorial $(name): reusing the cached rendering"
    else
        @info "Tutorial $(name): executing"
        tmp = mktempdir()
        Literate.markdown(script, tmp; flavor = Literate.CommonMarkFlavor(), execute = true,
                          preprocess = protect ∘ badge, postprocess = restore)
        for old in filter(d -> startswith(d, "$(name)-"), isdir(CACHE) ? readdir(CACHE) : String[])
            rm(joinpath(CACHE, old); recursive = true)               # drop stale renderings
        end
        mkpath(dirname(cached))
        mv(tmp, cached; force = true)
    end
    foreach(f -> cp(joinpath(cached, f), joinpath(TUTORIALS, f); force = true), readdir(cached))
    Literate.notebook(script, TUTORIALS; execute = false, preprocess = uncite)
    push!(tutorial_pages, "tutorials/$(name).md")
end

using LenticulumLM

# The site is mathstruct.org/LenticulumLM: the vault is its front page, and this API
# documentation lives under api/ (deploydocs' `dirname`), api/dev/ for master. The pages link to
# the vault through LENTICULUMLM_VAULT_URL.
const SITE = "https://mathstruct.org/LenticulumLM"
const VAULT_URL = "$(SITE)/"
const API_URL = "$(SITE)/api/dev/"
ENV["LENTICULUMLM_VAULT_URL"] = VAULT_URL

# One bibliography for the docs and the vault (docs/site/bib2vault.py renders it there)
const BIB = CitationBibliography(joinpath(@__DIR__, "src", "refs.bib"); style = :authoryear)

makedocs(;
    plugins = [BIB],
    sitename = "LenticulumLM",
    authors = "Daniel Boigk",
    modules = [LenticulumLM],
    format = Documenter.HTML(;
        canonical = "https://mathstruct.org/LenticulumLM/api/dev",
        edit_link = "master",
        assets = String[],
    ),
    pages = [
        "Home" => "index.md",
        "Getting started" => "getting-started.md",
        "Tutorials" => tutorial_pages,
        "Theory vault" => "theory.md",
        "References" => "references.md",
        "API" => "packages/lenticulumlm.md",
    ],
    # Docstrings cite the Obsidian vault with [[wiki links]] and reference notes that are not
    # part of this site. Those are deliberate: the theory lives in `vault/`, not here.
    checkdocs = :exports,
    warnonly = [:missing_docs, :cross_references],
)

# --- The Obsidian vault, rendered with Quartz, at the front of the site -------------------
# `docs/site/build.sh` builds the vault into docs/vault-build/, outside docs/build/, so that
# deploydocs does not ship a second copy of it; the Docs workflow deploys it to the site's root
# (docs/site/deploy_vault.sh), which also turns the old dev/ addresses into redirects. It needs
# Node ≥ 22; without `npx` the API docs build alone.
let script = joinpath(@__DIR__, "site", "build.sh")
    if Sys.which("npx") === nothing
        @warn "npx not found — skipping the theory vault (docs/site/build.sh). The API docs are unaffected."
    else
        @info "Building the theory vault with Quartz"
        withenv("VAULT_BASEURL" => "mathstruct.org/LenticulumLM", "VAULT_API_URL" => API_URL) do
            run(`$script`)
        end
    end
end

deploydocs(;
    repo = "github.com/MathStruct/LenticulumLM",
    dirname = "api",
    devbranch = "master",
)
