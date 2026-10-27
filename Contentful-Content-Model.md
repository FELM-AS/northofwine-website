# Contentful content model

For developers and anyone changing the Contentful space: the content types, fields, validations and editor conventions the site depends on. Generated from a Contentful export of space `58mi2hzmh573`, environment `master`, on 2026-10-22. What the site does with this content is in [FEATURES.md](FEATURES.md).

To refresh it, export the model (no entries needed; the CLI uses the management token from `contentful login`), then update the tables below to match:

```sh
contentful space export --space-id 58mi2hzmh573 --environment-id master \
  --skip-content --skip-roles --content-file model.json
```

The **Site** column says where the site reads a field. A blank means the field isn't used on the site (it's used for Vinmonopolet, NBS or internal records). The site reads every field by its snake_cased ID, e.g. `productTypeName` → `page.product_type_name`.

## Space

- **Locales:** `nb-NO` (default) and `en`. The site builds `nb-NO` only (`contentful_locales` in `_config.yml`). Only the `description` and `summary` of Manufacturer and Region are localized.
- **Tags:** `productImage` (Product image), `imageManufacturer` (Image: Manufacturer), `imageLogo` (Image: Logo). These are for editors only and aren't shown on the site.
- **Webhooks:** none yet; see "Contentful publish trigger" in [CLAUDE.md](CLAUDE.md).

## Product (`product`)

Entry title: `productShortName`. One page per published entry, at `/utvalg/<slug>/`.

| Field ID | Label | Type | Required | Validation | Site |
|---|---|---|---|---|---|
| `productShortName` | Artikkelnavn | Symbol | yes | unique | Name (page title, card, breadcrumb) |
| `slug` | Slug | Symbol | yes | | URL. Sanitized and warned about if not URL-safe; an entry without one is skipped |
| `sku` | SKU NBS | Symbol | | unique | Product page ("Vårt varenummer"). Also the image file name prefix, see below |
| `description` | Beskrivelse | Text (Markdown) | | | Product page body and meta description |
| `productId` | Artikkelnummer VMP | Symbol | | 7–8 digits | Product page; with `salesPrice`, the card's link to vinmonopolet.no/p/`<productId>` |
| `assortment` | Produktutvalg | Symbol | | Basisutvalget, Partiutvalget, Testutvalget, Bestillingsutvalget, Tilleggsutvalget, Spesialutvalg | |
| `gtinSingle` | GTIN | Symbol | | 13–14 digits | |
| `gtinDpak` | GTIN D-PAK | Symbol | | 13–14 digits | |
| `webProductTypeName` | Nettsidekategori | Symbol | | | Utvalg filter page, breadcrumb |
| `productTypeName` | Varetype | Symbol | yes | Aromatisert vin, Fruktvin, Hvitvin, Musserende vin, Rosévin, Rødvin, Øvrig svakvin, Perlende vin, Sider, Madeira, Portvin, Sherry, Vermut, Sterkvin, annen | Utvalg filter page, breadcrumb, card. `Rødvin` shows tannins instead of sweetness |
| `grapeDesc` | Druetyper | List of Symbol | | | Product page, paired by position with `grapePct` |
| `grapePct` | Drueandel | List of Symbol | | 1–3 digits | Product page |
| `productionMethodStorage` | Produksjonsmetode / Lagring | Text | | | Product page ("Metode") |
| `vintage` | Årgang | Symbol | | 4 digits | |
| `vintageControlled` | Årgang i produktnavn | Boolean | | default `false`; hidden in the editor | |
| `country` | Land | Symbol | | | Card (with `region`) |
| `region` | Distrikt | Symbol | | | Card; product page, when a Region entry matches |
| `subRegion` | Underdistrikt | Symbol | | | Product page, when a Region entry matches |
| `localQualityClassif` | Kvalitets-ID | Symbol | | | |
| `manufacturer` | Produsent | Reference → manufacturer | yes | | Producer link on the product page; the producer's `country` sets the name's `lang` |
| `colour` | Karakteristikk - Farge | Symbol | | | Product page |
| `odour` | Karakteristikk - Lukt | Symbol | | | Product page |
| `taste` | Karakteristikk - Smak | Symbol | | | Product page |
| `fullness` | Fylde | Symbol | | 1–12 | Product page gauge |
| `tannins` | Garvestoffer | Symbol | | 1–12 | Product page gauge (Rødvin) |
| `freshness` | Friskhet | Symbol | | 1–12 | Product page gauge |
| `sweetness` | Sødme | Symbol | | 1–12 | Product page gauge (all but Rødvin) |
| `recommendedFood` | Bruksområde | List of Symbol | | Aperitiff/avec, Skalldyr, Fisk, Lyst kjøtt, Storfe, Lam og sau, Småvilt og fugl, Storvilt, Ost, Dessert, kake, frukt, Svinekjøtt, Grønnsaker | Product page ("Passer til") |
| `storagePotential` | Konsum-ID | Symbol | | Drikkeklar, ikke egnet for lagring · Drikkeklar nå, men kan også lagres · Kan drikkes nå, blir bedre ved lagring | Product page |
| `sugar` | Sukker (gram / liter) | Symbol | | | |
| `acid` | Syre (gram / liter) | Symbol | | | |
| `corkType` | Korktype | Symbol | | Naturkork, Syntetisk kork, Skrukapsel, Glasstoper, Annet, Plastkork, Crown Cap | Product page |
| `alcoholContent` | Alkoholprosent | Number | | ≤ 40 | Product page |
| `volume` | Volum | Integer (ml) | | 375, 500, 750, 1000, 1500, 3000 | Product page, in litres |
| `packagingMaterial` | Emballasjetype | Symbol | | Glass, Bag-in-box | Product page |
| `salesPrice` | Pris - VMP | Number | | | Card price button, when above 0 and `productId` is set |
| `salesPriceHoreca` | Pris - Horeca | Number | | | Never shown: trade prices are given on request |
| `image` | Produktbilde | Asset | | image, height ≥ 5000 px | Card, product page sidebar, share preview |
| `labelBack` | Baketikett | Asset | | image | |

