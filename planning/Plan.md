# northofwine.no

## Background

- Website for North of Wine AS, a Norwegian wine importer based in Trondheim.

## Stack

- Contentful → Jekyll → GitHub Pages.
- Content is authored and edited in Contentful.
- Build triggers:
  - Contentful publish event → fetch fresh content, rebuild site.
  - Push to `main` branch.
- Auto-build on Contentful publish can be disabled, to avoid overlapping builds during bulk edits.
- No staging pipeline — deploys straight to production. The old setup's `now-web-staging` webhook is not carried over.
- Hosted under the FELM-AS GitHub organization, with a custom domain.
  - The current production repo (`northofwine/northofwine.github.io`) moves to FELM-AS when the new site is ready.
  - DNS: correct records (A/ALIAS, or CNAME for a subdomain) pointing at GitHub Pages, with "Enforce HTTPS" enabled once the certificate issues.
- Contentful content model already exists and is used as-is — templates match existing fields, no redesign.
- Contentful fetch: based on the `github-pages-contentful` template (custom Jekyll `Generator` + `contentful.rb` client — not the archived `jekyll-contentful-data-import` gem).
  - Resolves the Product → Manufacturer reference field and exposes every Contentful field directly — no per-field mapping code needed.
  - The template's one-entry-per-page model applies only to Product (has a `slug` field); Manufacturer and Person are fetched as data only, no detail pages.
  - Static filter/listing pages (per product type, per manufacturer country, per manufacturer) need new generator code on top of the template — it has no aggregation/grouping support out of the box.
  - Credentials (space ID, access token, environment) via GitHub Actions secrets, not committed to the repo.

## Content

- Only Product, Manufacturer, and Person are modeled in Contentful. Page copy (Hjem intro, Om oss text) and site-wide settings (footer contact info, social links) stay as static Jekyll content/data.
- Full field-by-field reference: `Contentful-Content-Model.md`.
- Most content already exists; some entries still need to be added before launch.
- Existing entries need a data-quality pass: consistent formatting, complete required fields.
- A discontinued product is unpublished in Contentful — removed from the built site entirely, no "unavailable" state.

## Layout

- Header, sidebar (navigation), main content area, footer.
- On small screens, sidebar stacks above main content (matches current site).

## Pages

- **Hjem** (`/`)
  - No header — sidebar is the main navigation.
  - Company name + short intro text.
- **Utvalg** (product catalog)
  - Lists all products.
  - Sidebar filters by product type (e.g. "Alle viner", "Rødvin", "Hvitvin", "Tokaj"); a product can belong to more than one filter (see Filter component).
  - Filtering is static, pre-built pages per filter value (e.g. `/utvalg/rodvin/`), generated at build time.
    - Pro: SEO-friendly, shareable links, no client-side JS.
    - Con: full page load per filter change, more generated pages.
- **Utvalg/<product>** (product detail)
  - Product description + full details: grape composition (with %), volume, alcohol %, SKU, production notes.
  - Sensory profile: appearance, aroma, taste, plus graphical 1–12 ratings for three axes — matching Vinmonopolet's own product pages, not all four at once: fullness (body) and freshness (acidity) are always shown, plus a third axis that depends on wine type — tannins for red wine (`productTypeName: Rødvin`), sweetness for every other type. Existing feature, must be preserved.
  - Food pairing suggestions.
  - Links to the manufacturer's entry on Produsenter (anchor link), mirroring the current site.
  - Sidebar: breadcrumb + product image.
- **Produsenter** (manufacturers)
  - Lists all manufacturers.
  - Sidebar filters by country: fixed set of 13 countries (see Filter component).
  - No manufacturer detail page — represented as a card only.
  - Manufacturer card links to a static per-manufacturer product listing (e.g. `/produsenter/<slug>/viner/`), built from products' required `manufacturer` reference field.
  - Product detail pages link back here to the manufacturer's card (anchor link).
- **Om oss** (about)
  - Company text + list of people.
  - Absorbs contact info — no separate Kontakt page/nav item.

## Components

### Global

- **Header**
  - Home button.
  - Menu button.
- **Footer**
  - Contact emails: `post@`, `faktura@` (`ordre@` intentionally dropped).
  - Business info: address, org. number.
  - Social buttons: Facebook, Instagram.
  - Helsenorge alcohol-advertising disclaimer (link).
- **Button**
  - Variants: Strong, Subtle.
  - Usable as a nav list item.
  - Optional icon, left or right.

### Navigation

- **Menu**
  - Top-level nav: Hjem, Utvalg, Produsenter, Om oss.
  - Opened via header menu button.
  - On Hjem: shown in sidebar as hero content.
  - Elsewhere: shown as an overlay.
- **Filter**
  - Products: `productTypeName`, `webProductTypeName` (when set).
    - Flat sibling values, not a hierarchy.
    - A product with both set appears on both filter pages (e.g. `productTypeName: Hvitvin` + `webProductTypeName: Tokaj` → listed on `/utvalg/hvitvin/` and `/utvalg/tokaj/`).
    - `webProductTypeName` values don't necessarily map to one parent `productTypeName`.
    - `subProductTypeName`, `productGroupName`, `mainProductTypeName` are Vinmonopolet classification fields, not used for filtering — Vinmonopolet has no "Tokaj" category, hence `webProductTypeName`.
  - Manufacturers, by country: `country` is a fixed enum of 13 values (Frankrike, Italia, Tyskland, Østerrike, Spania, Portugal, Ungarn, Chile, Argentina, Australia, New Zealand, USA, Norge) — one static page per value.
