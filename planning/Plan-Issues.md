# northofwine.no — Issue Breakdown

Regenerated from the current Plan.md (supersedes the earlier version of this file). Numbered for cross-referencing only — renumber as needed when pasted into GitHub. Each entry is a ready-to-paste issue (title + body).

---

## Foundation & Infrastructure

### 1. Scaffold the Jekyll project
**Body:** Set up the Jekyll project with the header/sidebar/main-content/footer layout. Sidebar stacks above main content on small screens (matches current site).
**Acceptance criteria:**
- Jekyll builds locally with placeholder layout showing header, sidebar, content, footer
- Responsive stacking verified at mobile width
**Depends on:** none

### 2. Contentful → Jekyll data pipeline
**Body:** Pull Product, Manufacturer, and Person entries from Contentful (existing content model, used as-is — see `Contentful-Content-Model.md`) at build time, based on the `github-pages-contentful` template (custom Jekyll `Generator` + `contentful.rb` client — not the archived `jekyll-contentful-data-import` gem). Product gets one generated page per entry (via its `slug` field); Manufacturer and Person are fetched as data only, consumed by other pages/generators — neither gets a detail page.
**Acceptance criteria:**
- Build produces per-entry Product pages and Manufacturer/Person data, matching real field names (e.g. `productTypeName`, `webProductTypeName`, `salesPrice`)
- Product → Manufacturer reference field resolves to the linked manufacturer's own fields (no separate lookup step needed in templates)
- Page copy (Hjem intro, Om oss text) and site settings (footer contact info, social links) are handled separately as static Jekyll content, not pulled from Contentful
- Contentful credentials (space ID, access token, environment) are stored as GitHub Actions secrets, not committed to the repo
**Depends on:** #1

