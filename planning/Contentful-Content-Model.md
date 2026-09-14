# Contentful Content Model — northofwine.no

Generated from `contentful-export-58mi2hzmh573-master-2026-09-11T15-17-51.json`.

## Space overview

- Locale(s): nb-NO (default)
- Content types: 3
- Entries in this export: 178
- Assets in this export: 370

## Editorial tags

Tags available for tagging entries (used by editors to track content status, not shown on the site). `inactive` exists but is not currently used.

- `productImage` — Product image
- `notComplete` — Not complete
- `complete` — Complete
- `processing` — Processing
- `republish` — Republish
- `nbs` — NBS
- `todo` — Todo
- `inactive` — Inactive
- `imageManufacturer` — Image: Manufacturer
- `imageLogo` — Image: Logo

## Webhooks (build triggers)

- **Deploy to staging** → `https://api.github.com/repos/northofwine/now-web-staging/dispatches`
  - Fires on: ContentType.publish, ContentType.unpublish, Entry.publish, Entry.unpublish, Asset.publish, Asset.unpublish
- **Deploy GitHub Pages** → `https://api.github.com/repos/northofwine/northofwine.github.io/dispatches`
  - Fires on: ContentType.publish, ContentType.unpublish, Entry.publish, Entry.unpublish, Asset.publish, Asset.unpublish

## Product (`product`)

Display field: `productShortName`

| Field ID | Label | Type | Required | Notes |
|---|---|---|---|---|
| `productShortName` | Artikkelnavn | Symbol | Yes | must be unique |
| `slug` | Slug | Symbol | Yes |  |
| `sku` | SKU NBS | Symbol |  | must be unique |
| `description` | Beskrivelse | Text |  |  |
| `productId` | Artikkelnummer VMP | Symbol |  | pattern `[0-9]` — Artikkelnummeret hos vinmonopolet har kun siffer |
| `assortment` | Produktutvalg | Symbol |  | allowed: Basisutvalget, Partiutvalget, Testutvalget, Bestillingsutvalget, Tilleggsutvalget, Spesialbestilling, Spesialutvalg |
| `gtinSingle` | GTIN | Symbol |  |  |
| `gtinDpak` | GTIN D-PAK | Symbol |  |  |
| `orderPack` | Forpakning | Symbol |  | allowed: D06, D12 |
| `minimumOrderQuantity` | Minste bestillingskvantum | Number |  | allowed: 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12 |
| `webProductTypeName` | Nettsidekategori | Symbol |  |  |
| `mainProductTypeName` | Hovedvaretype | Symbol |  | allowed: Alkoholfritt, Brennevin, Sterkvin, Svakvin, Øl |
| `productTypeName` | Varetype | Symbol | Yes | allowed: Aromatisert vin, Fruktvin, Hvitvin, Musserende vin, Perlende vin, Rosévin, Rødvin, Sider, Sterkvin, Øvrig svakvin, Portvin |
| `subProductTypeName` | Subvaretype | Symbol |  | allowed: Champagne extra brut, Champagne, annen, Champagne, brut, Champagne, rosé, Champagne, sec, Hvitvin, Musserende vin, rosé, Perlende vin, hvit, Perlende vin, rosé, Perlende vin, rød, Portvin, Rosévin, Rødvin, Sider, Vermut, Øvrig svakvin |
| `productGroupName` | Produktgruppe | Symbol |  |  |
| `grapeDesc` | Druetyper | List of Symbol |  |  |
| `grapePct` | Drueandel | List of Symbol |  |  |
| `ingredients` | Ingredienser | Text |  |  |
| `allergens` | Allergener | Text |  |  |
| `productionMethodStorage` | Produksjonsmetode / Lagring | Text |  |  |
| `vintage` | Årgang | Symbol |  | length 4-4; pattern `[0-9]{4}` |
| `vintageControlled` | Årgang i produktnavn | Boolean |  |  |
| `country` | Land | Symbol |  |  |
| `region` | Distrikt | Symbol |  |  |
| `subRegion` | Underdistrikt | Symbol |  |  |
| `localQualityClassif` | Kvalitets-ID | Symbol |  |  |
| `manufacturer` | Produsent | Reference → Entry | Yes | links to: manufacturer |
| `colour` | Karakteristikk - Farge | Symbol |  |  |
| `odour` | Karakteristikk - Lukt | Symbol |  |  |
| `taste` | Karakteristikk - Smak | Symbol |  |  |
| `fullness` | Fylde | Symbol |  | allowed: 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12 |
| `tannins` | Garvestoffer | Symbol |  | allowed: 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12 |
| `freshness` | Friskhet | Symbol |  | allowed: 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12 |
| `sweetness` | Sødme | Symbol |  | allowed: 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12 |
| `recommendedFood` | Bruksområde | List of Symbol |  |  |
| `storagePotential` | Konsum-ID | Symbol |  | allowed: Drikkeklar, ikke egnet for lagring, Drikkeklar nå, men kan også lagres, Kan drikkes nå, blir bedre ved lagring |
| `sugar` | Sukker (gram / liter) | Symbol |  |  |
| `acid` | Syre (gram / liter) | Symbol |  |  |
| `corkType` | Korktype | Symbol |  | allowed: Naturkork, Syntetisk kork, Skrukapsel, Glasstoper, Crown cap, Annet, Plastkork |
| `alcoholContent` | Alkoholprosent | Number |  |  |
| `volume` | Volum | Integer |  |  |
| `packagingMaterial` | Emballasjetype | Symbol |  | allowed: Glass, Bag-in-box |
| `packagingWeight` | Emballasjevekt (gram) | Number |  |  |
| `transportWeight` | Transportvekt (gram) | Number |  |  |
| `salesPrice` | Pris - VMP | Number |  |  |
| `salesPriceHoreca` | Pris - Horeca | Number |  |  |
| `image` | Produktbilde | Reference → Asset |  | must be: image; image size: height ≥5000px |
| `labelBack` | Baketikett | Reference → Asset |  | must be: image |

