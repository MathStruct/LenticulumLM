#open-problem

> The roadmap of LenticulumLM: every step from a closed-form $n$-gram chain to a language model
> assembled from learned implicit relations, with its status and its evidence. One step is
> done; the others are open, and some of them are open in Lenticulum as well.

> Sources: original to this vault (analysis); code: `tokens.jl`, `sequence.jl`
>
> Lenticulum (vault): [Open Problems in Implicit Diffusion Learning](https://mathstruct.org/Lenticulum.jl/Families/Diffusion/Open-Problems-in-Implicit-Diffusion-Learning) · [Language Models](https://mathstruct.org/Lenticulum.jl/Applications/Language-Models) · [product](https://mathstruct.org/Lenticulum.jl/lib/VariationalDiffusion.jl/product)

### L1. A language model assembled from relations — **done (closed form)**

`sequence_relation` joins window relations with separators; with the closed-form windows of a
bigram chain, every query direction is answered to within $10^{-4}$ of the closed form, and every
completion is found ([[sequence]] §3). Without separators the error is 0.01 to 0.06 and grows
with the number of inner positions.

### L2. Learned windows — **open (next)**

Train an energy network on the windows of a small corpus (characters of a text, $V \approx 30$,
$n = 3$ to $5$), use it as the window relation, and measure the assembled model against the corpus's
empirical $n$-gram statistics: per-query marginals, the smoothing bias, and how it adds up along
the sequence. The separators need the window's marginal on the overlap, which is either a second
learned relation or the window queried with its other positions free.

### L3. A discrete implicit learner — **open**

Masked discrete diffusion (D3PM, MDLM, LLaDA) models language better than continuous codes, but
has no continuous state to find roots in. A discrete learner would answer a query by a fixed
point of the denoiser's per-position categorical predictions, with clamps on the known tokens.
What replaces the Jacobian, the Laplace weight and the adjoint there is open.

### L4. Vocabulary scale — **open**

One-hot codes give a position $V$ coordinates, so a query with $u$ free positions has $uV$
unknowns. For a real vocabulary this needs low-dimensional learned embeddings (Diffusion-LM) with
a decoding step, or the discrete learner of L3.

### L5. Messages instead of joint answers — **open**

`token_marginals` enumerates all $V^u$ completions. Belief propagation on the chain of windows,
with categorical beliefs as messages, would cost $O(L V^n)$ instead. It needs a window relation
to produce a categorical message for one position given categorical beliefs on the others, which
for continuous codes means integrating the relation over the codes of the other positions.

### L6. Long-range structure — **open**

A chain of windows is Markov of order $n - 1$. Longer dependencies need latent variables (segment
summaries with relations between them) or other factor-graph structure than a chain. Which
structure a corpus supports, and how the latent relations are trained, is open.

### L7. Composition of learned relations at $t > 0$ — **open (shared with Lenticulum)**

Products of smoothed relations are not smoothed products. On Lenticulum's chain of learned curves
the bias grows about linearly in the number of relations (`product.md` §4) and shrinks at lower
noise levels. Over the length of a text this may dominate; correctors (MCMC at each level, as
in Du et al.) or lower levels are the known remedies.

### L8. Distilling a pretrained model — **moonshot**

Dissect a small open-weight language model into a graph of language diffusion relations, with
embeddings only at the input and output. It depends on L3 to L6.

## Summary

| | step | status |
|---|---|---|
| L1 | assembly from relations | done, closed form: exact in every query direction |
| L2 | learned windows | open, next |
| L3 | discrete implicit learner | open |
| L4 | vocabulary scale | open |
| L5 | messages instead of joint answers | open |
| L6 | long-range structure | open |
| L7 | composition at $t > 0$ | open, shared with Lenticulum |
| L8 | distillation | moonshot |

Related: [[Assembling a Language Model from Implicit Learners]], [[sequence]], [[tokens]]
