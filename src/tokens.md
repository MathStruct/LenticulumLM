#implementation

> Tokens as coordinates. A sequence of $L$ tokens over $V$ symbols is a point of
> $\mathbb R^{VL}$: one block of $V$ coordinates per position, each token its scaled one-hot code.
> A query clamps the blocks of the known tokens and frees the rest, so the direction of a query
> (continue, predict backwards, fill in) is a choice of precisions, not of model.

> Sources: code: `tokens.jl`; Li et al., *Diffusion-LM Improves Controllable Text Generation*, NeurIPS 2022 (continuous codes for tokens); Austin et al., *Structured Denoising Diffusion Models in Discrete State-Spaces*, NeurIPS 2021 (the discrete alternative)
>
> Bibliography: [[Bibliography#^li2022diffusionlm|Li et al. 2022]] · [[Bibliography#^austin2021d3pm|Austin et al. 2021]]
>
> Lenticulum (vault): [Implicit Diffusion Learners](https://mathstruct.org/Lenticulum.jl/dev/vault/Families/Diffusion/Implicit-Diffusion-Learners) §2 (polarity is a precision vector) · [MNIST in Both Directions](https://mathstruct.org/Lenticulum.jl/dev/vault/Applications/MNIST-in-Both-Directions) (a label as a scaled one-hot code)

## 1. The encoding

`Vocabulary(symbols; scale = C)` numbers the symbols $1, \dots, V$ and gives symbol $a$ the code
$C e_a \in \mathbb R^V$. Position $i$ of a sequence owns the coordinates `block(v, i)`
$= (i-1)V+1, \dots, iV$, so a sequence is the concatenation of its codes:

$$
z = (C e_{x_1}, \dots, C e_{x_L}) \in \mathbb R^{VL} .
$$

`decode` reads each block back by its largest coordinate, which is the nearest code: the codes
are orthogonal and of equal length, so the nearest code to $u$ is $\arg\max_a u_a$.

`sequence_query(v, tokens)` turns a partly known sequence (a symbol or `nothing` per position)
into the query of an implicit learner. The precision is $\infty$ on the blocks of known tokens
(hard clamps) and $0$ on the others (free), and $z_0$ holds the known codes. An unknown
position starts at zero, the centre of the codes, which favours no symbol.

This is the encoding of the MNIST example in Lenticulum, where the label is the code
$C e_y \in \mathbb R^{10}$ next to the image. A language model has only labels.

## 2. What it does not do

- **It does not scale with the vocabulary.** A block has $V$ coordinates, so a sequence of $L$
  tokens over a vocabulary of $5\cdot10^4$ is a state of $5\cdot10^4 L$ coordinates, and every free
  block of a query is $V$ unknowns for the root finder. Diffusion-LM avoids this with learned
  low-dimensional embeddings, and masked discrete diffusion (D3PM, MDLM) avoids it by not having
  a continuous state at all. Both are open here
  ([[Open Problems in Assembling Language Models]] L3, L4).
- **No tokeniser.** Symbols are whatever the vocabulary is built from (characters, words,
  integers). Splitting text into tokens is left to the caller.
- **No soft evidence.** A query either clamps a position or frees it. A noisy observation of a
  token would be a finite precision on its block, which the implicit learner supports but
  `sequence_query` does not build yet.
- **The scale $C$ matters, and is not chosen here.** Relative to the noise levels of the learner,
  $C$ sets how far apart the codes are: too small and the answers of neighbouring symbols merge
  under the smoothing, too large and the field is stiff. The default $C = 1$ with mixture width
  $0.05$ separates them by 20 widths.

Related: [[sequence]], [[Assembling a Language Model from Implicit Learners]]
