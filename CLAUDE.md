# CLAUDE.md

For developers and coding agents changing the code: how the build works (plugins, config keys, data shapes, conventions) and why it's built that way. What the site does is in [`FEATURES.md`](FEATURES.md); setup, deploying and operations are in [`README.md`](README.md); the Contentful fields are in [`Contentful-Content-Model.md`](Contentful-Content-Model.md).

## Project

This repo builds and deploys **northofwine.no**, the live website of North of Wine AS, a Norwegian wine importer in Trondheim. It's hosted under the FELM-AS GitHub organization and replaced the old site at `northofwine/northofwine.github.io`. That repo and its `northofwine` GitHub organization have since been deleted; a zip backup of the repo exists outside GitHub.

The repo started from the `github-pages-contentful` template's Contentful → Jekyll → GitHub Pages machinery, but it isn't a template anymore. It's one company's site, modified in place. The generators are still config-driven (see "Architecture"), which is why parts of this file describe options this site doesn't use.

Open work is in the [issue tracker](https://github.com/FELM-AS/northofwine-website/issues).

## Commands

- `bundle install` — install Ruby dependencies (after cloning or editing the Gemfile)
- `bundle exec jekyll serve` — local dev server at `http://localhost:4000`; loads `.env` via the `dotenv` gem
- `bundle exec jekyll build` — build the static site into `_site/`
- `bundle exec jekyll build --trace` — build with full backtraces (use this when a plugin error is unclear)
- `bundle exec htmlproofer ./_site --checks Links,Scripts --ignore-urls "/^https:\/\/northofwine\.no/" --no-enforce-https --only-4xx --ignore-status-codes 429 --assume-extension ""` — the link check CI runs (`.github/workflows/deploy.yml`) on `_site/`. `jekyll build` doesn't run it, so run it yourself after a change that touches links.

There is no test suite. CI's html-proofer check runs on the *built HTML* (not the Ruby/Liquid source) and gates the deploy. Verify a change with `bundle exec jekyll build --trace` and read the generated HTML in `_site/`; add the htmlproofer run if links could be affected.

## Architecture

The site pulls its content from Contentful at **build time**. No pages are stored as files in the repo. The generator machinery is config-driven: pointing it at a content type means editing `_config.yml`, not the plugin (see the `contentful_collections`/`contentful_data_collections` tables below). Nine plugin files split the work:

| File | Responsibility |
| --- | --- |
| `_plugins/contentful_client.rb` | Builds the `Contentful::Client` used everywhere else. |
| `_plugins/contentful_locales.rb` | Locale resolution: the `Locale` struct and `.each_locale`/`.dir_for`. Pure functions of `_config.yml`'s `contentful_locales`/`dir`, with no Jekyll dependency. |
| `_plugins/contentful_rich_text.rb` | Rich Text → HTML rendering rules. The extension point for custom embeds/markup. |
| `_plugins/contentful_serializer.rb` | Turns a `Contentful::Entry` into plain Jekyll data (a Hash for `page.data`/`site.data`, plus rendered body HTML), and holds the Markdown parser for editor text. |
| `_plugins/contentful_entries_generator.rb` | The `Jekyll::Generator` that drives the build: reads `_config.yml`, fetches entries, and turns each into a generated page or a `site.data` entry. |
| `_plugins/contentful_listing_pages.rb` | A second `Jekyll::Generator` (priority `:low`, after `contentful_entries_generator.rb`'s `:high`) that builds the Utvalg/Produsenter/Om oss listing pages. Specific to this site, not config-driven (see "Listing pages"). |
| `_plugins/contentful_url_registry.rb` | `UrlRegistry`: the URL collision check both generators share. It is seeded with the site's existing pages and names both sides when two pages land on the same URL. Fatal in production, a warning elsewhere. |
| `_plugins/i18n.rb` | `ContentfulJekyll::I18n`: looks up UI text in `_data/i18n/<locale>.yml` by dotted key (see "UI text (i18n)"). |
| `_plugins/contentful_filters.rb` | Shared Liquid filters: `t` (UI text), `dir_href` (`"/<dir>/"`, the one place templates turn a resolved collection `dir` into a URL), `json_script` (`jsonify` safe inside `<script>`), `nb_number` (Norwegian decimal comma), `country_lang` (country → language, `_data/countries.yml`), `unescape_html` (see "SEO"), `og_locale` and `strip_protocol`. |

### Connecting to Contentful

`contentful_client.rb` builds a `Contentful::Client` from the `CONTENTFUL_SPACE_ID`, `CONTENTFUL_ACCESS_TOKEN` and `CONTENTFUL_ENVIRONMENT` env vars, and returns `nil` if any is missing or blank. The environment has no `master` default, so a lost secret can't silently build from the wrong environment. A local build without credentials succeeds with no generated pages (`EntriesGenerator` logs a warning and returns early). A production build (`JEKYLL_ENV=production`, as CI sets) fails instead and names the missing variable, so a lost secret can't deploy an empty catalogue.

`CONTENTFUL_PREVIEW=true` builds against draft content: the client reads `CONTENTFUL_PREVIEW_ACCESS_TOKEN` (a separate token from the CDA one) and uses `preview.contentful.com` instead of `cdn.contentful.com`.

### How a page gets built

`EntriesGenerator#generate` (in `contentful_entries_generator.rb`) runs once per build:

1. Build the Contentful client, or bail out (see above) if credentials are missing.
2. Fetch every content type's `displayField` (see "Title" below) via `client.content_types`. This happens once per build, not per locale, since schemas aren't locale-specific.
3. For each configured locale (see "Locales"), with a fresh `EntrySerializer` per pass:
   - For each `contentful_collections` entry, fetch its entries and turn each into a `Jekyll::PageWithoutAFile` at `/<dir>/<slug>/` (`dir: ""` → site root; prefixed for a non-primary locale). Individual entries have no files on disk; they exist only as generated pages during a build.
   - For each `contentful_data_collections` entry, fetch its entries into `site.data.<name>` instead (see "Data-only collections").

Here `product` is the only page collection (`layout: product`, `dir: utvalg`). Adding a content type with pages means a `contentful_collections` entry and a layout in `_layouts/`, with no Ruby changes. A `contentful_collections` entry supports:

| Key | Required | Meaning |
| --- | --- | --- |
| `content_type` | yes | The Contentful content type id to fetch. |
| `layout` | yes | Which layout renders the page. |
| `dir` | yes | URL path prefix (`dir: ""` → site root). A Hash keyed by locale code translates it per locale (see "Locales"). |
| `order` | no | A raw [CDA order value](https://www.contentful.com/developers/docs/references/content-delivery-api/#/reference/search-parameters/order) (e.g. `fields.productShortName`). Defaults to `-sys.updatedAt`. `,sys.id` is appended unless present, and spaces around commas are removed (the CDA rejects them). |
| `body_field` | no | Which field to render as page content, if not `body` (see "Content type conventions"). |
| `image_field` | no | Which field to expose as `page.social_image` (see "SEO"), if not `image`. |

A top-level `contentful_entry_depth` (default 2) sets how deep linked entries are flattened before degrading to a stub (see "Field exposure").

Entries are fetched with `include` set to `contentful_entry_depth`, capped at the CDA's maximum of 10. Asking the CDA to resolve more levels than `EntrySerializer` flattens would only fetch unused JSON. Results come in `MAX_PAGE_SIZE` (1000, the CDA limit) pages via the shared `each_page` loop, until every entry is fetched. Pages are requested by `skip`, so `entries_query` makes the order unique with a `sys.id` tiebreaker; otherwise entries that tie on the order key could swap between requests, and one would be fetched twice and another not at all. `each_page` works with any CDA list endpoint (entries, content types, ...), since `Contentful::Array#next_page` dispatches by the resource's own type.

### Content type conventions

A page collection's content type needs a **`slug`** field (the URL segment) and a **body field**. Neither the body nor the title needs a field with a literal name:

- **Body field**: `body` by default; set `body_field` to use another field. This is required when the field is literally named `content`, since that collides with Jekyll's reserved `page.content`/`{{ content }}`. Product uses `body_field: description`.
- **Title**: `page.title` (and a linked or data-collection entry's `title`) always comes from the content type's "Entry title" setting, its `displayField` in the CDA (here `productShortName` for products and `name` for manufacturers and people). It's fetched once per build (`fetch_display_fields`) and applied in `EntrySerializer#flatten_fields`, which reads straight from `entry.fields`, so it's correct even when the displayField is also the `body_field`.

`slug` is sanitized with `Jekyll::Utils.slugify` (the normalization Jekyll uses for post permalinks) if it isn't URL-safe already, with a build warning. An entry with no `slug` is skipped with a warning naming the entry. A blank slug must never reach `build_page`, since the page would land on the bare collection `dir` (`/utvalg/`) and collide with that section's listing page.

If two pages still produce the same URL (a raw collision, or two slugs that sanitize to the same value), `UrlRegistry` (`contentful_url_registry.rb`) fails a production build with an error naming both sides, so an editor has to change a slug. Any other build logs the same message as a warning, so one bad value in Contentful doesn't block local `jekyll serve`. The registry is seeded with every existing page's URL (static files like `index.html` included) before any entry is fetched, so a collision with a static page is caught too. `contentful_listing_pages.rb` uses the same check, so a product slug matching a filter page under `/utvalg/` is caught as well.

### Rich Text rendering (`contentful_rich_text.rb`)

No field in the current content model is Rich Text: every description is a Markdown Text field. This file is here so a Rich Text body field renders if one is added. It renders a Rich Text document to HTML with the `rich_text_renderer` gem, through `RICH_TEXT_MAPPINGS`. Compared with the `BLOCKS`/`INLINES`/`MARKS` lists in `@contentful/rich-text-types`, the gem's defaults cover everything except these node/mark types, which this file adds:

- **`embedded-entry-block`/`embedded-entry-inline`**: rendered as the linked entry's title, wrapped in `<div class="embedded-entry">`/`<span class="embedded-entry">`. The title uses the same displayField resolution as everywhere else (see "Content type conventions"). It is passed in through a `display_fields` key merged into the mappings Hash the gem hands to every renderer, so this file doesn't depend on `EntrySerializer`. Without that key it falls back to a literal `title`/`name` field.
- **`strikethrough`**: a standard Contentful mark the gem lacks entirely, so it would fail the build the first time it's used. Rendered as `<s>`.
- **`entry-hyperlink`/`resource-hyperlink`**: text linked to a Contentful entry rather than a URL. Rendered as `<span class="entry-hyperlink">` with no `href`, since the renderer doesn't know the site's URL scheme.

`embedded-resource-block`/`embedded-resource-inline` (cross-space embeds) are deliberately unmapped and fail the build, like any other unmapped type, rather than render wrong. Override a key in `RICH_TEXT_MAPPINGS` to change markup, or add one for a new type.

### Field exposure (`contentful_serializer.rb`)

`EntrySerializer#flatten_fields` copies every field of an entry (except the page's body field) onto a plain Hash under its snake_cased field ID: contentful.rb symbolizes field names, so `productTypeName` becomes `page.product_type_name`. There's no allowlist, so a layout can use a new field without Ruby changes. `#serialize_field` turns SDK objects that Liquid can't call methods on into plain Hashes and Strings:

- **Strings** are stripped and NFC-normalized. Editors leave stray spaces, and a decomposed "Å" pasted from macOS would otherwise sort, group and slugify differently from the precomposed one.
- **Assets** (`Contentful::Asset`) become `{ "url", "content_type", "title", "description", "width", "height" }`. `url` is rewritten from Contentful's protocol-relative `//images.ctfassets.net/...` to `https://`. Render one with `_includes/contentful-image.html`, which resizes through the Images API and sets `width`/`height` to avoid layout shift.
  - An asset that hasn't finished processing (e.g. linked from a draft under `CONTENTFUL_PREVIEW`) has no `url`/`content_type`/`details` key in its `file` JSON. contentful.rb defines a method only for keys that are present, so the method is undefined rather than returning `nil`, and `&.` doesn't help. `#serialize_asset`'s `safe_field` checks `respond_to?` before each call.
  - `width`/`height` come from `file.details["image"]`, a plain Hash, so a non-image or unprocessed asset just reads `nil`.
- **Top-level entries**: a generated page's data and each `site.data.<name>` item both come from `#serialize_root` (`id`, `content_type`, the flattened fields at depth 0, then `updated_at` from `sys.updatedAt`). A product page and a manufacturer from `site.data.manufacturers` therefore have the same shape and link depth. A generated page also gets `layout`, `locale` (nil for the primary locale), `slug` (the sanitized one its URL uses), `social_image` and `description` (see "SEO").
- **Linked entries** (`Contentful::Entry`, e.g. a product's `manufacturer`) become the linked entry's own flattened fields plus `id` and `content_type`, so `{{ page.manufacturer.title }}` works directly. They are memoized per `(entry id, depth)` and frozen: one manufacturer is linked from many products, so it's flattened once and shared by reference, and freezing enforces that nothing downstream mutates it.
- **Depth cap**: linked entries are flattened up to `contentful_entry_depth` levels (default `EntrySerializer::DEFAULT_ENTRY_DEPTH`, 2). Rebuilding a tree from Contentful's flat, deduplicated `includes` duplicates a shared reference at every occurrence, so unbounded recursion can bloat the output. Beyond the cap, and for any link Contentful didn't resolve, an entry becomes `{ "id", "link_type" }`, the same shape as an unresolved `Contentful::Link`. Raise `contentful_entry_depth` if a reference chain needs more levels.
- **Body field**: a content type's configured `body_field` (on a `contentful_collections` or `contentful_data_collections` entry) goes through `#render_body` instead of being stringified. The content_type → field map comes from `EntriesGenerator#body_fields_for` and is passed to every `EntrySerializer`. This applies however the entry is reached (a page's own body, a data collection, or a linked entry), since all three go through `#flatten_fields`. `#render_body` renders a Rich Text Hash with the renderer above, and a String as Markdown without raw HTML (see "Data-only collections"). **Known gap**: only that one field per content type is rendered. Any other Rich Text field arrives as the raw Rich Text Hash, with embedded assets and entries left as unserialized SDK objects.

### Homepage & navigation

**`index.html`** (Hjem) is a static page with `home: true` in its front matter: the company name, intro text and a link to Utvalg, all from the i18n dictionary. That flag makes `_layouts/default.html` drop the header and render the menu in the sidebar instead (Hjem has no header; the sidebar is the nav). The layout reads it from the page's data, never from `page.url`. The same flag puts `class="hero"` on `<body>`, which `_sass/_layout.scss` turns into two columns: the menu and the intro beside it. `_sass/_components.scss` puts `assets/images/texture.png` and the `domen.svg` illustration behind the menu. The `<h1>` is `site.title` with `" of "` replaced by `<br>of&nbsp;`, so the line break and non-breaking space hold. A title without " of " renders as plain text.

Every other page gets `_includes/header.html`, whose menu button opens the same links in a native `<dialog>` (`assets/js/menu.js`). The links (`navigation/menu-items.html`) use `site.product_dir`/`manufacturer_dir`/`about_dir`, set by the listing generator.

### Listing pages (`contentful_listing_pages.rb`)

`ListingPagesGenerator` runs after `EntriesGenerator` and builds, per locale:

- **Utvalg** (`product` collection): a root page, plus one filter page per distinct `productTypeName` and `webProductTypeName` value. Both fields share one flat URL namespace (`/utvalg/rodvin/`, `/utvalg/tokaj/`), and values with the same slug, from either field, share one page listing the products of both. A value with no letters or digits to slugify (e.g. `–`) gets no page and a build warning, since it would land on the root's URL. Product pages are selected by `page.content_type` and `page.locale`.
- **Produsenter** (`manufacturer` data collection; needs `dir`): a root page plus one page per `country` that some manufacturer has.
- **Om oss** (`person` data collection; needs `dir`): one page. The person with `companyProfile: true` is the intro (`page.about_entry`); everyone else is in the team list. The build warns if there's no such person, or more than one.

Items and filter values are sorted in Norwegian alphabetical order (`nb_sort`: Æ/Ø/Å after Z, other accents folded). Items sort by `title` (the displayField). The CDA can't do this itself, since it has no collation parameter and folds Å to A. Filter slugs are transliterated to ASCII (`slugify mode: "latin"`).

It also precomputes cross-references, so templates never scan `site.pages`:

- `page.siblings`: a section's listing pages, for `navigation/filter.html`.
- `page.breadcrumb` on every product page: the root listing, then the filter pages it appears on. Used by `navigation/breadcrumb.html` and the JSON-LD BreadcrumbList.
- `page.products_by_manufacturer` on Produsenter pages.
- `page.regions` on every product page, in every locale: its region and subregion entries that have a `summary`, as `{ name, entry }`, for `_includes/region.html`. It's a step of its own, run once after the locale passes, and reads the primary locale's `site.data.regions` only. Keys are compared trimmed around `/` and case-insensitively. A product with a `region` but no `country`, or a `subRegion` but no `region`, gets a build warning, since its key can't be built.
- `site.config["<product|manufacturer|about>_dir"]` (primary locale only), for the nav.

Listing copy comes from the UI dictionary under `sections.<content_type>` (see "UI text (i18n)"):

- `menu_label`: the nav link text and the root page's title.
- `section_heading`: the listing sidebar's `<h1>`.
- `root_description`/`filter_description`: meta descriptions; `%{value}` is the filter value.
- `root_label` (optional): the root page's link in the filter list, defaulting to `menu_label`.
- `empty`: the empty-state message.

### UI text (i18n)

All site copy that isn't Contentful content lives in `_data/i18n/<locale code>.yml` (today only `nb-NO.yml`), a nested dictionary read by dotted key. That covers labels, aria-labels, empty states, the footer warning, Hjem/404 text and listing copy. Templates use the `t` filter: `{{ "menu.open" | t }}`, or with `%{name}` placeholders, `{{ "product.see" | t: title: product.title }}`. `t` picks the dictionary from `page.locale`, falling back to the primary locale (the first `contentful_locales` entry, else `site.lang`). Its output isn't escaped, so escape it wherever a placeholder carries editor content. A missing key, placeholder value or dictionary file fails the build. Plugins use the same lookup via `ContentfulJekyll::I18n.translate`.

A static page sets `title_key:` (e.g. `pages.not_found.title`) instead of `title:` in its front matter, and `description_key:` instead of `description:`; `_layouts/default.html` translates them. Hjem has no title of its own and gets `site.title`. `assets/js/image-fallback.js` and `assets/images/placeholder.svg` have empty front matter so they can use `t` too.

Adding a locale means adding its `contentful_locales` entry and a `_data/i18n/<code>.yml` with the same keys.

### Data-only collections

A `contentful_data_collections` entry (`content_type`, `name`) fetches a content type into `site.data.<name>` instead of generating pages. Here that's `manufacturer` → `site.data.manufacturers`, `person` → `site.data.people` and `region` → `site.data.regions`. `contentful_listing_pages.rb` matches a region entry by its `key` (`Italia / Piemonte / Barolo`), built from the product's `country`, `region` and `subRegion`, so a product finds its summary only when those carry Vinmonopolet's names (spacing around `/` and case aside) (see `page.regions` under "Listing pages"). `_includes/region.html` renders each summary as a `<details>`. Each entry is flattened the same way as a generated page (`EntrySerializer#serialize_root`). A build warning is logged if `name` collides with an existing `site.data` key (e.g. a `_data/<name>.yml` file), which it then overwrites. It also takes:

- **`order`**, as for `contentful_collections`.
- **`dir`**: ignored by `EntriesGenerator` (a data collection still gets no per-entry pages). `contentful_listing_pages.rb` reads it as the one source for that collection's listing pages (e.g. `dir: produsenter` for `/produsenter/`).
- **`body_field`**: which field `EntrySerializer#render_body` renders. Manufacturer's and Person's `description` both use it (`body_field: description`), as Product's does, and Region's `summary` (`body_field: summary`), so every description and summary the site shows is Markdown rendered to HTML, and templates output it directly without `escape`/`markdownify`.

  A plain Text field is parsed by `Kramdown::Parser::NoHtmlGFM` (`contentful_serializer.rb`) through Jekyll's own kramdown converter, so `_config.yml`'s `kramdown` settings apply (`hard_wrap`, Norwegian `smart_quotes`), with `auto_ids` off. The parser restricts what editor text can do:
  - an editor's `<b>` or `{::nomarkdown}` renders as literal text;
  - only `href`/`src`/`alt`/`title` attributes survive, so no `{: onclick=…}` or `{#id}`;
  - a link with a scheme other than http(s)/mailto/tel loses its `href`;
  - footnote ids are prefixed per text.

### Locales (`contentful_locales.rb`)

This site configures `contentful_locales: [nb-NO]`. The Contentful space also has an `en` locale, which the site doesn't build yet.

`ContentfulJekyll.each_locale` yields one `Locale` struct per `contentful_locales` entry, with the first as primary. The struct has `code` and `url_prefix`, plus `#primary?` (`url_prefix.nil?`) and `#data_suffix`, which is derived from `url_prefix` rather than stored, so the two can't desync. Like `.dir_for` below, it's a function of that config value alone. When `contentful_locales` is unset, it yields a single `Locale.new(nil, nil)`: no `locale` query param and no prefixes. A configured single-entry list like this site's does **not** collapse to that. It still sends `locale: nb-NO` on every query, so the site can't silently fetch whatever the space's own default locale is.

Check primary-ness with `locale.primary?`, never `code` or `url_prefix` directly. They mean different things: `code` is `nil` only when no locales are configured, while `url_prefix` is `nil` for the primary locale even when `code` is set.

With 2+ locales configured, each pass (`EntriesGenerator#generate`):

- Adds `locale: code` to every CDA query (`entries_query`), the primary locale included.
- Prefixes a non-primary locale's URLs with `/<prefix>/` (e.g. `/en/utvalg/`) and its `site.data` keys with `_<suffix>` (`site.data.manufacturers_en`, which stays valid Liquid dot-notation). The primary locale gets neither. A `contentful_locales` entry is a bare code (prefix == code) or a `{code:, prefix:}` Hash (`.locale_code_and_prefix`). The prefix is explicit rather than derived from the code, since `en-US` and `en-GB` would both shorten to `en`. `.locale_code_and_prefix` fails if `prefix` parsed as a boolean: YAML reads a bare `no`/`yes`/`on`/`off` as `true`/`false`, which is exactly the trap an unquoted `prefix: no` (Norwegian) falls into.
- Sets `page.data["locale"]` to `Locale#page_code`: the locale code for a non-primary page, `nil` for the primary locale. `contentful_listing_pages.rb` selects each locale's product pages by it. A Contentful field named `locale` (or `id`, `content_type`, `slug`, `layout`, `updated_at`) would collide with these generator-set keys.
- Gets its own `EntrySerializer`, so the memoization cache (`@entry_cache`, keyed by `(entry id, depth)`) never returns one locale's frozen fields for the same entry fetched in another.

A collection's `dir` can also be a Hash keyed by locale code (`ContentfulJekyll.dir_for`, resolved once per collection per locale pass), for when the path segment itself is translated (`produsenter` vs `producers`). `.dir_for` raises if the Hash lacks a configured locale. A locale code must exist in the Contentful space (Settings → Locales) before it can be queried: the CDA returns a 400 ("Unknown locale") otherwise.

`<html lang>` in `_layouts/default.html` is `page.locale`, else `_config.yml`'s `lang` (`nb`), else `"en"`.

A hand-written page for a non-primary locale (e.g. an `en/index.html`) needs `locale: en` in its front matter. Without it, `page.locale` is `nil`, and `t`, `<html lang>` and `og:locale` all treat it as a primary-locale page.

### SEO, sitemap, robots.txt, 404

There's deliberately no `jekyll-seo-tag`, `jekyll-sitemap` or `jekyll-feed` dependency. Their templates assume blog-shaped fields (a string `image`, a `date`), while here `image` is an asset Hash. Everything below is hand-rolled and reads only fields every page has (`title`, `url`, the rendered `content`), or a generic alias the generator sets. There's no feed: the site has no chronological content.

- **`<title>`** is `title_format` from the i18n dictionary (`"%{title} – %{site}"`), except on Hjem (`home: true`), where it's just `site.title`. `og:title`/`twitter:title` stay the bare page title, since `og:site_name` carries the brand.
- **`_includes/seo.html`** (in `default.html`'s `<head>`) emits a canonical link, a meta description, and Open Graph and Twitter Card tags. A page with `noindex: true` (404) gets `<meta name="robots" content="noindex">` instead of the canonical link and description, and is left out of the sitemap. `noindex: true` in `_config.yml` adds the robots tag to every page (canonical and description kept), for a deploy that shouldn't be indexed. robots.txt still allows crawling, since a crawler blocked by robots.txt never sees the `noindex`.
  - **Description** (`meta_description`, `og:description`, `twitter:description`): `page.description` (or a static page's translated `description_key`), else `content | strip_html | unescape_html | normalize_whitespace | truncate: 160`.
    - `EntriesGenerator#build_page` sets `page.description` to the rendered body field (unless the content type has its own `description` field), so a product's description is its description alone, not the breadcrumb and `<h1>` its layout adds.
    - Listing pages set an explicit description from the dictionary, since their `content` is a grid of cards, not prose. The `content` fallback is for static pages.
    - `unescape_html` undoes the entity escaping `strip_html` leaves behind (e.g. `&quot;`), which the final `| escape` would otherwise double-escape into `&amp;quot;`. It also turns `&nbsp;` into a space, which `normalize_whitespace` doesn't match.
  - **`og:image`/`twitter:image`**: `page.social_image.url` through the Images API, padded to 1200×630 JPG (`fit=pad`, white background) so tall bottle shots aren't cropped. It's JPG because not every link-preview crawler reads WebP.
    - The `og:image:width`/`height` tags are set, and the alt text is the asset's description, else the page title.
    - `EntriesGenerator#build_page` sets `social_image` to `page.data[collection["image_field"] || "image"]`, a generic alias, since content types name that field differently.
    - Pages without one (every listing page, Om oss, Hjem) fall back to `site.data.company.social_image` (`assets/images/og-fallback.jpg`, which must stay 1200×630), with the site title as alt.
    - `twitter:card` is `summary_large_image` when an image resolves, else `summary`.
  - **`og:locale`**: the `og_locale` filter: `page.locale`, else the primary `contentful_locales` code (not `site.lang`, which is a bare `nb`), with `-` → `_` (`nb_NO`).
  - **`og:type`**: always `website`.
- **`_includes/structured-data.html`** (JSON-LD): Organization (from `_data/company.yml`) and WebSite on Hjem, and a BreadcrumbList on product pages from the same `page.breadcrumb` as `navigation/breadcrumb.html`. There's deliberately no Product markup: prices and offers could count as alcohol advertising under alkoholloven. Values go through `json_script` (`jsonify` with `<` escaped as `\u003c`), so editor content can't close the `<script>`.
- **`sitemap.xml`** (`layout: none`) loops `site.pages` and prints `<loc>{{ p.url | absolute_url }}</loc>` for every page except:
  - `noindex` pages (404);
  - old-URL redirects (`redirect_to`);
  - `sitemap.xml`/`robots.txt` themselves (by `.name`);
  - anything under `/assets/` (Sass, JS and SVG files with front matter are Jekyll pages too).

  `<lastmod>` comes from `page.updated_at`: `EntrySerializer#serialize_root` sets it on every generated page and `site.data` entry, and `contentful_listing_pages.rb` gives each listing page the newest of its items'. Static pages have none.
- **`robots.txt`** (`layout: none`) allows everything and points at `sitemap.xml`.
- **Old-URL redirects**: `utvalg.html`, `produsenter.html` and `omoss.html` (`layout: redirect`, with the target path in `redirect_to:`) forward the old site's section URLs to `/<dir>/`, with an instant meta refresh plus a canonical link (GitHub Pages has no server-side redirects). Old product URLs (`/utvalg/<slug>`) already match. html-proofer runs with `--assume-extension ""` because its default `.html` would resolve `/utvalg/` to `utvalg.html`.
- **Icons**: `assets/images/favicon.svg` (a `#000` glyph, `#fff` under `prefers-color-scheme: dark`) and `assets/images/apple-touch-icon.png` (180 px), linked from `default.html`, plus `favicon.ico` (16/32 px) at the root. Both raster icons are white on `#000`. The `.ico` is deliberately not linked: Safari picks a linked `.ico` over the SVG, while browsers without SVG favicon support request `/favicon.ico` anyway.
- **`404.html`** is a static page. Jekyll outputs it at `/404.html`, which is where GitHub Pages looks for it.
- `_config.yml`'s `url` (`https://northofwine.no`) must stay the real site URL: `absolute_url` builds canonical links, Open Graph tags and the sitemap from it.

### Why GitHub Actions instead of native GitHub Pages builds

GitHub Pages' built-in Jekyll build runs in "safe mode", which disables custom plugins and network access, so it can't call the Contentful API. Instead, `.github/workflows/deploy.yml` runs `bundle exec jekyll build` itself and publishes `_site/` with `actions/deploy-pages`. The repo's Pages source must be "GitHub Actions", not "Deploy from a branch".

The Contentful credentials must be in `.env` locally (gitignored) and in the repo's Actions secrets (`CONTENTFUL_SPACE_ID`, `CONTENTFUL_ACCESS_TOKEN`, `CONTENTFUL_ENVIRONMENT`) for CI (see "Connecting to Contentful").

### Contentful publish trigger

**Not set up yet** ([#3](https://github.com/FELM-AS/northofwine-website/issues/3)): the Contentful space has no webhooks, so publishing content doesn't deploy. Deploys run on push to `main` or by hand.

`deploy.yml`'s `repository_dispatch: types: [contentful-publish]` trigger is the GitHub side. The Contentful side has to be set up in Contentful's UI:

1. In GitHub, create a fine-grained personal access token scoped to this repo only, with **Contents: read and write**. That's what the `dispatches` endpoint checks; an Actions permission gets a 403. Use a machine/bot account if one is available, and rotate the token periodically, since it's stored outside this repo's secrets.
2. In Contentful, go to **Settings → Webhooks → Add webhook**, triggered on Entry **Publish** (and Unpublish, if wanted), with:
   - URL: `https://api.github.com/repos/FELM-AS/northofwine-website/dispatches`
   - Method: `POST`, Content type: `application/json`
   - Headers: `Authorization: Bearer <the token from step 1>`, `Accept: application/vnd.github+json`
   - Payload: `{"event_type": "contentful-publish"}`

`repository_dispatch` only runs a workflow that's on the default branch. Testing the webhook against an unmerged `deploy.yml` gets a 200 from GitHub but triggers no run.

To pause Contentful-triggered deploys during a bulk edit, set the `CONTENTFUL_AUTOBUILD_DISABLED` repo variable to `true` (`gh variable set CONTENTFUL_AUTOBUILD_DISABLED --body true`). `deploy.yml`'s `build` job then skips `repository_dispatch` runs; push and manual runs are unaffected. Unset it (or set any other value) to resume. It's a manual switch, not a debounce: without it, each publish queues its own full run (`concurrency: pages` queues rather than cancels), which can also delay a push deploy queued behind them. So flip it before a bulk edit, not after noticing a backlog.
