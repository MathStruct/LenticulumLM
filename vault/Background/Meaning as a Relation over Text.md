#design

> A meaning does not pick out one text; it picks out a set of texts that express it, and a text
> can carry several meanings. So meaning is naturally a **relation** between texts and meanings, or
> between texts and texts (paraphrase, entailment, translation), not a function. A relational model
> answers in every direction (generate from a meaning, read a meaning off a text, check that two
> texts agree) and composes by product. This note makes that precise enough to build on, and says
> what it does not settle.

> Sources: original to this vault (design and interpretation). It uses Lenticulum's reading of implicit learners as relations; no claim here is measured.
>
> Lenticulum (vault): [Implicit Diffusion Learners](https://mathstruct.org/Lenticulum.jl/Families/Diffusion/Implicit-Diffusion-Learners) · [Composing Diffusion Factors](https://mathstruct.org/Lenticulum.jl/Families/Diffusion/Composing-Diffusion-Factors) · [Why Learned Relations Do Not Collapse](https://mathstruct.org/Lenticulum.jl/Energy-Based/Why-Learned-Relations-Do-Not-Collapse)
>
> Theory (CT-ML wiki): [Markov Category](https://mathstruct.org/CategoryTheory-ML-Wiki/Markov-Category) · [Bayesian Inversion](https://mathstruct.org/CategoryTheory-ML-Wiki/Bayesian-Inversion)

## 1. Relations, not functions

Write $T$ for texts and $M$ for meanings, whatever represents them: a logical form, a latent vector,
a label, another text. A semantic relation is a subset $R \subseteq T \times M$, or, with uncertainty, a joint
density $p(t, m)$ whose high-density set is $R$.

- **Many texts per meaning**: the paraphrases of $m$ are the fibre $\{t : (t, m) \in R\}$.
- **Many meanings per text**: ambiguity, $\{m : (t, m) \in R\}$ with more than one element.
- **Relations between texts**: paraphrase ($t \sim t'$ when they share a meaning), translation (texts in
  two languages), entailment (an order, not an equivalence), and question and answer.

A function $T \to M$ (a classifier) or $M \to T$ (a generator) is one direction of such a relation, and loses
the other. A language model conditioned on a prompt is one slice of it: texts given a prefix.

## 2. A diffusion model as a relation

A denoiser at small noise moves a corrupted text towards the texts the model finds plausible. Its
fixed points, the texts it leaves unchanged at small noise, are the texts the model accepts.
Clamping some positions and solving for the rest is a query of the relation:
- fix a meaning's tokens (a topic, a slot filler, a constraint) and solve for the text;
- fix a text and solve for a meaning's coordinates;
- fix two texts' shared slots and ask whether a joint solution exists.

The relation is the set of all such solutions, and the network is one way to answer queries
of it ([[How a Diffusion Language Model Generates]] §4).

**Composition is a product.** Two relations on overlapping variables combine by multiplying their
densities, which adds their energies. For example: a fluency relation on the text, a content
relation between the text and a meaning, a style relation between the text and a style label.
The text then has to satisfy all of them, and each part can be learned separately. That is what
[[Assembling a Language Model from Implicit Learners]] builds, and the product's smoothing bias is
its main known cost (§3 there).

## 3. What this does and does not give

- **It gives a common interface.** Generation, understanding, checking and editing are queries of
  one object. A constraint added at query time is a factor added to the product, not a retraining.
- **It does not give the meanings.** Which $M$ to use is open. It could be latent coordinates
  learned with the text, another text (meaning as paraphrase class), or a formal representation.
  The relational view only says how $T$ and $M$ are tied once both are there.
- **A learned relation can be degenerate.** A relation that accepts every text is trivially
  consistent with any data. Lenticulum's analysis of when learned relations collapse applies
  unchanged: a part must be a normalised density in its data channels, or be trained by
  comparison (denoising is a comparison against injected noise). See
  [Why Learned Relations Do Not Collapse](https://mathstruct.org/Lenticulum.jl/Energy-Based/Why-Learned-Relations-Do-Not-Collapse).
- **Spurious answers.** The stable roots of a smoothed relation include points off the data, and
  near-by branches merge. Lenticulum measures this on small relations
  (VariationalDiffusion's `examples/calibration.md`). For text that would mean fluent-looking
  non-solutions and lost rare readings.

Related: [[Diffusion Language Models]], [[Embeddings in a Diffusion Language Model]],
[[Factor Graphs against Mixtures of Experts and Agent Chains]]
