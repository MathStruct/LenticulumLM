import { siteLayout } from "./mathstruct/layout"

// The footer links back to the API documentation (the Documenter site under api/) and to the
// repository; every note has a giscus comment thread (GitHub Discussions), as in Lenticulum's
// vault. A single note opts out with `comments: false` in its frontmatter.
export const { sharedPageComponents, defaultContentPageLayout, defaultListPageLayout } =
  siteLayout({
    footerLinks: {
      // set by docs/make.jl through docs/site/build.sh
      "API documentation":
        process.env.VAULT_API_URL ?? "https://mathstruct.org/LenticulumLM/api/dev/",
      GitHub: "https://github.com/MathStruct/LenticulumLM",
    },
    // a giscus comment thread on every page (GitHub Discussions, category Announcements)
    comments: {
      repo: "MathStruct/LenticulumLM",
      repoId: "R_kgDOVHrm6w",
      category: "Announcements",
      categoryId: "DIC_kwDOVHrm684DJXDI",
    },
  })
