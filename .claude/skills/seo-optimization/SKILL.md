---
name: seo-optimization
description: Search-engine optimization for any web-facing project — classic HTML sites, GitHub Pages, static sites, documentation sites, landing pages, blogs, Next.js, Astro, Hugo, Jekyll, VuePress, VitePress, React, Vue, Svelte, Angular, or any other web framework. Covers on-page HTML (title, meta description, canonical, robots, lang, charset, viewport, heading hierarchy, semantic HTML, alt text, internal linking), Open Graph, Twitter Cards, JSON-LD/schema.org structured data (Organization, Person, Article, FAQPage, BreadcrumbList, Product, SoftwareApplication, WebSite, WebPage), technical SEO (robots.txt, sitemap.xml, canonical URLs, redirects, clean URLs, broken links, Core Web Vitals), GitHub Pages specifics (base URL, 404 page, social preview, favicon, RSS), content SEO (keyword coverage, search intent, readability), and accessibility overlap (ARIA, alt text, contrast, keyboard nav). Triggers automatically whenever HTML, Markdown, JSX, TSX, Vue, Svelte, or Astro web content exists or is about to be created/changed and the user is discussing search visibility, meta tags, sitemap, robots.txt, Open Graph, structured data, or "SEO" in any form — offer to run it, then run on confirmation. Also invoke on explicit request: "optimize SEO", "improve search ranking", "add meta tags", "add structured data", "audit SEO".
---

# SEO optimization for web projects

Optimizes how well a web project is found, understood, and indexed by search engines — Google,
Bing, Yahoo, DuckDuckGo, Brave Search, Startpage, MetaGer, Ecosia, and anything built on the
Google/Bing indexes. Applies to any web-facing project: plain HTML, GitHub Pages, static site
generators (Jekyll, Hugo, Astro, VuePress, VitePress), and app frameworks (Next.js, React, Vue,
Svelte, Angular) alike.

**Never destructive.** Before any non-trivial change, state: why it helps SEO, what the concrete
benefit is, and which files will change. Small, mechanical fixes (a missing `alt`, a duplicate
title) can just be fixed and reported.

## 1. On-page HTML

Check every page/template for:
- `<title>` — unique per page, ~50–60 chars, primary keyword near the front, no duplicates
  site-wide.
- `<meta name="description">` — unique per page, ~120–158 chars, states the page's value, no
  keyword stuffing.
- `<link rel="canonical">` — points at the preferred URL for every page (self-canonical by
  default); critical when a static-site generator can emit the same content at more than one URL
  (trailing slash, `/index.html`, pagination).
- `<meta name="robots">` — only where indexing should be restricted (`noindex`, `nofollow`); most
  pages need none (indexable by default).
- `<html lang="...">` — correct, present on every page; a multi-language site sets it per
  language and adds `hreflang` alternates.
- `<meta charset="utf-8">` — first child of `<head>`.
- `<meta name="viewport" content="width=device-width, initial-scale=1">` — mobile-friendliness is
  a ranking factor.
