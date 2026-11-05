#algorithm

> Generation runs the corruption backwards: start from a fully masked (or fully noisy) text, and at
> each step let the network predict every position, then commit some of the predictions and
> re-corrupt the rest. The number of steps trades speed against quality, and which predictions are
> committed is a design choice of its own. Conditioning and infilling are clamps: the given tokens
> are never corrupted.

> Sources: Sahoo et al., *Simple and Effective Masked Diffusion Language Models* (MDLM), NeurIPS 2024; Nie et al., *Large Language Diffusion Models* (LLaDA), 2025; Li et al., *Diffusion-LM Improves Controllable Text Generation*, NeurIPS 2022; Lou, Meng & Ermon (SEDD), ICML 2024; Arriola et al., *Block Diffusion*, 2025. A summary of their samplers; nothing here is measured in this repository.
>
> Bibliography: [[Bibliography#^sahoo2024mdlm|Sahoo et al. 2024]] · [[Bibliography#^nie2025llada|Nie et al. 2025]] · [[Bibliography#^li2022diffusionlm|Li et al. 2022]] · [[Bibliography#^arriola2025block|Arriola et al. 2025]]
>
> Lenticulum (vault): [Implicit Diffusion Learners](https://mathstruct.org/Lenticulum.jl/Families/Diffusion/Implicit-Diffusion-Learners)

## 1. Masked diffusion, step by step

The forward process masks each token independently with probability $t$, the noise level from
0 (the text) to 1 (all masked). The network $\hat p_\theta(x_i \mid z_t)$ predicts a distribution over the
vocabulary at every masked position $i$, given the partly masked text $z_t$. To generate $L$ tokens in $T$
steps:

1. Start with $z_1 = [\mathrm{MASK}]^L$ (the prompt's positions, if any, are filled and stay filled).
2. For $t = 1, 1 - \tfrac1T, \dots, \tfrac1T$:
   - predict every masked position, $\hat x_i \sim \hat p_\theta(\cdot \mid z_t)$, or take the most likely token;
   - **commit** a fraction of them, the expected number going from $t$ to $t - \tfrac1T$, and keep the rest
     masked.
3. After $T$ steps nothing is masked: that is the text.

**Which predictions to commit.** The plain reverse process commits a random subset, as the
forward process masked one. LLaDA's *low-confidence remasking* instead commits the most
confident predictions and re-masks the least confident. That is a heuristic, and the paper reports
it works better than random remasking. Committed tokens are never revised in the basic sampler. Revising them (re-masking
a committed token) is possible and is a choice of sampler.

**Steps and quality.** With $T = L$ steps one token is committed per step, like an autoregressive
model in a learned order. With fewer steps several tokens are committed at once, from predictions
that were made independently per position given $z_t$. Positions that depend strongly on each other
(the two words of a fixed expression) can then come out inconsistent. That is the price of
parallel decoding, and the reason quality drops as $T$ falls.

## 2. Continuous diffusion

In Diffusion-LM the state is a matrix of embeddings plus Gaussian noise. Each step denoises it,
like an image diffusion model, and at the end every position is **rounded** to its nearest
token's embedding. Guidance is a gradient on the continuous state: a classifier's
$\nabla \log p(c \mid x_t)$ added to the score steers the text towards an attribute $c$. Rounding is the
weak point, because a state between two embeddings commits to one of them only at the end.

## 3. Score-based and block samplers

- **SEDD** steps a continuous-time Markov chain whose rates are the learned ratios. It updates
  several positions per step ("$\tau$-leaping") or one position exactly.
- **Block diffusion** generates block after block, each by masked diffusion conditioned on the
  blocks before. It can stop at any block boundary, which gives variable length, and it reuses
  earlier blocks' computation.

## 4. Conditioning as clamping

Any token given in advance is fixed and never masked: a prompt (a prefix), a suffix, scattered
words, or a template with slots. The model fills the rest. In the relational reading of this vault,
a query clamps the known positions and solves for the free ones
([[tokens]]; [[Assembling a Language Model from Implicit Learners]] §1). A diffusion model is a
solver that answers every such query with one network. The difference from a relation is that it
samples one answer per run. A relation's interface instead enumerates the stable answers
(Lenticulum's `implicit_roots`) or their mixture.

Related: [[Diffusion Language Models]], [[Meaning as a Relation over Text]]
