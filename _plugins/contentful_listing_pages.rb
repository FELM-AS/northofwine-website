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
  # Also stashes each collection's resolved `dir` onto site.config (see
  # RESOLVED_DIR_KEYS) so _includes/menu.html and _includes/breadcrumb.html
  # can read a plain, already-locale-resolved string instead of each
  # independently re-deriving it in Liquid -- a `dir` configured as a
  # per-locale Hash (see dir_for below) would otherwise silently
  # stringify into a broken href in those templates.
  #
  # Locale-unaware by design for now (unlike EntriesGenerator): doesn't
  # loop contentful_locales, doesn't tag pages with `locale`, doesn't
  # read locale-suffixed site.data keys. contentful_locales isn't
  # configured anywhere in this site yet -- full locale support for this
  # generator is #27/M6, alongside the rest of the site's i18n
  # groundwork. It does still resolve `dir` via `dir_for` (not a raw
  # `collection["dir"]` string), so a `dir` configured as a per-locale
  # Hash fails loudly here rather than silently building a broken path.
  #
  # Content is placeholder-minimal for now (see _layouts/listing.html) --
  # the real Product/Manufacturer-card rendering lands once those
  # components exist.
  class ListingPagesGenerator < Jekyll::Generator
    safe true
    priority :low

    LOG_TAG = "Contentful:"

    # Matches the primary-locale case of ContentfulJekyll.each_locale
    # when contentful_locales isn't configured -- see the class comment.
    PRIMARY_LOCALE = Locale.new(nil, nil)

    def generate(site)
      # url -> a label for what built it, so a collision warning can name
      # both sides (e.g. "the web_product_type_name filter" colliding
      # with "the product_type_name filter") instead of just "an existing
      # page". Seeded with already-existing pages under that generic label.
      @built_dirs = site.pages.to_h { |page| [page.url, "an existing page"] }

      product_collection = find_collection(site.config["contentful_collections"], "product")
      manufacturer_collection = find_collection(site.config["contentful_data_collections"], "manufacturer")

      if product_collection
        dir = ContentfulJekyll.dir_for(product_collection, PRIMARY_LOCALE)
        site.config["utvalg_dir"] = dir
        product_pages = site.pages.select { |page| page.url.start_with?("/#{dir}/") }

        site.pages << build_page(site, dir, nil, product_pages, "the root listing", "product")
        build_filter_pages(site, dir, product_pages, "product_type_name", "product")
        build_filter_pages(site, dir, product_pages, "web_product_type_name", "product")
      end

      return unless manufacturer_collection && manufacturer_collection["dir"]

      dir = ContentfulJekyll.dir_for(manufacturer_collection, PRIMARY_LOCALE)
      site.config["produsenter_dir"] = dir
      manufacturers = site.data["manufacturers"] || []
      site.pages << build_page(site, dir, nil, manufacturers, "the root listing", "manufacturer")
      # Country is a fixed 13-value enum (planning/Contentful-Content-Model.md,
      # Plan-Issues.md #14: "Each of the 13 country values has its own
      # static URL") -- unlike product_type_name/web_product_type_name
      # below, every enum value gets a page regardless of whether a
      # manufacturer currently has it, so a Filter sidebar can link to
      # all 13 without any of them 404ing. _data/countries.yml (#8) is
      # used as the list of those 13 values -- NOT fetched from
      # Contentful, a manually-maintained shadow of the real schema
      # enum. If it drifts out of sync (e.g. a manufacturer added from
      # a genuinely new country), that country gets no filter page and
      # no build warning -- see the roadmap's "Known limitations".
      build_enum_pages(site, dir, manufacturers, "country", (site.data["countries"] || {}).keys, "manufacturer")
    end

    private

    def find_collection(collections, content_type)
      (collections || []).find { |collection| collection["content_type"] == content_type }
    end

    # One page per distinct value of `field` actually present among
    # `items` (the root "all items" page is built separately -- see
    # #generate -- since a collection can have more than one grouping
    # field, but only one root).
    def build_filter_pages(site, dir, items, field, item_type)
      grouped = items.group_by { |item| item_field(item, field) }
      grouped.delete(nil)

      grouped.each do |value, matching_items|
        site.pages << build_page(site, dir, value, matching_items, "the #{field} filter", item_type)
      end
    end

    # Like #build_filter_pages, but one page per value in `enum_values`
    # -- every one of them, not just values actually present among
    # `items` (possibly an empty list for a value nothing currently has).
    def build_enum_pages(site, dir, items, field, enum_values, item_type)
      grouped = items.group_by { |item| item_field(item, field) }

      enum_values.each do |value|
        site.pages << build_page(site, dir, value, grouped[value] || [], "the #{field} filter", item_type)
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
    def build_page(site, dir, value, items, label, item_type)
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

      page
    end
  end
end
