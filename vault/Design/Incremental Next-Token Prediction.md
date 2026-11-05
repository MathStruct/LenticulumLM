#design

> **Status: an idea (2026-11-05, Daniel; written up by Claude), not a design yet.** Next-token
> prediction as incremental inference: each new token appends factors to the graph, as iSAM appends
> measurements. A proximal diffusion solve then denoises the positions ahead, with a noise level
> that falls with a position's age (the past nearly clean, the future noisy). The parts this would
> use exist in Lenticulum; how they would work together, and whether the denoisers must be trained
> for it, is open.

> Sources: Kaess et al., *iSAM2: Incremental Smoothing and Mapping Using the Bayes Tree*, IJRR 31(2), 2012; Wu et al., *AR-Diffusion: Auto-Regressive Diffusion Model for Text Generation*, 2023; Ruhe, Heek, Salimans & Hoogeboom, *Rolling Diffusion Models*, 2024; Chen et al., *Diffusion Forcing: Next-token Prediction Meets Full-Sequence Diffusion*, 2024; Fang, Díaz, Buchanan & Sulam, *Beyond Scores: Proximal Diffusion Models* (ProxDM), 2025. The proposal is original to this vault; nothing here is measured.
>
> Bibliography: [[Bibliography#^kaess2012isam2|Kaess et al. 2012]] · [[Bibliography#^wu2023ardiffusion|Wu et al. 2023]] · [[Bibliography#^ruhe2024rolling|Ruhe et al. 2024]] · [[Bibliography#^chen2024forcing|Chen et al. 2024]] · [[Bibliography#^fang2025proxdm|Fang et al. 2025]]
>
> Lenticulum (vault): [ProxDM and Proximal Alternatives](https://mathstruct.org/Lenticulum.jl/Families/Diffusion/ProxDM-and-Proximal-Alternatives) · [Implicit Diffusion Learners](https://mathstruct.org/Lenticulum.jl/Families/Diffusion/Implicit-Diffusion-Learners)

## 1. The idea

- **Append.** At each step a token arrives (or is generated). Append its variable and the factors
  that touch it, such as the window relations ending at it, to the graph.
- **Re-solve incrementally.** Warm-start from the previous solution and update only what the new
  factors affect.
- **Denoise the future.** Solve for the next positions with a proximal diffusion step (as in
  ProxDM, queried through a proximal operator instead of a score). Each position's noise level
  depends on its age: old positions are held at (nearly) zero noise, the newest at the most, the
  ones ahead free.
- **Commit, slide.** Commit the next token once its belief is sharp, and move on.

## 2. The precedents

| | what is the same | what differs |
|---|---|---|
| **iSAM2** (Kaess et al. 2012) | a factor per new measurement; incremental re-solve; old variables re-linearised when new evidence warrants it; fixed-lag smoothing (old variables summarised into one prior) | Gaussian, robotics; no diffusion |
| **AR-Diffusion** (Wu et al. 2023) | text; positions further left get fewer denoising steps, so earlier tokens settle first | one network over the sequence; sampling, not a factor graph |
| **Rolling Diffusion** (Ruhe et al. 2024) | a sliding window whose noise rises along it: the oldest frame leaves clean, a pure-noise frame enters | video; trained with the schedule |
| **Diffusion Forcing** (Chen et al. 2024) | a noise level per token; causal prediction is "past clean, future noisy" | one causal network, trained with per-token levels |

So the schedule is established. What would be new here is doing it with an **assembled** graph
(separately learned relations, appended over time) and **inference as proximal root finding**,
with beliefs on the variables.

## 3. What Lenticulum already has

- **Per-block noise levels.** `ImplicitDiffusion(pred, nodes; levels)` holds each block either
  annealed with the field or at a fixed level. Holding the conditioning blocks clean measurably
  helps (VariationalDiffusion `implicit.md` §9: the circle's answer radius 0.993 against 0.978).
  The schedule above is the graded version: a fixed level per block, rising with age (Lenticulum's
  Feature Backlog, "graded block levels").
- **Soft clamps.** A query's precision vector $\rho$ ($\infty$ clamped, 0 free, finite soft) could
  express the same thing the other way round: a token's clamp hardening as it ages.
- **Proximal inference.** VariationalDiffusion's `proxdm.jl`: proximal inference for the implicit
  learner (half-quadratic splitting) and its adjoint.
- **Warm starts across edits.** Mycelium's `transfer` carries a store's messages to an edited graph.
  The reuse of factorisations that makes iSAM incremental is Lenticulum's Feature Backlog item
  "incremental inference".

## 4. What revising the past would mean

In iSAM old states stay revisable, cheaply: a loop closure re-weights the whole trajectory. Here the
observed tokens of the past are clamped. What can be revised is a latent variable over the past's
**reading**: an interpretation, a parse, a topic. A garden-path sentence ("the old man the boat")
is a loop closure. The last words re-weight the reading of the first, while the tokens stay fixed.
An agent chain cannot do that
([[Factor Graphs against Mixtures of Experts and Agent Chains]] §3); a graph with beliefs can, if it
has such latent variables (L6 of [[Open Problems in Assembling Language Models]]).

## 5. Open questions

1. **Does the schedule need training?** A denoiser trained with one noise level per sample (masked
   diffusion) has never seen old positions clean and new ones noisy. Rolling Diffusion and
   Diffusion Forcing train with the schedule; the window relations probably must too.
2. **How many tokens in flight.** Several noisy future positions denoised together can come out
   mutually inconsistent, the parallel-decoding price
   ([[How a Diffusion Language Model Generates]] §1). The schedule sets how many are in flight.
3. **The cost of an append.** iSAM gains because an append touches a small part of the graph. Here
   a window of width $n$ makes each append touch $n$ factors, plus the latent summaries that depend on
   them.
4. **What the fixed lag summarises.** Fixed-lag smoothing replaces old variables by a marginal prior.
   For text that marginal is a belief over the past's reading: the analogue of a context window.
   How wide it must be, and in what code, is L6's question.
5. **When to commit.** By belief sharpness, by a fixed delay, or never (keeping a mixture of
   continuations, a beam).

## 6. A first experiment (proposed)

Character-level, on a small corpus, against a plain sliding-window model of the same size:
- learned window relations (L2) over characters (one-hot codes, [[tokens]]);
- the graph grown one character at a time, warm-started (`transfer`);
- the next characters solved with graded levels (old clean, new noisy, ahead free).

Measure the next-character log-likelihood and the time per character, once with denoisers trained
on a common level and once trained with the schedule. That settles question 1.

Related: [[Assembling a Language Model from Implicit Learners]], [[Open Problems in Assembling Language Models]],
[[Diffusion Language Models]], [[How a Diffusion Language Model Generates]]
