#design #overview

> **The plan of this repository.** A diffusion language model whose parts are implicit
> learners: each part is a relation over a few token positions, the model is their product,
> and every query (continue, predict backwards, fill in, satisfy a constraint) is root finding
> with the known tokens clamped. The first step, an $n$-gram chain assembled from closed-form
> relations, is exact. What follows from it, and what stands in the way, is laid out here.

> Sources: original to this vault (design); builds on Hinton, *Training Products of Experts by Minimizing Contrastive Divergence*, Neural Computation 2002; Li et al., *Diffusion-LM Improves Controllable Text Generation*, NeurIPS 2022; Austin et al., *Structured Denoising Diffusion Models in Discrete State-Spaces*, NeurIPS 2021; Sahoo et al., *Simple and Effective Masked Diffusion Language Models* (MDLM); Lou, Meng & Ermon, *Discrete Diffusion Modeling by Estimating the Ratios of the Data Distribution* (SEDD); Nie et al., *Large Language Diffusion Models* (LLaDA); Du et al., *Reduce, Reuse, Recycle: Compositional Generation using Energy-Based Diffusion Models and MCMC*, ICML 2023; Liu, Li, Du, Tenenbaum & Torralba, *Compositional Visual Generation with Composable Diffusion Models*, ECCV 2022; code: `tokens.jl`, `sequence.jl`
>
> Bibliography: [[Bibliography#^hinton2002poe|Hinton 2002]] · [[Bibliography#^li2022diffusionlm|Li et al. 2022]] · [[Bibliography#^austin2021d3pm|Austin et al. 2021]] · [[Bibliography#^sahoo2024mdlm|Sahoo et al. 2024]] · [[Bibliography#^lou2024sedd|Lou et al. 2024]] · [[Bibliography#^nie2025llada|Nie et al. 2025]] · [[Bibliography#^liu2022composable|Liu et al. 2022]]
>
> Lenticulum (vault): [Language Models](https://mathstruct.org/Lenticulum.jl/Applications/Language-Models) · [Implicit Diffusion Learners](https://mathstruct.org/Lenticulum.jl/Families/Diffusion/Implicit-Diffusion-Learners) · [Composing Diffusion Factors](https://mathstruct.org/Lenticulum.jl/Families/Diffusion/Composing-Diffusion-Factors) · [product](https://mathstruct.org/Lenticulum.jl/lib/VariationalDiffusion.jl/product) · [Categorical Belief](https://mathstruct.org/Lenticulum.jl/Factor-Graphs/Categorical-Belief) · [Universal Approximation for Implicit Diffusion Learners](https://mathstruct.org/Lenticulum.jl/Families/Diffusion/Universal-Approximation-for-Implicit-Diffusion-Learners)
>
> Theory (CT-ML wiki): [Markov Category](https://mathstruct.org/CategoryTheory-ML-Wiki/Markov-Category) · [Bayesian Inversion](https://mathstruct.org/CategoryTheory-ML-Wiki/Bayesian-Inversion) · [Variational Free Energy](https://mathstruct.org/CategoryTheory-ML-Wiki/Variational-Free-Energy)

## 1. What is being built

Diffusion language models (MDLM, SEDD, LLaDA) already refine a whole sequence at once and can
fill in any masked positions. What they are not is **modular**: the model is one network over
the whole sequence, trained once, and nothing can be added to it at query time except guidance.

Lenticulum's implicit learners are relations, and relations compose by product
([Composing Diffusion Factors](https://mathstruct.org/Lenticulum.jl/Families/Diffusion/Composing-Diffusion-Factors)).
So a language model can be **assembled**: separately learned relations over windows, spans or
latent summaries, combined into one model whose queries are answered jointly. The pieces this
needs, and what Lenticulum provides for each:

| piece | in this repository | from Lenticulum |
|---|---|---|
| text as a joint space | [[tokens]]: one block of $V$ coordinates per position, tokens as one-hot codes | the joint space and its polarity (precision vector) |
| a relation on a window | [[sequence]]: `window_relation`, closed form for now | `ImplicitDiffusion` with any noise predictor; energy networks |
| the model as a product | [[sequence]]: `sequence_relation`, windows and separators | `ProductRelation` with coordinates and weights |
| a query's answers | `token_marginals`, `position_beliefs` | `implicit_mixture` (every stable root, Laplace weights), `CategoricalBelief` |

## 2. The first step: an $n$-gram chain, exactly

A chain of windows of width $n$, joined by separators on the overlaps,

$$
p(x_1, \dots, x_L) = \frac{\prod_k p_{\mathrm{win}}(x_k, \dots, x_{k+n-1})}{\prod_k p_{\mathrm{sep}}(x_{k+1}, \dots, x_{k+n-1})},
$$

is an $(n-1)$-th order Markov chain when the windows are its $n$-gram marginals. With closed-form
window relations (Gaussian mixtures at the codes of the $n$-grams), one assembled bigram model
over three symbols answers the continuation, the backward prediction and the infilling to within
$10^{-4}$ of the closed form, finding every completion as a separate answer ([[sequence]] §3).

This is the Lenticulum chain of `product.md` §4 with a vocabulary. It establishes that the
assembly is right, and that the answers of a relation, read per position, are the categorical
marginals a language model must produce. It does not yet learn anything.

## 3. The decisions ahead

**Continuous codes or a discrete learner.** Lenticulum's learners are continuous: a score or
energy on $\mathbb R^d$, with tokens as points. That is Diffusion-LM's choice, and it is what makes
root finding, Laplace weights and the adjoint available. Masked discrete diffusion (D3PM, MDLM,
LLaDA) is better at language and has no continuous state, so no roots. A discrete implicit
learner, where a query's answer is a fixed point of the denoiser's categorical predictions, would
keep the relational interface with a discrete model. Lenticulum has nothing of the kind yet.

**Joint answers or messages.** `token_marginals` enumerates every answer, $V^u$ of them for $u$
free positions. A language model needs the per-position beliefs passed between windows instead:
belief propagation on the chain, with categorical beliefs as messages. Pooling categorical beliefs
is exact and cheap ([Categorical Belief](https://mathstruct.org/Lenticulum.jl/Factor-Graphs/Categorical-Belief)),
but a window relation over continuous codes does not yet produce a categorical message for one
position given messages on the others.

**Where long-range structure comes from.** A chain of windows is Markov of order $n-1$. Longer
dependencies need wider windows (cost grows with $nV$) or latent variables: a summary of a
segment as its own variable, with relations between summaries. That is a factor graph with
latents, which Lenticulum's design supports and nothing here builds yet.

**Composition is not free for learned windows.** The product of smoothed relations is not the
smoothed product, so composing networks is approximate at every noise level (Lenticulum's
*Language Models* §7). On a chain of learned curves the smoothing bias adds up roughly linearly
in the length (`product.md` §4). How it behaves over hundreds of positions is open.

**The moonshot.** In the end, distil a small open-weight language model into such a graph:
relations between token sequences, with embeddings only at the input and output and per-position
categorical beliefs on the internal variables. Whether a pretrained model's computation can be
dissected that way is the question this repository exists to answer.

## 4. The order of work

The roadmap, with the status of each step, is [[Open Problems in Assembling Language Models]];
how the experiments, their data and the tools are set up is [[Environment and Experiments]].
In short: learned windows on a character corpus (L2) come next, then messages instead of joint
answers (L5), then a discrete learner (L3) and scale (L4).

Related: [[tokens]], [[sequence]], [[Open Problems in Assembling Language Models]], [[Map of Content]]