- **Breadcrumb**
  - `<page> / <productTypeName> / <webProductTypeName>` when both are set, otherwise `<page> / <productTypeName>`.

### Cards

- **Product**
  - Metadata:
    - `productTypeName` + `webProductTypeName` (when set), shown together (e.g. "Hvitvin · Tokaj").
    - `country`, `region`.
  - Image, name.
  - Button group: sales price (only if `productId` and `salesPrice` exist), arrow-right icon. Only `salesPrice` (Vinmonopolet retail price) is shown — `salesPriceHoreca` (trade price) is never public, given on request/by sales pitch.
  - Entire card links to the product detail page.
- **Manufacturer**
  - Image, logo, name.
  - Link (external, opens in a new tab).
  - Description.
  - Links to that manufacturer's product listing (see Produsenter).
- **Person**
  - Image, name, email, phone, description.

## Other

- **404 page**: no redirect from old `/kontakt.html` (low traffic) — custom 404 with header/sidebar/footer, friendly message, relevant links.
- **Images**: resized via the [Contentful Images API](https://www.contentful.com/developers/docs/concepts/images/#resizing-images); listing pages (especially the unfiltered "Alle viner" view) lazy-load images.
- **Favicon** and other site icons required.
- **Web fonts**: self-hosted, not loaded from a third-party CDN (e.g. Google Fonts) — avoids the same GDPR/IP-transfer issue that ruled out Google Analytics (see Analytics).

## Error Handling

- Build-time: an entry missing a field the template depends on is skipped with a build warning, not a failed build.
- `grapeDesc` and `grapePct` are stored as two parallel arrays (not paired objects) — templates must zip them by index and handle mismatched lengths gracefully rather than erroring.
- Image resizing failures fall back to the original image.
- Client-side: missing/broken images fall back to a placeholder.
- Missing/removed pages are handled by the 404 page (see Other).

## Testing

- No separate pre-launch QA phase — testing happens during development and code review.
- CI (GitHub Actions) runs on every build:
  - Link checking (e.g. `html-proofer`) catches broken internal/external links before they ship — e.g. the current site's Facebook/Instagram footer links, which lack a full scheme + domain and resolve as broken relative links. Contentful already validates this for the Manufacturer `link` field; site-wide social links live outside Contentful (e.g. Jekyll config) and need the same check enforced here.
  - The build fails only on unexpected errors, not missing content fields (see Error Handling).

## Formatting

- Prices: Norwegian convention — comma decimal separator, `kr` suffix (e.g. "550,00 kr").
- Alcohol %, volume, and sensory scale values (1–12) formatted per Norwegian numeric convention.
- **Hyphenation**: long product and manufacturer names need per-name hyphenation.
  - Set the `lang` attribute on both the product name element and the manufacturer name element using the manufacturer's `country` (a fixed enum) — not the product's own free-text `country` field, which isn't guaranteed to match spelling-wise. Looked up via the same explicit country→language lookup table (not an assumed 1:1 mapping).
  - The current 13-value country enum maps 1:1 to a single language each (e.g. Frankrike → fr, Tyskland → de, USA → en) — no ambiguous cases today. If the enum ever grows to include a genuinely multilingual country (e.g. Switzerland, Belgium), a fallback will need to be defined then.
  - Separate from the site-wide UI locale (see Internationalization) — affects only that name's hyphenation/pronunciation.

## Internationalization

- Norwegian only at launch.
- English (and other languages) supported later via Contentful locales.
- URL convention reserved now: default locale (`nb`) at root (`/utvalg/`), other locales prefixed (`/en/utvalg/`).
- Jekyll templates loop over locales, even with only one populated at launch.
- The Contentful fetch pipeline (see Stack) has no locale support yet — extending it for multi-locale entries is part of this work.
- Header/footer reserves space for a future language switcher.

## Accessibility

- Alt text required on all product/manufacturer/person images (from Contentful where possible).
- Header menu overlay fully keyboard-operable: focus trapping, Escape to close, visible focus states.
- Product-name and manufacturer-name `lang` attributes (see Formatting) also aid screen-reader pronunciation.

## SEO / Social Sharing

- Hand-rolled `_includes/seo.html` (not the `jekyll-seo-tag` gem — deliberately excluded, since its defaults assume blog-shaped fields like a plain string `image` that don't hold for this content model): title, description, Open Graph/Twitter Card tags per page, reading only fields every page already has (`page.title`, rendered `content`) or the generic `page.social_image` alias.
  - Product pages: own name/description/image.
  - Manufacturer/Om oss/Hjem: page-specific defaults.
  - Site-wide fallback image for pages without one.
- Hand-rolled `sitemap.xml` (not the `jekyll-sitemap` gem, same reasoning): loops `site.pages` and works off any page's `.url`, so static filter pages and product/manufacturer pages are covered automatically with no per-collection code.
- `robots.txt` points at `sitemap.xml`.

## Analytics

- No cookie-based/personal-data analytics — avoids GDPR consent-banner requirement.
- GoatCounter: free, open-source, cookie-less.
  - Tracks page views, referrers, country-level location (from IP, not stored).
  - No PII, no consent banner required.
  - Snippet on every page, including 404.
