require "jekyll"
require_relative "contentful_locales"

module ContentfulJekyll
  # Second generator, running after EntriesGenerator (see priority below):
  # static "listing" pages for the two groupings Plan.md calls for --
  # products by productTypeName/webProductTypeName, manufacturers by
  # country. Deliberately just these two hardcoded passes, not a generic
  # reusable grouping framework (see CLAUDE.md). "All items" (no filter)
  # is generated the same way as a filter value, so there's one single
  # URL/content mechanism per collection, not a hand-authored root page
  # plus generated filter pages that could drift apart (e.g. if a
  # collection's `dir` is ever renamed).
  #
  # Also stashes each collection's resolved `dir` onto site.config
  # ("utvalg_dir"/"produsenter_dir", see #generate) so _includes/menu.html
  # and _includes/breadcrumb.html can read a plain, already-locale-resolved
  # string instead of each independently re-deriving it in Liquid -- a
  # `dir` configured as a per-locale Hash (see dir_for below) would
  # otherwise silently stringify into a broken href in those templates.
  #
  # Two more cross-references are precomputed here, once per build, rather
  # than left for a template to re-derive by scanning site.pages on every
  # render (which not only costs O(items x site.pages) per render, but also
  # ties the correct result to a template-side convention -- e.g. a URL
  # prefix, or a field equality check -- that can silently drift from what
  # this generator actually builds):
  # - `page.data["siblings"]` on every listing page (root + each filter/enum
  #   page) in a section: the other listing pages in that same section, for
  #   _includes/filter-nav.html to link to directly.
  # - `page.data["products_by_manufacturer"]` on every manufacturer listing
  #   page: a manufacturer id -> Array<product page> Hash, for
  #   _includes/manufacturer-card.html's "this manufacturer's own products"
  #   list.
  #
  # Loops contentful_locales the same way EntriesGenerator does (planning/
  # Plan.md's Internationalization section: "Jekyll templates loop over
  # locales, even with only one populated at launch"), so this generator
  # needs no changes when a second locale is actually added later. With
  # contentful_locales unconfigured (or a single primary-only entry, this
  # site's case today, see _config.yml), each_locale yields exactly one
  # locale and every url_prefix/data_suffix below is nil -- byte-identical
  # output to a single-locale build.
  #
  # site.config["utvalg_dir"]/["produsenter_dir"] are set from the
  # *primary* locale only -- _includes/menu.html and breadcrumb.html read
  # them directly and aren't themselves locale-parametrized yet (Plan.md's
  # "reserve a spot for a future language switcher", not "translate the
  # nav now"), so they need one stable, unprefixed value to keep linking
  # to the primary locale's own listing pages.
  class ListingPagesGenerator < Jekyll::Generator
    safe true
    priority :low

    LOG_TAG = "Contentful:"

    def generate(site)
      # url -> a label for what built it, so a collision warning can name
      # both sides (e.g. "the web_product_type_name filter" colliding
      # with "the product_type_name filter") instead of just "an existing
      # page". Seeded with already-existing pages under that generic label.
      @built_dirs = site.pages.to_h { |page| [page.url, "an existing page"] }

      product_collection = find_collection(site.config["contentful_collections"], "product")
      manufacturer_collection = find_collection(site.config["contentful_data_collections"], "manufacturer")

      ContentfulJekyll.each_locale(site.config["contentful_locales"]) do |locale|
        generate_for_locale(site, locale, product_collection, manufacturer_collection)
      end
    end

    private

    # One locale pass: builds that locale's own Utvalg/Produsenter
    # root/filter pages, scoped to that locale's own product pages and
    # manufacturers so nothing in a multi-locale build ever mixes one
    # locale's items into another's listing page.
    def generate_for_locale(site, locale, product_collection, manufacturer_collection)
      # id of a product's resolved manufacturer -> Array of that product's
      # page. Computed once here (whether or not the manufacturer section
      # below actually runs) so manufacturer-card.html never has to scan
      # site.pages itself. A product with no resolved manufacturer groups
      # under the nil key, which nothing ever looks up.
      products_by_manufacturer = {}

      if product_collection
        dir = ContentfulJekyll.dir_for(product_collection, locale)
        site.config["utvalg_dir"] = dir if locale.primary?
        # EntriesGenerator prefixes a non-primary locale's own generated
        # pages with locale.url_prefix (nil for the primary locale) --
        # matching that same prefix here, rather than filtering by
        # page.data["locale"], scopes to this locale's product pages
        # using the exact same URL convention the pages were built with.
        url_dir = [locale.url_prefix, dir].compact.join("/")
        product_pages = site.pages.select { |page| page.url.start_with?("/#{url_dir}/") }
        products_by_manufacturer = product_pages.group_by { |page| page.data.dig("manufacturer", "id") }

        utvalg_pages = [build_page(site, locale, dir, nil, product_pages, "the root listing", "product")]
        utvalg_pages.concat(build_grouped_pages(site, locale, dir, product_pages, "product_type_name", "product"))
        utvalg_pages.concat(build_grouped_pages(site, locale, dir, product_pages, "web_product_type_name", "product"))
        link_siblings(utvalg_pages)
        site.pages.concat(utvalg_pages)
      end

      # A plain method return, not a return from `generate` itself (this
      # runs inside generate_for_locale, called once per locale) -- skips
      # only this locale's Produsenter section, letting each_locale's
      # loop continue to the next locale normally.
      return unless manufacturer_collection && manufacturer_collection["dir"]

      dir = ContentfulJekyll.dir_for(manufacturer_collection, locale)
      site.config["produsenter_dir"] = dir if locale.primary?
      # locale.data_key_for is the same helper fetch_data_collection
      # (contentful_entries_generator.rb) uses to build the key it writes
      # this collection's entries under -- reading manufacturer_collection
      # ["name"] here (not a hardcoded "manufacturers" literal) is what
      # keeps this in sync if that collection's configured `name` ever
      # changes.
      manufacturers = site.data[locale.data_key_for(manufacturer_collection["name"])] || []

      produsenter_pages = [build_page(site, locale, dir, nil, manufacturers, "the root listing", "manufacturer", products_by_manufacturer)]
      # Country is a fixed 13-value enum (planning/Contentful-Content-Model.md,
      # Plan-Issues.md #14: "Each of the 13 country values has its own
      # static URL") -- unlike product_type_name/web_product_type_name
      # above, every enum value gets a page regardless of whether a
      # manufacturer currently has it, so a Filter sidebar can link to
      # all 13 without any of them 404ing. _data/countries.yml (#8) is
      # used as the list of those 13 values -- NOT fetched from
      # Contentful, a manually-maintained shadow of the real schema
      # enum, and not itself locale-specific (it's a country -> language
      # code lookup, not editorial content). If it drifts out of sync
      # (e.g. a manufacturer added from a genuinely new country), that
      # country gets no filter page -- #build_grouped_pages below logs a
      # build warning naming the affected manufacturer(s) when this
      # happens.
      produsenter_pages.concat(
        build_grouped_pages(site, locale, dir, manufacturers, "country", "manufacturer",
                             enum_values: (site.data["countries"] || {}).keys,
                             products_by_manufacturer: products_by_manufacturer)
      )
      link_siblings(produsenter_pages)
      site.pages.concat(produsenter_pages)
    end

    def find_collection(collections, content_type)
      (collections || []).find { |collection| collection["content_type"] == content_type }
    end

    # Every page in `pages` gets the full list (itself included) as
    # page.data["siblings"], for _includes/filter-nav.html to render
    # directly instead of rediscovering this same grouping by scanning
    # site.pages for a matching URL prefix on every render.
    def link_siblings(pages)
      pages.each { |page| page.data["siblings"] = pages }
    end

    # One page per distinct value of `field` among `items`, plus (if
    # `enum_values` is given) one for every declared enum value too, even
    # if nothing currently has it -- so a Filter sidebar can link to all of
    # them without any 404ing (e.g. Produsenter's country filter). Without
    # `enum_values` (e.g. product_type_name/web_product_type_name), only
    # values actually present get a page.
    #
    # `enum_values` is a manually-maintained shadow of Contentful's own
    # field validation, not fetched from Contentful itself -- so an item
    # whose `field` value isn't in that list would otherwise just silently
    # get no filter page, with nothing in the build output pointing at
    # why. Warning here, naming the specific unmatched entries, is the
    # cheapest way to surface that drift without actually querying
    # Contentful's content-type validations.
    def build_grouped_pages(site, locale, dir, items, field, item_type, enum_values: nil, products_by_manufacturer: {})
      grouped = items.group_by { |item| item_field(item, field) }
      grouped.delete(nil)

      if enum_values
        unmatched_values = grouped.keys - enum_values
        unmatched_values.each do |value|
          entry_ids = grouped[value].map { |item| item_field(item, "id") }.join(", ")
          Jekyll.logger.warn LOG_TAG, "#{grouped[value].size} #{item_type}(s) have #{field} \"#{value}\", which isn't in the configured enum_values list -- no filter page will be built for it (entries: #{entry_ids})"
        end
      end

      (enum_values || grouped.keys).map do |value|
        build_page(site, locale, dir, value, grouped[value] || [], "the #{field} filter", item_type, products_by_manufacturer)
      end
    end

    # A Jekyll::Page's fields live in #data (String keys); a manufacturer
    # from site.data.manufacturers is already a plain String-keyed Hash
    # (EntrySerializer#serialize_entry) -- same key, different container.
    # Blank/whitespace-only is treated the same as absent: a real value
    # here becomes a URL segment (see #build_page), and a blank one would
    # otherwise slugify to "" and collide with the collection's root page.
    def item_field(item, field)
      value = (item.respond_to?(:data) ? item.data[field] : item[field]).to_s.strip
      value.empty? ? nil : value
    end

    # value: nil for the "all items" root page, else the filter value
    # (e.g. "Rødvin"). Transliterated ASCII slug (mode: "latin"), not the
    # plain default mode contentful_entries_generator.rb uses for
    # editor-curated `slug` fields -- these come straight from raw field
    # values (country, productTypeName) that do contain Norwegian
    # characters, and there's no reason to keep them in URLs here.
    #
    # label: what's building this page (e.g. "the country filter"),
    # named in a collision warning -- productTypeName and
    # webProductTypeName share one flat URL namespace per Plan.md's own
    # example (`webProductTypeName: Tokaj` -> `/utvalg/tokaj/`, alongside
    # `productTypeName` pages at the same level), so an editor-entered
    # webProductTypeName value that happens to match a productTypeName
    # enum word collides for real, not just in theory -- worth a warning
    # that says exactly which two groupings collided.
    #
    # item_type: "product" or "manufacturer" -- _layouts/listing.html
    # needs to know which card to render `items` with, since a Page and
    # a manufacturer Hash aren't otherwise distinguishable there.
    #
    # products_by_manufacturer: only meaningful for item_type
    # "manufacturer" -- see the class comment. Harmless ({}) for a product
    # listing page, which never reads it.
    def build_page(site, locale, dir, value, items, label, item_type, products_by_manufacturer = {})
      slug = Jekyll::Utils.slugify(value, mode: "latin") if value
      # Same locale.url_prefix convention as EntriesGenerator#build_page
      # (contentful_entries_generator.rb) -- nil for the primary locale,
      # so this is a no-op there.
      page_dir = [locale.url_prefix, dir, slug].compact.join("/")
      page = Jekyll::PageWithoutAFile.new(site, site.source, page_dir, "index.html")

      if @built_dirs.key?(page.url)
        Jekyll.logger.warn LOG_TAG, "#{label} listing page \"#{page.url}\" collides with #{@built_dirs[page.url]} -- only the last one written will survive in the build output"
      end
      @built_dirs[page.url] = label

      page.content = ""
      page.data["layout"] = "listing"
      page.data["title"] = value || dir.capitalize
      page.data["items"] = items
      page.data["item_type"] = item_type
      page.data["products_by_manufacturer"] = products_by_manufacturer
      # Matches EntriesGenerator's own convention: only set (to a real
      # value) for a non-primary locale, so a primary-locale listing page
      # falls back to site.lang for <html lang> exactly like today.
      page.data["locale"] = locale.code unless locale.primary?

      page
    end
  end
end
