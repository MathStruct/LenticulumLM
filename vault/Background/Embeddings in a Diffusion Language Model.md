#design

> A language model usually works on embeddings: each token becomes a learned vector. For a
> diffusion model on continuous embeddings, learned embeddings are a known source of trouble:
> trained with the denoiser, they can collapse to make denoising trivial, so they are normalised
> or anchored. A factor graph whose variables each had their own, drifting embedding would make it
> worse, since messages between variables need one code. Discrete diffusion works without an
> embedding in its state, and there is precedent for models without a token embedding at all.

> Sources: Li et al., *Diffusion-LM Improves Controllable Text Generation*, NeurIPS 2022; Dieleman et al., *Continuous Diffusion for Categorical Data* (CDCD), 2022; Gulrajani & Hashimoto, *Likelihood-Based Diffusion Language Models* (Plaid), 2023; Sahoo et al. (MDLM), NeurIPS 2024; Xue et al., *ByT5*, 2021; Yu et al., *MEGABYTE*, 2023; Pagnoni et al., *Byte Latent Transformer*, 2024. The collapse argument (§2) is an interpretation in Lenticulum's terms, not measured here. code: `tokens.jl`
>
> Bibliography: [[Bibliography#^li2022diffusionlm|Li et al. 2022]] · [[Bibliography#^dieleman2022cdcd|Dieleman et al. 2022]] · [[Bibliography#^gulrajani2023plaid|Gulrajani & Hashimoto 2023]] · [[Bibliography#^xue2021byt5|Xue et al. 2021]] · [[Bibliography#^yu2023megabyte|Yu et al. 2023]] · [[Bibliography#^pagnoni2024blt|Pagnoni et al. 2024]]
>
> Lenticulum (vault): [Why Learned Relations Do Not Collapse](https://mathstruct.org/Lenticulum.jl/Energy-Based/Why-Learned-Relations-Do-Not-Collapse) · [Language Models](https://mathstruct.org/Lenticulum.jl/Applications/Language-Models)

## 1. Where embeddings enter

- **In the network.** Every model embeds tokens at its input and maps back to the vocabulary at its
  output. That is internal to the network and harmless: it is how the denoiser computes.
- **In the diffusion state.** Only continuous diffusion (Diffusion-LM, CDCD, Plaid) puts embeddings
  in the noisy state itself: the state is a matrix of embedding vectors plus noise. Discrete
  diffusion (D3PM, MDLM, SEDD, LLaDA) noises the tokens: its state is a sequence of tokens and
  masks, with no embedding.
- **In this repository.** [[tokens]] codes each token as a one-hot block, a fixed code with no
  learned embedding in the state. That is the simplest embedding-free choice, at a dimension equal
  to the vocabulary size.

## 2. Learned embeddings in the state: the collapse problem

If the embeddings are learned together with the denoiser, the objective can be lowered by moving
them instead of by denoising better. Shrinking all embeddings towards each other makes the noise
relatively large, and the problem changes. Pushing them far apart makes the noisy states trivially
separable. Diffusion-LM trains the embeddings jointly and adds a rounding term that ties
the clean state to a token. CDCD normalises the embeddings and trains with a cross-entropy over
tokens. Both are ways of fixing the scale the objective would otherwise exploit.

In Lenticulum's terms this is the collapse of a learned relation whose coordinates are not fixed:
the embedding is a learned change of variables. Without its Jacobian (or a fixed normalisation) the
objective can be satisfied by squashing or stretching the space instead of by fitting.
[Why Learned Relations Do Not Collapse](https://mathstruct.org/Lenticulum.jl/Energy-Based/Why-Learned-Relations-Do-Not-Collapse)
goes through the same mechanism for other factors. The cure has the same shape: fix the scale
(normalised or anchored embeddings), or pay for it (a log-Jacobian).

## 3. One embedding per variable?

The question: in a factor graph of such models, if every variable had its own embedding and the
embeddings drifted as the parts were learned, would that be a problem? Yes, for three reasons.

1. **Messages need a common code.** A message from one factor to a variable is a belief over that
   variable's values. If two factors on the same variable use different embeddings, their messages
   live in different spaces, and the product of the beliefs is undefined until a map between the
   codes is fixed. That map is either learned too, which is one more drifting part, or the
   embedding is shared.
2. **Drift breaks composition.** A factor learned against one embedding is wrong once the embedding
   moves. Relations composed by product assume their coordinates mean the same thing on both
   sides of every shared variable.
3. **Collapse, per variable.** Each learned embedding is a place where §2's collapse can happen.

So embeddings should be shared and fixed across the graph, or learned once and frozen before the
parts are, or replaced by a discrete code.

## 4. Embedding-free, and the precedent

- **Discrete state, internal embeddings.** Masked diffusion has no embedding in its state.
  Variables are tokens, and messages are categorical beliefs over the vocabulary, which pool
  exactly. This is what [[Assembling a Language Model from Implicit Learners]] §3 means by
  per-position categorical beliefs. The networks still embed internally, but nothing drifts
  between factors.
- **Byte-level models.** ByT5 works on bytes, with no learned tokeniser and a vocabulary of 256.
  MEGABYTE and the Byte Latent Transformer group bytes into patches, the latter of dynamic size, and
  report scaling competitive with token models. The state is the raw bytes; any embedding is inside
  the network.
- **One-hot codes**, as here: exact and fixed, but of the vocabulary's dimension. They are practical
  for characters or bytes, and too wide for a 50 000-token vocabulary in a continuous state.

**A suggestion**, not tested: variables as tokens or bytes with categorical beliefs (discrete,
embedding-free), embeddings only inside each factor's network, and latent summary variables (the
long-range structure of §3 there) in a code that is learned once and then fixed.

Related: [[Diffusion Language Models]], [[Meaning as a Relation over Text]], [[tokens]]
