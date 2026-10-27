# northofwine.no

The website for [North of Wine AS](https://northofwine.no), a Norwegian wine importer based in Trondheim. Products, producers and people are edited in Contentful, fetched at build time, and rendered by Jekyll into a static site that GitHub Actions deploys to GitHub Pages.

This README is for developers and operators: local setup, how content gets from Contentful to the live site, deploying, and keeping the site running. For what the site does, see [FEATURES.md](FEATURES.md). For how the build works internally, see [CLAUDE.md](CLAUDE.md). For the Contentful fields, see [Contentful-Content-Model.md](Contentful-Content-Model.md).

## Setup

1. Install dependencies: `bundle install`
2. Copy `.env.example` to `.env` and fill in the Contentful credentials. In Contentful, go to Settings → API keys and open or add a key; it shows the space ID and the Content Delivery API token.
   ```
   CONTENTFUL_SPACE_ID=
   CONTENTFUL_ACCESS_TOKEN=
   CONTENTFUL_ENVIRONMENT=master
   ```
3. `bundle exec jekyll serve` starts a local server at `http://localhost:4000`.

All three variables are required. Without them a local build still succeeds, but with no products, producers or people (a warning says so). A production build (`JEKYLL_ENV=production`, as in CI) fails instead, so missing secrets can't deploy an empty site.

There's no test suite. Check a change with `bundle exec jekyll build --trace` and look at the HTML in `_site/`. If the change touches links, also run the link check CI runs:

```
bundle exec htmlproofer ./_site --checks Links,Scripts --ignore-urls "/^https:\/\/northofwine\.no/" --no-enforce-https --only-4xx --ignore-status-codes 429 --assume-extension ""
```

### Previewing draft content

Set `CONTENTFUL_PREVIEW=true` and `CONTENTFUL_PREVIEW_ACCESS_TOKEN` (the Preview API token, on the same API key page in Contentful) to build with draft content as well as published. Never add these to the repo's Actions secrets: the deploy would publish drafts to the live site.

## Editing content

Products, producers and people are edited in Contentful. There are no content files in this repo. Field reference and editing conventions: [Contentful-Content-Model.md](Contentful-Content-Model.md).

- **Product:** appears at `/utvalg/<slug>/`, on the Utvalg page, and on the filter pages for its `productTypeName` and `webProductTypeName`.
- **Producer:** appears on `/produsenter/` and on its country's page. A country not yet in `_data/countries.yml` needs a language code added there (the build warns).
- **Person:** appears on `/omoss/`. The entry marked *Company Profile* is the page's company text instead.
- **Site text** (Hjem's intro, labels, the footer warning) is in `_data/i18n/nb-NO.yml`. Contact details and social links are in `_data/company.yml`. Changing these needs a commit.

**Publishing in Contentful does not update the site yet.** The Contentful webhook isn't set up ([#3](https://github.com/FELM-AS/northofwine-website/issues/3)). After editing content, start a deploy by hand (see below).

## Deploying

`.github/workflows/deploy.yml` builds the site, checks every link, and deploys to GitHub Pages. A broken link or a build error stops the deploy, and the live site stays as it was. There is no staging site: every deploy goes straight to production.

A deploy runs:

- on every push to `main`;
- by hand: **Actions → Deploy to GitHub Pages → Run workflow** (or `gh workflow run deploy.yml`);
- on Contentful publish, once the webhook is set up. Setup, and pausing these deploys during a bulk edit, are in CLAUDE.md's "Contentful publish trigger" section.

## Operations

### Secrets and settings

| What | Where |
| --- | --- |
| `CONTENTFUL_SPACE_ID`, `CONTENTFUL_ACCESS_TOKEN`, `CONTENTFUL_ENVIRONMENT` | Repo Actions secrets. To rotate the token: create a new Content Delivery API key in Contentful, update the secret, run a deploy, then delete the old key. |
| `CONTENTFUL_AUTOBUILD_DISABLED` | Repo Actions variable; pauses Contentful-triggered deploys (CLAUDE.md, "Contentful publish trigger"). |
| Webhook token | A fine-grained GitHub token stored in the Contentful webhook's headers, not in this repo. Rotate it in both places. |
| Analytics | GoatCounter site code `northofwine` (`goatcounter_code` in `_config.yml`). Dashboard: https://northofwine.goatcounter.com |

### Domain

- **DNS:** hosted at Domeneshop. `northofwine.no` has A records for GitHub Pages' four addresses (185.199.108–111.153). `www` is a CNAME to `felm-as.github.io`.
- **GitHub Pages:** in the repo's Settings → Pages, the source is "GitHub Actions", the custom domain is `northofwine.no`, and "Enforce HTTPS" is on.
- **`_config.yml`:** `url` must stay `https://northofwine.no`. Canonical links, share previews and the sitemap are built from it.

### When a deploy fails

Open the failed run in the Actions tab. The error names the cause:

- **"… not set, refusing to build production without content":** an Actions secret is missing or empty. Add it back and re-run.
- **"… both produce "/utvalg/…/"":** two entries (or an entry and a filter value) land on the same URL. Change one slug in Contentful and re-run.
- **html-proofer lists broken links:** fix the link (in Contentful, `_data/`, or a template). Only 4xx responses fail the check, so an external link listed here is gone or moved, not just down: fix or remove it.
- **"i18n: missing key …":** a template uses a text key that isn't in `_data/i18n/nb-NO.yml`. Add it.

To undo a bad code change, revert the commit on `main`; the push deploys the previous version. To undo bad content, fix or unpublish the entry in Contentful and run a deploy.
