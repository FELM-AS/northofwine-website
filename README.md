# northofwine.no

The website for [North of Wine AS](https://northofwine.no), a Norwegian wine importer based in Trondheim. Content (products, manufacturers, people) is authored and edited in Contentful, fetched at build time, and rendered by Jekyll into a static site deployed to GitHub Pages via GitHub Actions.

**Status:** pre-launch. The real domain, `northofwine.no`, is still serving the old site; this repo currently deploys to a temporary GitHub Pages URL (`https://felm-as.github.io/northofwine-website/`) until DNS is cut over (tracked in the issue tracker).

Originally scaffolded from the `github-pages-contentful` template's Contentful → Jekyll → GitHub Pages architecture, but this repo is no longer a template — it's the concrete site for one company. See [`planning/Plan.md`](planning/Plan.md) for the full design/requirements spec this was built against, [`planning/Plan-Issues.md`](planning/Plan-Issues.md) for the implementation breakdown, [`planning/Contentful-Content-Model.md`](planning/Contentful-Content-Model.md) for the exact Contentful fields, and [`CLAUDE.md`](CLAUDE.md) for how the underlying Contentful→Jekyll build pipeline works internally.

## Features

**Pages**, all built from Contentful content except Hjem/Om oss (hand-authored) and 404:

- **Hjem** (`/`) — home page; sidebar doubles as the site nav here instead of a header.
- **Utvalg** (`/utvalg/`) — the product catalog: an unfiltered listing plus one page per wine type (`productTypeName`/`webProductTypeName`, e.g. `/utvalg/rodvin/`) and one page per product (grape composition, sensory ratings as native `<meter>` gauges, food pairing, alcohol/volume/SKU).
- **Produsenter** (`/produsenter/`) — the manufacturer listing plus one page per country of origin (all 13 enum values get a page even with zero current manufacturers, so a filter link never 404s).
- **Om oss** (`/omoss/`) — company text plus the People roster.
- **404** — a custom not-found page instead of GitHub's own default.

**Content & formatting**

- Product/Manufacturer/Person entries are fetched straight from Contentful at build time (see [`planning/Contentful-Content-Model.md`](planning/Contentful-Content-Model.md) for the field reference) — there's no local copy to keep in sync.
- Prices, alcohol %, volume, and sensory scores follow Norwegian numeric convention (comma decimals, `kr` suffix on prices).
- Product/manufacturer names get a `lang` attribute derived from the manufacturer's own country (via `_data/countries.yml`), for correct hyphenation and screen-reader pronunciation.
- Internationalization groundwork is in place (locale-aware URLs, `site.data` keys, and generators) even though only Norwegian (`nb-NO`) is configured today — adding a second locale is a one-line `_config.yml` change, not a rebuild, once that locale exists in Contentful's own Settings → Locales (the CDA hard-fails with "Unknown locale" otherwise).

**Resilience & accessibility**

- Every image goes through a two-stage client-side fallback: a failed resize retries the original asset, and a fully broken/missing asset falls back to a generic placeholder — see `assets/js/image-fallback.js`.
- Alt text is required and set from Contentful where available; the header's menu overlay is a native `<dialog>` (full keyboard support — focus trapping, Escape-to-close — for free).
- The build never fails on missing content fields — Liquid just renders an absent field as empty. An entry missing its `slug` specifically is skipped with a build warning instead of being built at a broken URL.

**Fonts** — DM Sans and DM Mono are self-hosted (`assets/fonts/`, `_sass/_fonts.scss`) rather than loaded from Google's CDN at request time, avoiding an unnecessary third-party request/IP transfer. DM Mono is currently unused, reserved for a later design decision.

**SEO** — every page gets a canonical link, a meta description, and Open Graph/Twitter Card tags automatically (`_includes/seo.html`), plus a hand-rolled `sitemap.xml`/`robots.txt` that stay correct as content is added or removed, with no extra config.

**Analytics** — [GoatCounter](https://www.goatcounter.com/) (free, cookie-less, no consent banner needed) is wired in but inactive until `_config.yml`'s `goatcounter_code` is set to a real account's site code.

**CI** — every push runs `html-proofer` against the built site (`.github/workflows/deploy.yml`) to catch broken internal/external links before they ship, gating the deploy.

## Setup

1. Install dependencies: `bundle install`
2. Copy `.env.example` to `.env` and fill in your Contentful credentials (in Contentful: Settings → API keys → add or open an API key for a Content Delivery API token; the space ID is on the same page):
   ```
   CONTENTFUL_SPACE_ID=
   CONTENTFUL_ACCESS_TOKEN=
   CONTENTFUL_ENVIRONMENT=master
   ```
3. `bundle exec jekyll serve` — local dev server at `http://localhost:4000`.

Without a `.env` (or without the same three values as Actions secrets in CI), the build still succeeds — it just generates zero Contentful-backed pages, logging a warning instead of failing.

### Previewing draft content

Set `CONTENTFUL_PREVIEW=true` and `CONTENTFUL_PREVIEW_ACCESS_TOKEN` (a separate token from your CDA `CONTENTFUL_ACCESS_TOKEN`, issued in Contentful under the same space) to build against draft/unpublished content instead of only published entries. **Don't** set these in the production deploy workflow's secrets — doing so publishes draft content to the live public site.

## Editing content

Products, manufacturers, and people are all edited directly in Contentful — there are no content files in this repo to touch. Publishing an entry doesn't update the live site by itself yet; see "Deploying" below.

- **Adding/editing a product**: fill in the `product` content type's fields (see [`planning/Contentful-Content-Model.md`](planning/Contentful-Content-Model.md)) and publish. It appears at `/utvalg/<slug>/`, and on the Utvalg root plus its `productTypeName`/`webProductTypeName` filter pages, automatically.
- **Adding/editing a manufacturer or person**: same idea — manufacturers appear on `/produsenter/` and their own country's filter page; people appear on `/omoss/`.
- **Country enum**: the 13-value country enum used for hyphenation and the Produsenter country filters is mirrored in `_data/countries.yml` — adding a genuinely new country to the Contentful schema needs a matching entry there too, or that manufacturer gets no filter page (a build warning names it if this happens).

## Deploying

- **Push to `main`** always builds and deploys (`.github/workflows/deploy.yml`).
- **Contentful publish** can also trigger a build+deploy automatically, once a webhook is configured in Contentful's own settings — see CLAUDE.md's "Contentful publish trigger" section for the exact setup (a GitHub PAT, the webhook URL/payload). To pause this during a bulk content edit, set the `CONTENTFUL_AUTOBUILD_DISABLED` repo variable to `true` (`gh variable set CONTENTFUL_AUTOBUILD_DISABLED --body true`); unset it to resume.
- A manual run is always available too: **Actions → Deploy to GitHub Pages → Run workflow**.

Every build also runs the link checker used in CI; run it locally after `bundle exec jekyll build` if you've touched anything link-related:

```
bundle exec htmlproofer ./_site --checks Links,Scripts --swap-urls "^/northofwine-website/:/" --ignore-urls "/^https:\/\/felm-as\.github\.io\/northofwine-website/" --no-enforce-https --only-4xx --ignore-status-codes 429
```

(The `--swap-urls`/`--ignore-urls` flags exist only because of the temporary GitHub Pages project-site path mentioned above — see the matching comment in `deploy.yml` for what to change once the custom domain lands.)

## Further reading

- [`planning/Plan.md`](planning/Plan.md) — the full design spec (pages, components, formatting, i18n, accessibility, SEO, analytics) this site was built against.
- [`planning/Plan-Issues.md`](planning/Plan-Issues.md) — that plan broken into individual issues, for historical/implementation-order reference (check the repo's actual issue tracker for current status, not this document).
- [`planning/Contentful-Content-Model.md`](planning/Contentful-Content-Model.md) — field-by-field reference for the `product`, `manufacturer`, and `person` content types.
- [`CLAUDE.md`](CLAUDE.md) — how the Contentful → Jekyll build pipeline itself works (the generator plugins, locale handling, field serialization, SEO internals) — the deeper "how" behind the features described above.