### 3. GitHub Actions build & deploy pipeline
**Body:** Build (via #2) and deploy to GitHub Pages under FELM-AS on push to `main` and on Contentful publish webhook. Provide a toggle to disable the Contentful-triggered auto-build during bulk edits. No staging pipeline — deploys straight to production; the old `now-web-staging` webhook is not carried over.
**Acceptance criteria:**
- Push to main triggers build + deploy
- Contentful publish triggers build + deploy
- Auto-build can be disabled with one step
**Depends on:** #1, #2

### 4. Custom domain & DNS under FELM-AS
**Body:** Move the production repo (currently `northofwine/northofwine.github.io`) to the FELM-AS GitHub organization. Configure DNS (A/ALIAS records, or CNAME for a subdomain) pointing at GitHub Pages, and enable "Enforce HTTPS" once the certificate issues.
**Acceptance criteria:**
- northofwine.no resolves to the FELM-AS-hosted site over HTTPS
**Depends on:** #3

### 5. Self-hosted web fonts
**Body:** Bundle and self-host all web fonts rather than loading from a third-party CDN (e.g. Google Fonts) — avoids the same GDPR/IP-transfer issue that ruled out Google Analytics.
**Acceptance criteria:**
- No requests to third-party font CDNs in the built site
**Depends on:** #1

---

## Content & Data

### 6. Contentful data-quality cleanup pass
**Body:** Review existing Product/Manufacturer/Person entries for consistent formatting and complete fields the templates depend on — e.g. Manufacturer `country` (needed by #8/#14/#26), messy Product `country` values (typos, stray whitespace/punctuation), and unresolved `manufacturer` references.
**Acceptance criteria:**
- Known gaps (missing Manufacturer `country`, inconsistent Product `country` values, unresolved Product→Manufacturer references) are reviewed and either fixed or explicitly deferred
**Depends on:** none (can run in parallel with build work)

### 7. Add missing Contentful entries
**Body:** Add any products/manufacturers/people that exist on the current site but are missing from Contentful, before launch.
**Depends on:** #6

### 8. Country → language lookup table
**Body:** Build the lookup table mapping Manufacturer `country` (a fixed 13-value enum: Frankrike, Italia, Tyskland, Østerrike, Spania, Portugal, Ungarn, Chile, Argentina, Australia, New Zealand, USA, Norge) to a language code, for the `lang` attribute used in Hyphenation (#26). Today's 13 values map 1:1 to a single language each; revisit only if the enum grows to include a genuinely multilingual country.
**Depends on:** #2

---

## Global Components

### 9. Header component
**Body:** Home button + menu button (opens the Menu overlay, see #12).
**Depends on:** #1

### 10. Footer component
**Body:** Contact emails `post@` and `faktura@` (`ordre@` intentionally dropped), business info (address, org. number), social buttons (Facebook, Instagram), and the Helsenorge alcohol-advertising disclaimer link.
**Depends on:** #1

### 11. Button component
**Body:** Strong and Subtle variants, usable as a nav list item, with an optional icon on the left or right.
**Depends on:** #1

---

## Navigation Components

### 12. Menu component
**Body:** Top-level nav (Hjem, Utvalg, Produsenter, Om oss). On Hjem, shown in the sidebar as hero content; elsewhere, opened as an overlay via the header's menu button.
**Depends on:** #9

### 13. Filter component — products
**Body:** Filter by `productTypeName` and `webProductTypeName` (when set) as flat sibling values, not a hierarchy — a product with both set appears on both static filter pages (e.g. `productTypeName: Hvitvin` + `webProductTypeName: Tokaji` → listed on `/utvalg/hvitvin/` and `/utvalg/tokaji/`). `subProductTypeName`, `productGroupName`, and `mainProductTypeName` are Vinmonopolet classification fields and are NOT used for filtering.
**Acceptance criteria:**
- Each distinct `productTypeName`/`webProductTypeName` value has its own static, indexable URL
- A product with both fields set appears on both corresponding pages
**Depends on:** #2

### 14. Filter component — manufacturers by country
**Body:** One static page per country value (13 fixed values, see #8) under Produsenter.
**Acceptance criteria:**
- Each of the 13 country values has its own static URL (e.g. `/produsenter/frankrike/`) listing only manufacturers from that country
**Depends on:** #2

### 15. Breadcrumb component
**Body:** Pattern `<page> / <productTypeName> / <webProductTypeName>` when both are set on the current product, otherwise `<page> / <productTypeName>`.
**Depends on:** #13

---

## Card Components

### 16. Product card
**Body:** Metadata (`productTypeName` + `webProductTypeName` when set, shown together e.g. "Hvitvin · Tokaji"; `country`; `region`), image, name, and a button group showing sales price only if `productId` and `salesPrice` both exist (only `salesPrice` — the Vinmonopolet retail price — is ever shown; `salesPriceHoreca` is never public) plus an arrow-right icon. Entire card links to the product detail page. Product name carries the `lang` attribute (see #26).
**Depends on:** #2, #8

### 17. Manufacturer card
**Body:** Image, logo, name (with `lang` attribute, see #26), external link (opens in a new tab), description, and a link to that manufacturer's product listing (#23). No manufacturer detail page.
**Depends on:** #2, #8

### 18. Person card
**Body:** Image, name, email, phone, description.
**Depends on:** #2

---

## Pages

### 19. Hjem (home) page
**Body:** No header — sidebar is the sole navigation (via Menu, #12). Company name + short intro text.
**Depends on:** #12

### 20. Utvalg (catalog) page + type filter pages
**Body:** Full product listing plus the static per-type/per-web-type filter pages (#13), built with the Product card (#16).
**Depends on:** #13, #16

### 21. Utvalg/<product> detail page
**Body:** Product description and full details: grape composition (with %, zipping `grapeDesc`/`grapePct` — see #29), volume, alcohol %, SKU, production notes. Sensory profile: appearance, aroma, taste, plus the graphical 1–12 ratings — three axes, not all four at once, matching Vinmonopolet's own product pages: fullness (body) and freshness (acidity) always shown, plus tannins for red wine (`productTypeName: Rødvin`) or sweetness for every other type. This is an existing, distinctive feature of the current site and must be preserved. Food pairing suggestions. Sidebar: breadcrumb (#15) + product image. Links to the manufacturer's card on Produsenter via anchor link.
**Acceptance criteria:**
- Fullness and freshness always render; the third axis renders as tannins for `Rødvin` and sweetness for every other `productTypeName`
- Grape composition displays correctly even if `grapeDesc`/`grapePct` arrays are mismatched in length (see #29)
**Depends on:** #15, #16

### 22. Produsenter (manufacturers) page + country filter pages
**Body:** Full manufacturer listing plus the static per-country filter pages (#14), built with the Manufacturer card (#17). Receives inbound anchor links from product detail pages (#21).
**Depends on:** #14, #17

### 23. Per-manufacturer product listing page
**Body:** For each manufacturer, a static page (e.g. `/produsenter/<slug>/viner/`) listing that manufacturer's own products, built from products' required `manufacturer` reference field. Resolves the product↔manufacturer cross-linking requirement, mirroring and extending the current site.
**Depends on:** #2, #16, #22

### 24. Om oss (about) page
**Body:** Company text + list of people (Person card, #18). Absorbs contact info — no separate Kontakt page/nav item.
**Depends on:** #18

### 25. Custom 404 page
**Body:** `404.html` at the site root. Same header/sidebar/footer as the rest of the site, a friendly "page not found" message, and links to Utvalg, Produsenter, and Om oss. No redirect from the old `/kontakt.html` — low traffic doesn't justify one.
**Depends on:** #9, #10, #12

---

## Language & Formatting

### 26. Hyphenation / `lang` attribute
**Body:** Set the `lang` attribute on both the product name element and the manufacturer name element, using the manufacturer's `country` (via the lookup table, #8) — not the product's own free-text `country` field, which isn't guaranteed to match spelling-wise. Enables correct hyphenation and (see #32) screen-reader pronunciation.
**Depends on:** #8

### 27. Internationalization groundwork
**Body:** Norwegian only at launch; English (and other languages) later via Contentful locales. Reserve the URL convention now: default locale (`nb`) stays at the root (`/utvalg/`), other locales get a path prefix (`/en/utvalg/`). Templates loop over locales even with only one populated. Reserve a spot in the header/footer for a future language switcher. The Contentful fetch pipeline (#2) has no locale support yet — extending it for multi-locale entries is part of this work.
**Depends on:** #2

### 28. Number/price formatting
**Body:** Norwegian convention throughout: comma decimal separator, `kr` suffix for prices (e.g. "550,00 kr"); alcohol %, volume, and the 1–12 sensory scale values formatted the same way.
**Depends on:** #16

---

## Quality & Resilience

### 29. Build-time error handling
**Body:** An entry missing a field the template depends on is skipped with a build warning, not a failed build. `grapeDesc` and `grapePct` are two parallel arrays (not paired objects) — zip them by index and handle mismatched lengths gracefully rather than erroring. Image resizing failures fall back to the original image.
**Depends on:** #2

### 30. Client-side error handling
**Body:** Missing/broken product, manufacturer, or person images fall back to a placeholder image.
**Depends on:** #16, #17, #18

### 31. CI link checking
**Body:** Add a link checker (e.g. `html-proofer`) to the GitHub Actions build (#3) to catch broken internal/external links before they ship — e.g. the current site's Facebook/Instagram footer links, which are missing a full scheme + domain and resolve as broken relative links. Contentful already validates this for the Manufacturer `link` field; site-wide social links live outside Contentful (e.g. Jekyll config) and need the same check enforced in CI.
**Depends on:** #3, #10

### 32. Accessibility pass
**Body:** Alt text on all product/manufacturer/person images (from Contentful where possible). Header menu overlay (#12) fully keyboard-operable: focus trapping, Escape to close, visible focus states. Product-name and manufacturer-name `lang` attributes (#26) also aid screen-reader pronunciation.
**Depends on:** #12, #26

---

## SEO & Discoverability

### 33. Wire page fields into `seo.html`
**Body:** The template's hand-rolled `_includes/seo.html` (not the `jekyll-seo-tag` gem — deliberately excluded, see Plan.md SEO section) already emits title/description/Open Graph/Twitter Card tags generically from `page.title`, rendered `content`, and `page.social_image`. Ensure Product pages get their own description and image (via `image_field` on the `product` collection if the field isn't literally `image`); Manufacturer/Om oss/Hjem get sensible page-specific defaults; confirm the site-wide fallback image applies to pages without one.
**Depends on:** #20, #21, #22, #24

### 34. Confirm sitemap.xml/robots.txt coverage
**Body:** The template's hand-rolled `sitemap.xml` (not the `jekyll-sitemap` gem, same reasoning as #33) already loops `site.pages` and works off any page's `.url`, so static filter pages and product/manufacturer pages should be covered automatically once #13/#14 land, with no code changes needed. Verify that after #13/#14 land, and confirm `robots.txt` points at `sitemap.xml`.
**Depends on:** #13, #14

---

## Analytics

### 35. GoatCounter integration
**Body:** Free, open-source, cookie-less analytics. Tracks page views, referrers, and country-level location (from IP, not stored) — no PII, no consent banner required. Snippet on every page, including the 404 page (#25).
**Depends on:** #1, #25