- **Heading hierarchy** — exactly one `<h1>` per page (the page's real topic, not the site name),
  logical `h2`/`h3` nesting with no level skipped, headings describe the section they introduce.
- **Semantic HTML** — `<nav>`, `<main>`, `<article>`, `<section>`, `<aside>`, `<header>`,
  `<footer>` over generic `<div>` soup; lists (`<ul>`/`<ol>`) and tables (`<table>`) for actual
  list/tabular content, not layout.
- **Alt text** — every `<img>` gets descriptive `alt` (empty `alt=""` only for pure decoration);
  never the filename, never "image of...".
- **Internal linking** — every page reachable within a few clicks from the home page; descriptive
  link text (never "click here"); related-content links between pages that logically connect.

## 2. Open Graph & Twitter Cards

Every shareable page (at minimum: home, articles/posts, docs landing pages) gets:
```html
<meta property="og:title" content="…">
<meta property="og:description" content="…">
<meta property="og:image" content="https://.../absolute-image-url.png">
<meta property="og:url" content="https://.../canonical-page-url">
<meta property="og:type" content="website"> <!-- or "article" for posts -->
<meta name="twitter:card" content="summary_large_image">
<meta name="twitter:title" content="…">
<meta name="twitter:description" content="…">
<meta name="twitter:image" content="https://.../absolute-image-url.png">
```
`og:image`/`twitter:image` must be absolute URLs (not relative) — social crawlers don't resolve
relative paths against the page URL reliably.

## 3. Structured data (JSON-LD, schema.org)

Add a `<script type="application/ld+json">` block with the type(s) that fit the page — don't add
types that don't genuinely describe the content:

| Page is... | schema.org type |
|---|---|
| the whole site | `WebSite` (add `SearchAction` if there's an internal search) |
| any page | `WebPage` (or a more specific subtype below) |
| an article/blog post | `Article` / `BlogPosting` |
| an FAQ section | `FAQPage` with `mainEntity: [Question/Answer, ...]` |
| a nav trail | `BreadcrumbList` |
| a product page | `Product` (with `offers`, `aggregateRating` if real data exists) |
| a company/org site | `Organization` (logo, sameAs social links) |
| a local business | `LocalBusiness` (address, hours, geo) |
| a personal site/portfolio | `Person` |
| a tool/app/library's site | `SoftwareApplication` (`applicationCategory`, `operatingSystem`) |

Never fabricate data (ratings, prices, availability) to fill a schema — invalid/misleading
structured data risks a manual action from Google. Only include fields you can back with real
content on the page.

## 4. Technical SEO

- **`robots.txt`** at the site root — allow crawling by default; disallow only build artifacts,
  admin paths, or duplicate-content paths; always include a `Sitemap:` line pointing at
  `sitemap.xml`.
- **`sitemap.xml`** — every indexable page listed, `lastmod` accurate, no 404s/redirects inside
  it. Static-site generators usually have a plugin for this (`jekyll-sitemap`,
  `next-sitemap`, `astro-sitemap`, `@vuepress/plugin-sitemap`, …) — prefer that over hand-rolling.
  Regenerate whenever pages are added/removed/renamed.
- **Canonical URLs** — one canonical form per piece of content (decide on trailing-slash-or-not,
  `www` vs. apex, `http` vs `https`, and redirect every other variant to it with a 301).
  Verify with the `<link rel="canonical">` from §1 lines up with what's actually served.
- **Redirects** — old URLs that changed get a 301 (never a 302 for a permanent move); no redirect
  chains (A→B→C — collapse to A→C).
- **Clean URLs** — human-readable slugs (`/blog/2026/seo-basics`, not `/p?id=1284`); no session
  IDs or tracking params in canonical/indexed URLs.
- **Broken links** — crawl the built site (or use the framework's own link-checker) before
  shipping; fix or remove dead internal links, flag dead external ones.
- **Images** — lazy-load below-the-fold images (`loading="lazy"`), serve appropriately sized
  images (no 4000px image displayed at 400px), modern formats (`webp`/`avif`) where the pipeline
  supports it.
- **Core Web Vitals / performance** — flag render-blocking scripts/styles, oversized JS bundles,
  missing `width`/`height` on `<img>` (layout shift), and unoptimized fonts (missing
  `font-display: swap`); these affect ranking, not just UX.
- **Indexability sanity check** — nothing indexable is accidentally blocked by `robots.txt`, a
  stray `noindex`, or a `canonical` pointing at the wrong page.

## 5. GitHub Pages specifics

When the project is (or includes) a GitHub Pages site:
- **Base URL** — `url`/`baseurl` in `_config.yml` (Jekyll) or the framework's equivalent match the
  actual published path (`https://user.github.io` vs. `https://user.github.io/repo`); every
  internal link and asset path respects it.
- **`sitemap.xml`** — `jekyll-sitemap` (or the generator's equivalent) enabled and producing
  correct absolute URLs under the real base URL.
- **`robots.txt`** — present at the published root, not just the repo root, if `baseurl` is a
  subpath.
- **404 page** — a real `404.html` (GitHub Pages serves it automatically); helps both UX and
  avoids soft-404 confusion for crawlers.
- **Canonicals & Open Graph** — same rules as §1/§2, with URLs built from the real `baseurl`.
- **Favicon** — present, referenced from every page.
- **Social preview image** — set in the GitHub repo settings (Settings → General → Social
  preview) in addition to `og:image` on the pages themselves.
- **RSS/Atom feed** — add one (`jekyll-feed` or equivalent) when the site has a blog/changelog —
  free discoverability channel, low effort.

## 6. Content SEO

- **Keyword coverage** — the page's real topic and the terms a user would actually search for are
  present in the title, first paragraph, and at least one heading — without stuffing. Prefer
  natural language and synonyms/related terms over repeating the exact phrase.
- **Search intent** — match the content type to what someone searching the term actually wants
  (a how-to page for a "how to X" query, a comparison for "X vs Y", reference docs for an API
  name).
- **Readability** — short paragraphs, active voice, one idea per paragraph, no unexplained jargon
  before it's introduced.
- **FAQs** — where genuinely useful (not padding), add an FAQ section — it doubles as `FAQPage`
  structured-data content (§3) and often earns a rich result.
- **Internal links & CTAs** — link out to related pages using descriptive anchor text; every
  page has a clear next action (docs → "try it", blog → related post, landing → signup/install).

No keyword over-optimization — natural, accurate wording always wins over density.

## 7. Accessibility (overlaps with SEO)

- **ARIA** — landmark roles only where semantic HTML can't express the structure; never
  ARIA-over-semantic-HTML.
- **Alt text** — see §1; also caption/describe complex images (charts, diagrams) meaningfully.
- **Contrast** — text meets WCAG AA contrast ratios against its background.
- **Keyboard operability** — every interactive element reachable and operable via keyboard, a
  visible focus state, sensible tab order.

## 8. Before finishing — quality check

Verify, and fix what fails:
- [ ] HTML validates (no unclosed tags, no duplicate IDs)
- [ ] every page has exactly one `<h1>`, no skipped heading levels
- [ ] no duplicate `<title>` or `<meta description>` across pages
- [ ] no missing `alt` on content images
- [ ] structured data is valid JSON-LD and matches real page content (spot-check with a
      schema.org validator if one is available in the project's tooling)
- [ ] every indexable page has a canonical, isn't blocked by `robots.txt`, and appears in
      `sitemap.xml`
- [ ] Open Graph/Twitter images are absolute URLs

## 9. Output: SEO report

After making changes (or when asked for an audit without changes), report:
1. **What was fixed** — concrete list, file by file.
2. **What's still open** — issues found but not fixed (e.g. missing real content for a schema
   field, a design decision needed from the user, a performance fix outside this skill's scope).
3. **Priority** — order remaining items by expected impact (indexability blockers first, then
   structured data / social previews, then content-level polish).
4. **Forward-looking recommendations** — what to keep doing for new pages/content going forward
   (e.g. "every new blog post needs its own `og:image` and a canonical").