## Manufacturer (`manufacturer`)

Entry title: `name`. No page of its own: a card on `/produsenter/` and on its country's filter page.

| Field ID | Label | Type | Required | Validation | Site |
|---|---|---|---|---|---|
| `name` | Navn | Symbol | yes | unique | Card heading, product page producer link |
| `country` | Land | Symbol | yes | Frankrike, Italia, Tyskland, Østerrike, Spania, Portugal, Ungarn, Chile, Argentina, Australia, New Zealand, USA, Norge, Danmark | Produsenter filter page (only countries some producer has), and the `lang` of the producer's and its wines' names via `_data/countries.yml` |
| `description` | Beskrivelse | Text (Markdown), localized | yes | | Card |
| `summary` | Sammendrag | Text (Markdown), localized | | | |
| `link` | Link | Symbol | | unique; must start with ftp://, http:// or https:// | Card, shown as the bare host name (`https://example.it/en/` → `example.it`), opens in a new tab |
| `image` | Bilde | Asset | | image | Card |
| `logo` | Logo | Asset | | image | Card |
| `manufacturerId` | Produsent ID | Symbol | | | |

## Person (`person`)

Entry title: `name`. Shown on `/omoss/`.

| Field ID | Label | Type | Required | Validation | Site |
|---|---|---|---|---|---|
| `name` | Name | Symbol | yes | unique | Card heading, or the heading of the company text |
| `description` | Description | Text (Markdown) | yes | | Card, or the company text |
| `email` | Email | Symbol | | email address | Card |
| `image` | Image | Asset | | image | Card |
| `phone` | Phone | Symbol | | 8 digits | Card |
| `companyProfile` | Company Profile | Boolean | | default `false` | `true` makes this entry Om oss's company text instead of a person card. Exactly one entry should have it; the build warns otherwise |

## Region (`region`)

Entry title: `name`. One entry per Vinmonopolet region or subregion value our wines carry. No page of its own yet. The entries are loaded from the region description drafts in the Data quality folder by an import script kept outside this repo (`Claude outputs/Region import/region_import.py` in that folder), which matches entries by `key`.

| Field ID | Label | Type | Required | Validation | Site |
|---|---|---|---|---|---|
| `name` | Navn | Symbol | yes | | |
| `key` | Nøkkel | Symbol | yes | unique | Matched against the product's `country / region / subRegion`, e.g. `Italia / Piemonte / Barolo` |
| `summary` | Sammendrag | Text (Markdown), localized | | | Product page, under the producer, behind the region or subregion name |
| `description` | Beskrivelse | Text (Markdown), localized | | | Not shown yet |

## Conventions the site relies on

Contentful doesn't enforce these, so keep to them when editing:

- **Product images** are named `<SKU>-product-image.<jpg|png>` (`image`) and `<SKU>-label-rear.<jpg|png>` (`labelBack`), and the asset title is the file name without its extension. An image shared by several products takes the lowest SKU.
- **Alt text** comes from an image's description, else the product, producer or person name. Product image descriptions are left empty on purpose: the card's heading already names the wine.
- **New producer country:** each `country` value needs a language code in `_data/countries.yml`, for the `lang` attribute. The build warns about a country that's missing there. Each of today's countries has one language. If a country with several (e.g. Switzerland) is added, decide which one its names use.
- **Grapes:** `grapeDesc` and `grapePct` are two lists matched by position, largest share first. A share without a grape is ignored.
- **Vinmonopolet categories:** `productTypeName` is Vinmonopolet's category. `webProductTypeName` is for categories Vinmonopolet doesn't have (e.g. Tokaj). Both become Utvalg filters.
- **Origin:** a product's `country`, `region` and `subRegion` use Vinmonopolet's code list names, spelled exactly as in the Region entry's `key`. A misspelt value shows without its summary.
- **Slugs** must be unique. Two products on the same URL fail the deploy.
