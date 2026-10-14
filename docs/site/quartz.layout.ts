import { PageLayout, SharedLayout } from "./quartz/cfg"
import * as Component from "./quartz/components"

// Copied over the stock `quartz.layout.ts` by `docs/site/build.sh`.
// Deliberate change from stock: the footer links back to the API documentation (the
// Documenter site this vault is deployed inside) and to the repository. Lenticulum's vault
// also has a Giscus comment thread per note; this one has none until the repository has
// Discussions enabled and its giscus repository and category ids are filled in here.

export const sharedPageComponents: SharedLayout = {
  head: Component.Head(),
  header: [],
  afterBody: [],
  footer: Component.Footer({
    links: {
      "API documentation": "../",
      GitHub: "https://github.com/MathStruct/LenticulumLM",
    },
  }),
}

export const defaultContentPageLayout: PageLayout = {
  beforeBody: [
    Component.ConditionalRender({
      component: Component.Breadcrumbs(),
      condition: (page) => page.fileData.slug !== "index",
    }),
    Component.ArticleTitle(),
    Component.ContentMeta(),
    Component.TagList(),
  ],
  left: [
    Component.PageTitle(),
    Component.MobileOnly(Component.Spacer()),
    Component.Flex({
      components: [
        { Component: Component.Search(), grow: true },
        { Component: Component.Darkmode() },
        { Component: Component.ReaderMode() },
      ],
    }),
    Component.Explorer(),
  ],
  right: [
    Component.Graph(),
    Component.DesktopOnly(Component.TableOfContents()),
    Component.Backlinks(),
  ],
}

export const defaultListPageLayout: PageLayout = {
  beforeBody: [Component.Breadcrumbs(), Component.ArticleTitle(), Component.ContentMeta()],
  left: [
    Component.PageTitle(),
    Component.MobileOnly(Component.Spacer()),
    Component.Flex({
      components: [
        { Component: Component.Search(), grow: true },
        { Component: Component.Darkmode() },
      ],
    }),
    Component.Explorer(),
  ],
  right: [],
}
