# Features

What northofwine.no and this repository do, and why, for anyone who needs to know: developers, North of Wine staff, reviewers. How each feature is built is in [CLAUDE.md](CLAUDE.md); setup and deploying are in [README.md](README.md).

## Pages

### Hjem (`/`)

The company name, a short intro and a link to Utvalg. There is no header: the menu sits in the left column on the textured background instead, so the front page is the navigation. The intro text is UI text (`_data/i18n/nb-NO.yml`), not Contentful content.

### Utvalg (`/utvalg/`)

The wine catalogue: every published product as a card, in Norwegian alphabetical order (Æ, Ø, Å after Z).

- **Filters.** The sidebar links to one page per wine type, e.g. `/utvalg/rodvin/` and `/utvalg/tokaj/`. Types come from two fields: *Varetype* (`productTypeName`, Vinmonopolet's category) and *Nettsidekategori* (`webProductTypeName`, for categories Vinmonopolet doesn't have, such as Tokaj). A wine with both set is listed under both. Only types that have wines get a page, so a filter never leads to an empty list, and a new type gets its page automatically.
- **Product card.** Wine type, country and region, image, name, and a link to the product page. If the wine has a Vinmonopolet item number and a price above 0, the card also shows the price as a button to the wine on vinmonopolet.no (new tab). The Horeca price is never shown: trade prices are given on request.
- Filtering is done with real pages rather than JavaScript, so every filter has its own shareable URL that search engines can index.

### Product page (`/utvalg/<slug>/`)

- Breadcrumb back to Utvalg and to the type pages the wine is listed on.
- Name, description, production method, and a link to the producer's card on Produsenter.
- **Taste profile** as 1–12 gauges, like Vinmonopolet's own product pages: fullness and freshness always, plus tannins for red wine and sweetness for every other type.
- Food pairing as a sentence ("Fisk, skalldyr og ost"), colour, smell and taste.
- Our item number, Vinmonopolet's item number, grapes with their share, storage potential, alcohol, volume in litres, packaging and closure.
- The bottle image in the sidebar.

Fields without a value are left out, with no empty labels.

### Produsenter (`/produsenter/`)

Every producer as a card, with one filter page per country (e.g. `/produsenter/italia/`) for the countries that have producers. The card has image, logo, name, a link to the producer's website (new tab), description, and links to that producer's wines on Utvalg. Producers have no page of their own, as on the old site; product pages link to the producer's card instead.

### Om oss (`/omoss/`)

The company text, then a card per person with image, name, email, phone and description. The company text is the Contentful person entry marked *Company Profile*. Contact details live here and in the footer; there is no separate contact page.

### 404

A short message, links to the three sections, and the footer. Search engines are told not to index it.

### Old addresses

The old site's `/utvalg.html`, `/produsenter.html` and `/omoss.html` forward to the new pages, so old links and search results keep working. Old product URLs (`/utvalg/<slug>`) are unchanged. `/kontakt.html` had too little traffic to keep and goes to the 404 page.

## Shared parts

- **Header** (every page but Hjem): home button and menu button.
- **Menu**: opens as an overlay. It works fully from the keyboard: focus stays inside it, and Escape closes it.
- **Footer**: the Helsenorge alcohol warning (alcohol marketing must carry it), the post@ and faktura@ addresses, street address, org. number, and Facebook and Instagram links. These come from `_data/company.yml`.
- **Layout**: sidebar beside the main content; on narrow screens the sidebar stacks above it.

## Content

- Products, producers and people are edited in Contentful and fetched when the site is built. Everything else (Hjem's text, labels, footer details) lives in this repo. Field reference: [Contentful-Content-Model.md](Contentful-Content-Model.md).
- Descriptions are written in Markdown. A single line break stays a line break, and quotes become Norwegian «» and ‘’. Raw HTML in a description shows as plain text, so an editor can't break the page layout or add scripts.
- Unpublishing an entry removes it from the site on the next build. There is no "sold out" state.
- Stray spaces around text fields are trimmed, and letters like Å are normalized, so sorting and URLs behave the same however the text was typed or pasted.
- A product without a slug is left out with a build warning, rather than ending up on a broken address.

## Language and formatting

- Numbers use Norwegian conventions: decimal comma, prices as "550,00 kr", volume in litres.
- Product and producer names carry the language of the producer's country (`lang="it"` for an Italian producer, and so on), so long names hyphenate correctly and screen readers pronounce them right. The country → language list is `_data/countries.yml`.
- Lists sort in Norwegian alphabetical order.
- All UI text is in one file, `_data/i18n/nb-NO.yml`. The site is Norwegian only, but URLs, data and templates are ready for a second language: adding one means translating that file and configuring the language, not rebuilding the site.

## Images

- Images are resized by Contentful to the size each spot needs, and served as WebP.
- Images further down a listing load only when scrolled to.
- If a resized image fails, the original is tried. If that fails too, a placeholder is shown.
- Alt text comes from the image's description in Contentful, else the product, producer or person name. On product cards the image is decorative (empty alt), since the card's heading already names the wine.

## Search engines and sharing

- Each page has its own title ("Rødvin – North of Wine"), meta description and canonical address.
- Shared links show a preview card (Open Graph / Twitter Card). A product shows its bottle, padded to the card's shape so it isn't cropped. Other pages show a site-wide image.
- Structured data (JSON-LD) describes the company on Hjem and the breadcrumb on product pages. There is deliberately no product or price markup: it could count as alcohol advertising under alkoholloven.
- `sitemap.xml` lists every page, with the date the content last changed. `robots.txt` points to it.
- Favicon (adapts to dark mode) and a home-screen icon for phones.

## Privacy

- Visitor statistics use [GoatCounter](https://www.goatcounter.com/): no cookies and no personal data, so no consent banner is needed.
- Fonts (DM Sans, DM Mono) are served from this site, not from Google Fonts, so no visitor data goes to Google (GDPR).
- Images are served from Contentful's image CDN. There are no other third-party requests.

## Build and deploy

- The site is static: GitHub Actions fetches the content from Contentful, builds the pages with Jekyll, and publishes them to GitHub Pages at northofwine.no.
- **When it deploys:** on every push to `main`, and when started by hand in GitHub Actions. The workflow can also deploy when an entry is published in Contentful, but the Contentful webhook for that is not set up yet ([#3](https://github.com/FELM-AS/northofwine-website/issues/3)), so after editing content, start a deploy by hand. Once the webhook exists, a repo variable can pause these deploys during a bulk edit.
- **Safety checks.** A deploy is stopped if:
  - the Contentful credentials are missing, so an empty site can't go live;
  - two entries end up on the same address, for example two products with the same slug;
  - a link on the site is broken (every build is link-checked).
- Draft content can be previewed in a local build (Contentful's Preview API). The live site only ever shows published content.
