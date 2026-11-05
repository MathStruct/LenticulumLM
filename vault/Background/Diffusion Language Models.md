#overview

> A diffusion language model generates a whole text at once, by starting from noise and
> denoising every position in parallel, instead of writing it left to right. The variants differ
> in where the noise lives: on continuous embeddings of the tokens, or on the tokens themselves
> (replaced by random tokens, or masked). Masked diffusion is the variant that now scales. This
> note is a map of the variants and of what each offers the relational models of this vault.

> Sources: Austin et al., *Structured Denoising Diffusion Models in Discrete State-Spaces* (D3PM), NeurIPS 2021; Li et al., *Diffusion-LM Improves Controllable Text Generation*, NeurIPS 2022; Dieleman et al., *Continuous Diffusion for Categorical Data* (CDCD), 2022; Gulrajani & Hashimoto, *Likelihood-Based Diffusion Language Models* (Plaid), 2023; Lou, Meng & Ermon, *Discrete Diffusion Modeling by Estimating the Ratios of the Data Distribution* (SEDD), ICML 2024; Sahoo et al., *Simple and Effective Masked Diffusion Language Models* (MDLM), NeurIPS 2024; Shi et al., *Simplified and Generalized Masked Diffusion for Discrete Data* (MD4), 2024; Nie et al., *Large Language Diffusion Models* (LLaDA), 2025; Arriola et al., *Block Diffusion* (BD3-LM), 2025. An overview written from these papers; nothing here is measured in this repository.
>
> Bibliography: [[Bibliography#^austin2021d3pm|Austin et al. 2021]] · [[Bibliography#^li2022diffusionlm|Li et al. 2022]] · [[Bibliography#^dieleman2022cdcd|Dieleman et al. 2022]] · [[Bibliography#^gulrajani2023plaid|Gulrajani & Hashimoto 2023]] · [[Bibliography#^lou2024sedd|Lou et al. 2024]] · [[Bibliography#^sahoo2024mdlm|Sahoo et al. 2024]] · [[Bibliography#^shi2024md4|Shi et al. 2024]] · [[Bibliography#^nie2025llada|Nie et al. 2025]] · [[Bibliography#^arriola2025block|Arriola et al. 2025]]
>
> Lenticulum (vault): [Language Models](https://mathstruct.org/Lenticulum.jl/Applications/Language-Models) · [Implicit Diffusion Learners](https://mathstruct.org/Lenticulum.jl/Families/Diffusion/Implicit-Diffusion-Learners)

## 1. The idea

An autoregressive model factorises $p(x_1, \dots, x_L) = \prod_i p(x_i \mid x_{<i})$ and generates one token at a time.
A diffusion model instead defines a **forward process** that corrupts a text step by step until
nothing is left, and learns the **reverse process**: given a corrupted text and the noise level,
predict the clean one. Generation runs the reverse process from pure noise. Every position is
updated at every step, so the model sees the whole text in both directions. Infilling, editing
and constraints on any position are then natural, not special cases. [[How a Diffusion Language
Model Generates]] goes through the steps.

## 2. The variants

| family | the noisy state | the network predicts | examples |
|---|---|---|---|
| **continuous, on embeddings** | each token's embedding plus Gaussian noise | the clean embedding (or the noise), then a rounding step to tokens | Diffusion-LM, CDCD, Plaid |
| **discrete, uniform** | each token replaced, with growing probability, by a random token | the distribution of the clean token at each position | D3PM (uniform transitions) |
| **discrete, absorbing (masked)** | each token replaced, with growing probability, by a `[MASK]` token | the clean token at each masked position | D3PM (absorbing), MDLM, MD4, LLaDA |
| **discrete, score-based** | as above (uniform or absorbing) | ratios $p(y)/p(x)$ of neighbouring sequences, the discrete analogue of the score | SEDD |
| **block (semi-autoregressive)** | blocks generated left to right, masked diffusion within a block | as for masked diffusion, conditioned on the earlier blocks | BD3-LM |

- **Continuous.** Diffusion-LM diffuses in a learned embedding space, and its gradient guidance
  gives controllable generation (syntax, length, content). Its embeddings are learned together
  with the denoiser, which needs care: [[Embeddings in a Diffusion Language Model]].
  - CDCD trains the denoiser with a cross-entropy loss over the vocabulary and normalises the
    embeddings ("score interpolation", "time warping").
  - Plaid studies the likelihood scaling of continuous models.
- **Masked.** The forward process masks each token independently. MDLM and MD4 showed that the
  training objective simplifies to a weighted mixture of masked-language-modelling losses (as in
  BERT), one per masking rate. That made masked diffusion simple to train and competitive with
  autoregressive models of the same size. LLaDA trained such a model at the 8-billion-parameter
  scale.
- **Score-based discrete.** SEDD learns the ratios of the data distribution between sequences
  that differ in one token. That is the "score" of a discrete distribution, and the paper reports
  perplexities competitive with autoregressive models of GPT-2's size.
- **Block.** BD3-LM interpolates between the two worlds: autoregressive over blocks, diffusion
  within a block. That brings back variable-length generation and key-value caching.

## 3. What they offer this vault

- **Every query direction.** A diffusion model conditions on any set of positions and fills the
  rest. That is the clamp-and-solve interface of Lenticulum's implicit learners
  ([[tokens]]: queries as clamps).
- **A relation, not only a sampler.** The denoiser at small noise points towards the data. Its
  fixed points or stable roots are the texts the model "accepts". That is the sense in which a
  model is a relation over text ([[Meaning as a Relation over Text]]).
- **The choice ahead** ([[Assembling a Language Model from Implicit Learners]] §3): Lenticulum's
  learners are continuous (roots, Laplace weights, adjoints), which is the Diffusion-LM family,
  while the masked discrete family is the one that scales. A discrete implicit learner would join
  them.

Related: [[How a Diffusion Language Model Generates]], [[Meaning as a Relation over Text]],
[[Embeddings in a Diffusion Language Model]], [[Factor Graphs against Mixtures of Experts and Agent Chains]]
