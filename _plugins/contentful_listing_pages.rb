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
  # Locale-unaware by design for now (unlike EntriesGenerator): doesn't
  # loop contentful_locales, doesn't tag pages with `locale`, doesn't
  # read locale-suffixed site.data keys. contentful_locales isn't
  # configured anywhere in this site yet -- full locale support for this
  # generator is #27/M6, alongside the rest of the site's i18n
  # groundwork. It does still resolve `dir` via `dir_for` (not a raw
  # `collection["dir"]` string), so a `dir` configured as a per-locale
  # Hash fails loudly here rather than silently building a broken path.
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

      # The real primary locale (each_locale's first yield), not a
      # hardcoded Locale.new(nil, nil) stand-in -- that stand-in's `code`
      # is only actually nil when contentful_locales is unconfigured; once
      # it IS configured, the real primary locale's `code` is a genuine
      # value (only its url_prefix is nil, see contentful_locales.rb), so
      # a hardcoded nil `code` would make dir_for look up the wrong key
      # in a per-locale `dir` Hash and raise a misleading error.
      primary_locale = ContentfulJekyll.each_locale(site.config["contentful_locales"]) { |locale| break locale }

      product_collection = find_collection(site.config["contentful_collections"], "product")
      manufacturer_collection = find_collection(site.config["contentful_data_collections"], "manufacturer")

      # id of a product's resolved manufacturer -> Array of that product's
      # page. Computed once here (whether or not the manufacturer section
      # below actually runs) so manufacturer-card.html never has to scan
      # site.pages itself. A product with no resolved manufacturer groups
      # under the nil key, which nothing ever looks up.
      products_by_manufacturer = {}

      if product_collection
        dir = ContentfulJekyll.dir_for(product_collection, primary_locale)
        site.config["utvalg_dir"] = dir
        product_pages = site.pages.select { |page| page.url.start_with?("/#{dir}/") }
        products_by_manufacturer = product_pages.group_by { |page| page.data.dig("manufacturer", "id") }

        utvalg_pages = [build_page(site, dir, nil, product_pages, "the root listing", "product")]
        utvalg_pages.concat(build_grouped_pages(site, dir, product_pages, "product_type_name", "product"))
        utvalg_pages.concat(build_grouped_pages(site, dir, product_pages, "web_product_type_name", "product"))
        link_siblings(utvalg_pages)
        site.pages.concat(utvalg_pages)
      end

      return unless manufacturer_collection && manufacturer_collection["dir"]

      dir = ContentfulJekyll.dir_for(manufacturer_collection, primary_locale)
      site.config["produsenter_dir"] = dir
      manufacturers = site.data["manufacturers"] || []

      produsenter_pages = [build_page(site, dir, nil, manufacturers, "the root listing", "manufacturer", products_by_manufacturer)]
      # Country is a fixed 13-value enum (planning/Contentful-Content-Model.md,
      # Plan-Issues.md #14: "Each of the 13 country values has its own
      # static URL") -- unlike product_type_name/web_product_type_name
      # above, every enum value gets a page regardless of whether a
      # manufacturer currently has it, so a Filter sidebar can link to
      # all 13 without any of them 404ing. _data/countries.yml (#8) is
      # used as the list of those 13 values -- NOT fetched from
      # Contentful, a manually-maintained shadow of the real schema
      # enum. If it drifts out of sync (e.g. a manufacturer added from
      # a genuinely new country), that country gets no filter page --
      # #build_grouped_pages below logs a build warning naming the
      # affected manufacturer(s) when this happens.
      produsenter_pages.concat(
        build_grouped_pages(site, dir, manufacturers, "country", "manufacturer",
                             enum_values: (site.data["countries"] || {}).keys,
                             products_by_manufacturer: products_by_manufacturer)
      )
      link_siblings(produsenter_pages)
      site.pages.concat(produsenter_pages)
    end

    private

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
    def build_grouped_pages(site, dir, items, field, item_type, enum_values: nil, products_by_manufacturer: {})
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
        build_page(site, dir, value, grouped[value] || [], "the #{field} filter", item_type, products_by_manufacturer)
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
    def build_page(site, dir, value, items, label, item_type, products_by_manufacturer = {})
      page_dir = [dir, (Jekyll::Utils.slugify(value, mode: "latin") if value)].compact.join("/")
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

      page
    end
  end
end
