import { siteLayout } from "./mathstruct/layout"

// The footer links back to the API documentation (the Documenter site under api/) and to the
// repository. Lenticulum's vault also has a giscus comment thread per note; this one gets one
// once the repository has Discussions enabled and its giscus ids are added here as `comments`.
export const { sharedPageComponents, defaultContentPageLayout, defaultListPageLayout } =
  siteLayout({
    footerLinks: {
      // set by docs/make.jl through docs/site/build.sh
      "API documentation":
        process.env.VAULT_API_URL ?? "https://mathstruct.org/LenticulumLM/api/dev/",
      GitHub: "https://github.com/MathStruct/LenticulumLM",
    },
  })
