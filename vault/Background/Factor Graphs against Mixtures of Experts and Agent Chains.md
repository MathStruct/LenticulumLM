#comparison

> A mixture of experts routes each input to a few sub-networks and mixes their outputs; an agent
> chain passes a text from one model or tool to the next. Both pass **points** forward: one routing
> decision, one intermediate text. A factor graph with a belief algebra passes **beliefs** in every
> direction. Several hypotheses survive until evidence decides between them, a constraint added
> later can correct an earlier step, and the whole is scored by one free energy. This note says what
> that buys and what it costs.

> Sources: Jacobs, Jordan, Nowlan & Hinton, *Adaptive Mixtures of Local Experts*, Neural Computation 1991; Shazeer et al., *Outrageously Large Neural Networks: The Sparsely-Gated Mixture-of-Experts Layer*, 2017; Fedus, Zoph & Shazeer, *Switch Transformers*, 2021; Hinton, *Training Products of Experts by Minimizing Contrastive Divergence*, Neural Computation 2002; Yao et al., *ReAct*, 2022. The comparison is original to this vault; nothing here is measured.
>
> Bibliography: [[Bibliography#^jacobs1991experts|Jacobs et al. 1991]] · [[Bibliography#^shazeer2017moe|Shazeer et al. 2017]] · [[Bibliography#^fedus2021switch|Fedus et al. 2021]] · [[Bibliography#^hinton2002poe|Hinton 2002]] · [[Bibliography#^yao2022react|Yao et al. 2022]]
>
> Lenticulum (vault): [Belief Algebra](https://mathstruct.org/Lenticulum.jl/Factor-Graphs/Belief-Algebra) · [Messages are Inversions](https://mathstruct.org/Lenticulum.jl/Factor-Graphs/Messages-are-Inversions) · [Switching Constraint Factors](https://mathstruct.org/Lenticulum.jl/Factor-Graphs/Switching-Constraint-Factors) · [RQ-008 Overlays, Mixtures and Tropical Limits](https://mathstruct.org/Lenticulum.jl/Research-Questions/RQ-008-Overlays,-Mixtures-and-Tropical-Limits)

## 1. Three ways to combine models

| | mixture of experts | agent chain | factor graph with beliefs |
|---|---|---|---|
| what flows | an input to the chosen experts, their weighted outputs | one text (or tool result) per step | a belief per variable (a distribution), in every direction |
| combination | a **sum** of experts, gated by the input | **composition** of steps, in order | a **product** of factors, inferred jointly |
| decisions | routing per token (top-1, top-2) | each step commits to its output | committed only when the beliefs are sharp |
| correction | none after routing | a later step can only react | a later factor's evidence flows back to earlier variables |
| a global score | the training loss | none (each step's own) | the free energy of the whole graph |

## 2. A mixture of experts is a switch; a product of experts is an overlay

- **A mixture of experts** (Jacobs et al. 1991) is $p(y \mid x) = \sum_k g_k(x)\, p_k(y \mid x)$: a gate picks experts and
  their predictions are averaged. In a factor graph that is a **switching factor**: a discrete
  outcome $k$ with the gate's weights, and per outcome its expert. The sparse layers of large
  networks (Shazeer et al. 2017, Switch Transformers) keep only the top one or two outcomes, a hard
  switch that is cheap to compute. The graph keeps the outcome's posterior instead. Evidence
  downstream can then revise which expert applied.
- **A product of experts** (Hinton 2002) is $\prod_k p_k(y)/Z$: every expert must agree, and each vetoes
  what it rejects. In a factor graph that is an **overlay** of factors on the same variables.
  Lenticulum's `OverlayFactor` implements it, and with normalisation in the data channels it is a
  product of Gaussian experts or a mixture of experts. A product sharpens, and a sum broadens.
  Overlaying convex energies cannot create several modes; the switch can. A switch is exactly a
  linear constraint overlaid with a concave piecewise-linear term (Lenticulum's RQ-008).

## 3. An agent chain is a composition of point maps

An agent chain (ReAct and its successors) alternates a model's reasoning with tool calls. Each step
reads the previous step's text and writes the next. In Lenticulum's terms every step is a **point
lens**: its output is a Dirac belief, one committed text, and it runs in one direction.
Uncertainty does not propagate. If step 2 was unsure between two readings, step 3 sees only the
one that was written down. A later failure cannot correct step 2 except by rerunning the chain, which is
what retries and reflection prompts do by hand.

## 4. What the belief algebra buys

With beliefs on the variables (categorical over tokens or options, Gaussian over latent
coordinates, mixtures for several hypotheses):

- **Several hypotheses stay alive.** A mixture belief carries both readings until evidence decides.
- **Messages run both ways.** A constraint on the answer (a checker, a type, a unit test, a
  required format) sends a message back to the variables it depends on and reweights them. That is
  verification inside inference, not after it.
- **Additions are factors.** A new requirement is a factor added to the product. Its effect on every
  other variable follows from inference, with no new routing logic.
- **One score.** The free energy is comparable across structures. That is what lets Lenticulum
  search over graph structures by it (structure edits, cluster nodes).

## 5. What it costs

- **Inference is not free.** Exact inference is exponential in the discrete variables a cluster
  joins; belief propagation on loops is approximate; mixtures grow with every switch unless reduced.
  A chain of point maps is cheap because it decides early.
- **Beliefs over text are hard.** A distribution over whole texts has no closed form. In practice
  beliefs are per position (categorical over the vocabulary) or over latent summaries, and the
  dependencies between positions must come from factors, or they are lost.
- **Learning has to be designed.** Each part must be a normalised density in its data channels or
  trained by comparison, or it collapses
  ([Why Learned Relations Do Not Collapse](https://mathstruct.org/Lenticulum.jl/Energy-Based/Why-Learned-Relations-Do-Not-Collapse)),
  and naive joint training of many parts is not expected to converge easily. Distilling the parts
  from a large model, subgraph by subgraph, is the route this repository plans
  ([[Assembling a Language Model from Implicit Learners]] §3, the moonshot).

## 6. A sketch

A question-answering system as a factor graph:
- **Variables:** the question (clamped), a latent reading of it (categorical over interpretations),
  retrieved facts (categorical over candidates), an answer (tokens).
- **Factors:**
  - a parser relating the question to readings;
  - a retriever relating readings to facts;
  - a generator relating readings and facts to the answer;
  - a checker on the answer, for format or consistency with the facts.

Inference returns beliefs over readings and answers together. A checker that rejects an answer
lowers the weight of the reading that produced it. An agent chain would have committed to one
reading at the first step.

Related: [[Diffusion Language Models]], [[Meaning as a Relation over Text]],
[[Embeddings in a Diffusion Language Model]]
