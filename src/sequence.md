#implementation

> A language model assembled from implicit learners: one relation per window of $n$
> consecutive tokens, joined by separators on the overlaps. With the windows of an $n$-gram
> chain this is that chain exactly, and one assembled relation answers continuation, backward
> prediction and infilling, each to within $10^{-4}$ of the closed form.

> Sources: code: `sequence.jl`, `tokens.jl`; Hinton, *Training Products of Experts by Minimizing Contrastive Divergence*, Neural Computation 2002 (the product); Du et al., *Reduce, Reuse, Recycle: Compositional Generation using Energy-Based Diffusion Models and MCMC*, ICML 2023 (adding scores, and why it is not exact at $t > 0$)
>
> Bibliography: [[Bibliography#^hinton2002poe|Hinton 2002]]
>
> Lenticulum (vault): [product](https://mathstruct.org/Lenticulum.jl/lib/VariationalDiffusion.jl/product) §4 (separators, longer chains) · [Implicit Diffusion Learners](https://mathstruct.org/Lenticulum.jl/Families/Diffusion/Implicit-Diffusion-Learners) · [Language Models](https://mathstruct.org/Lenticulum.jl/Applications/Language-Models) §7

## 1. The construction

A window relation sees $n$ consecutive positions. Applied at every offset and joined by a
separator on each overlap of two consecutive windows,

$$
p(x_1, \dots, x_L) = \frac{\prod_{k=1}^{L-n+1} p_{\mathrm{win}}(x_k, \dots, x_{k+n-1})}{\prod_{k=2}^{L-n+1} p_{\mathrm{sep}}(x_k, \dots, x_{k+n-2})} .
$$

When $p_{\mathrm{win}}$ is the $n$-gram distribution of a stationary $(n-1)$-th order Markov chain
and $p_{\mathrm{sep}}$ its $(n-1)$-gram marginal, this is the chain's joint distribution: the
junction-tree factorisation of a path. `sequence_relation` builds it as a Lenticulum
`ProductRelation`, with the window relation on the coordinates of positions $k, \dots, k+n-1$
and the separator, weight $-1$, on the overlap. The same relation object and parameters are
used at every offset: the model is stationary, and its parameters are shared as a sliding
network's would be.

`window_relation(v, P)` is the closed-form window: a Gaussian mixture of width $s$ with one
component at the codes of every window $(a_1, \dots, a_n)$ with $P[a_1, \dots, a_n] > 0$, weighted by
it. This is the relation a diffusion model trained on those windows would converge to, with
every derivative exact, so it is the test oracle for the assembly. A learned window would replace
it without changing anything else.

## 2. Reading the answers as tokens

A query clamps the known positions. `implicit_mixture` finds its stable roots, each with a
Laplace weight $\propto e^{-U(z_k)}\det(\Sigma_k)^{1/2}$, which is the probability of the completion
it represents. `position_marginals` decodes every root to its nearest codes and adds its weight
to the symbol it gives at each free position. The result is one categorical distribution per
free position, the marginal of the query's posterior. `token_marginals` does both steps, and
`position_beliefs` turns the columns into LenticulumCore `CategoricalBelief`s labelled with the
symbols, the belief type a factor graph over tokens passes along.

The number of roots is the number of completions with positive probability, $V^u$ for $u$ free
positions of a chain with full support. `token_marginals` starts 16 solves per completion by
default. That is fine for the test's three symbols and hopeless for a real vocabulary (§4).

## 3. Measured

A stationary bigram chain over three symbols, $T = \begin{pmatrix}0.6&0.3&0.1\\0.2&0.5&0.3\\0.3&0.2&0.5\end{pmatrix}$, its
stationary $\pi$, window table $\pi(a)T(a,b)$ and separator $\pi$. Width $0.05$, the default nodes.
Errors are the largest difference of a marginal from its closed form:

| $L$ | query | closed form | answers | error | without separators | time |
|---|---|---|---|---|---|---|
| 3 | `[a, ?, ?]`, last position | $(T^2)_{a\cdot}$ | 9 | $2\cdot10^{-5}$ | 0.013 | 8.7 s (first call, compiling) |
| 3 | `[?, ?, c]`, first position | $\propto \pi(\cdot)(T^2)_{\cdot c}$ | 9 | $8\cdot10^{-5}$ | 0.019 | 0.7 s |
| 3 | `[a, ?, c]` | $\propto T_{a\cdot}T_{\cdot c}$ | 3 | $1\cdot10^{-4}$ | 0.042 | 0.2 s |
| 4 | `[a, ?, ?, ?]`, last position | $(T^3)_{a\cdot}$ | 27 | $1\cdot10^{-5}$ | 0.021 | 5.5 s |
| 4 | `[?, ?, ?, c]`, first position | $\propto \pi(\cdot)(T^3)_{\cdot c}$ | 27 | $7\cdot10^{-5}$ | 0.030 | 3.3 s |
| 4 | `[a, ?, ?, c]`, position 2 | $\propto T_{a\cdot}(T^2)_{\cdot c}$ | 9 | $9\cdot10^{-5}$ | 0.060 | 1.1 s |

Every completion is found, and every query direction is answered by the same relation. Without
the separators each inner position's marginal counts once per window covering it, and the
error grows with the number of inner positions (Lenticulum's `product.md` §4 measures the same for
chains of three to five binary relations).

## 4. What it does not do

- **The windows are not learned yet.** `window_relation` is the exact relation of a known
  table. A learned window (an energy network on $nV$ coordinates, trained by denoising on the
  windows of a corpus) plugs into `sequence_relation` unchanged. Training one, and measuring
  how its smoothing bias adds up along a sequence, is the next step
  ([[Open Problems in Assembling Language Models]] L2).
- **The separators are supplied.** They must be the marginals of the windows on the overlaps,
  or the product is not the chain. For a learned window that means a second learned relation,
  or the window model queried with the other positions marginalised away.
- **Enumerating answers is exponential.** A query with $u$ free positions has up to $V^u$ roots.
  The categorical marginals here sum over all of them. A real model needs per-position beliefs
  passed between windows (message passing on the chain) instead of the joint answers, which
  means categorical beliefs over continuous codes ([[Open Problems in Assembling Language Models]] L5).
- **Composition is exact here only because the windows are closed form.** For networks the
  product of smoothed relations is not the smoothed product (the $t > 0$ obstruction of
  Lenticulum's *Language Models* §7), and the error is expected to add up along the chain like
  the smoothing bias does.

Related: [[tokens]], [[Assembling a Language Model from Implicit Learners]],
[[Open Problems in Assembling Language Models]]