## Person (`person`)

Display field: `name`

| Field ID | Label | Type | Required | Notes |
|---|---|---|---|---|
| `name` | Name | Symbol | Yes | must be unique |
| `description` | Description | Text | Yes |  |
| `email` | Email | Symbol |  | pattern `^\w[\w.-]*@([\w-]+\.)+[\w-]+$` |
| `image` | Image | Reference → Asset |  | must be: image |
| `phone` | Phone | Symbol |  | pattern `[0-9]{8}` |

## Manufacturer (`manufacturer`)

Display field: `name`

| Field ID | Label | Type | Required | Notes |
|---|---|---|---|---|
| `name` | Navn | Symbol | Yes | must be unique |
| `country` | Land | Symbol | Yes | allowed: Frankrike, Italia, Tyskland, Østerrike, Spania, Portugal, Ungarn, Chile, Argentina, Australia, New Zealand, USA, Norge |
| `description` | Beskrivelse | Text | Yes |  |
| `link` | Link | Symbol |  | must be unique; pattern `^(ftp|http|https):\/\/(\w+:{0,1}\w*@)?(\S+)(:[0-9]+)?(\/|\/([\w#!:.?+=&%@!\-/]))?$` |
| `image` | Bilde | Reference → Asset |  | must be: image |
| `logo` | Logo | Reference → Asset |  | must be: image |
| `manufacturerId` | Produsent ID | Symbol |  |  |

## Notes for the redesign

- `subProductTypeName`, `productGroupName`, `mainProductTypeName` are Vinmonopolet classification fields, not used for site filtering. Vinmonopolet has no "Tokaj" category — that's why it lives in `webProductTypeName` instead.
- Manufacturer `country` is a fixed enum (13 values: Frankrike, Italia, Tyskland, Østerrike, Spania, Portugal, Ungarn, Chile, Argentina, Australia, New Zealand, USA, Norge) — the Produsenter country filter has exactly these static pages to generate.
- Only `salesPrice` (Vinmonopolet retail price) is shown publicly. `salesPriceHoreca` is never shown on the site — trade pricing is given on request/by sales pitch.
- Product's own `country` field (Land) is free text, independent of Manufacturer's new `country` enum — the two aren't guaranteed to match spelling-wise since they're separate fields.