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
  # ("product_dir"/"manufacturer_dir", see #generate) so _includes/menu.html
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
  # site.config["product_dir"]/["manufacturer_dir"] are set from the
  # *primary* locale only -- _includes/menu.html and breadcrumb.html read
  # them directly and aren't themselves locale-parametrized yet (Plan.md's
  # "reserve a spot for a future language switcher", not "translate the
  # nav now"), so they need one stable, unprefixed value to keep linking
  # to the primary locale's own listing pages.
  class ListingPagesGenerator < Jekyll::Generator
    safe true
    priority :low

    # Per-section constants for a build_page/build_grouped_pages call
    # (computed once in build_product_listing/build_manufacturer_listing/
    # build_about_page and passed as one object), mirroring
    # contentful_entries_generator.rb's own CollectionContext -- both
    # exist to keep build_page from growing an ever-longer param list.
    ListingContext = Struct.new(:dir, :item_type, :products_by_manufacturer, :section_heading, :root_label, keyword_init: true)

    def generate(site)
      # url -> a label for what built it, so a collision warning can name
      # both sides (e.g. "the web_product_type_name filter" colliding
      # with "the product_type_name filter") instead of just "an existing
      # page". Seeded with already-existing pages under that generic label.
      @built_dirs = site.pages.to_h { |page| [page.url, "an existing page"] }

      product_collection = find_collection(site.config["contentful_collections"], "product")
      manufacturer_collection = find_collection(site.config["contentful_data_collections"], "manufacturer")
      person_collection = find_collection(site.config["contentful_data_collections"], "person")

      ContentfulJekyll.each_locale(site.config["contentful_locales"]) do |locale|
        generate_for_locale(site, locale, product_collection, manufacturer_collection, person_collection)
      end
    end

    private

    # One locale pass: builds that locale's own Utvalg/Produsenter
    # root/filter pages, scoped to that locale's own product pages and
    # manufacturers so nothing in a multi-locale build ever mixes one
    # locale's items into another's listing page. Three independent
    # sections -- extracted to their own methods so each section's own
    # locals don't leak into the others' scope; products_by_manufacturer
    # is the only value threaded between two of them.
    def generate_for_locale(site, locale, product_collection, manufacturer_collection, person_collection)
      products_by_manufacturer = build_product_listing(site, locale, product_collection)
      build_manufacturer_listing(site, locale, manufacturer_collection, products_by_manufacturer)
      build_about_page(site, locale, person_collection)
    end

    # Product listing pages (Utvalg): root + product_type_name/
    # web_product_type_name filters. Returns id of a product's resolved
    # manufacturer -> Array of that product's page -- computed here
    # (whether or not the manufacturer section below actually runs) so
    # manufacturer-card.html never has to scan site.pages itself. A
    # product with no resolved manufacturer groups under the nil key,
    # which nothing ever looks up.
    def build_product_listing(site, locale, product_collection)
      return {} unless product_collection

      dir = ContentfulJekyll.dir_for(product_collection, locale)
      site.config["product_dir"] = dir if locale.primary?
      site.config["product_menu_label"] = ContentfulJekyll.label_for(product_collection, "menu_label", locale, "Utvalg") if locale.primary?
      # locale.path_for is the same helper EntriesGenerator's build_page
      # (contentful_entries_generator.rb) uses to prefix a non-primary
      # locale's own generated pages -- using it here too, rather than
      # filtering by page.data["locale"], scopes to this locale's
      # product pages using the exact same URL convention the pages
      # were built with.
      url_dir = locale.path_for(dir)
      product_pages = site.pages.select { |page| page.url.start_with?("/#{url_dir}/") }
      products_by_manufacturer = product_pages.group_by { |page| page.data.dig("manufacturer", "id") }

      context = ListingContext.new(
        dir: dir,
        item_type: "product",
        products_by_manufacturer: {},
        section_heading: ContentfulJekyll.label_for(product_collection, "section_heading", locale, "Vårt utvalg"),
        root_label: ContentfulJekyll.label_for(product_collection, "root_label", locale, "Alle viner")
      )

      utvalg_pages = [build_page(site, locale, nil, product_pages, "the root listing", context)]
      utvalg_pages.concat(build_grouped_pages(site, locale, product_pages, "product_type_name", context))
      utvalg_pages.concat(build_grouped_pages(site, locale, product_pages, "web_product_type_name", context))
      link_siblings(utvalg_pages)
      site.pages.concat(utvalg_pages)

      products_by_manufacturer
    end

    # Manufacturer listing pages (Produsenter): root + country filter.
    def build_manufacturer_listing(site, locale, manufacturer_collection, products_by_manufacturer)
      return unless manufacturer_collection && manufacturer_collection["dir"]

      dir = ContentfulJekyll.dir_for(manufacturer_collection, locale)
      site.config["manufacturer_dir"] = dir if locale.primary?
      site.config["manufacturer_menu_label"] = ContentfulJekyll.label_for(manufacturer_collection, "menu_label", locale, "Produsenter") if locale.primary?
      # locale.data_key_for is the same helper fetch_data_collection
      # (contentful_entries_generator.rb) uses to build the key it writes
      # this collection's entries under -- reading manufacturer_collection
      # ["name"] here (not a hardcoded "manufacturers" literal) is what
      # keeps this in sync if that collection's configured `name` ever
      # changes.
      manufacturers = site.data[locale.data_key_for(manufacturer_collection["name"])] || []

      context = ListingContext.new(
        dir: dir,
        item_type: "manufacturer",
        products_by_manufacturer: products_by_manufacturer,
        section_heading: ContentfulJekyll.label_for(manufacturer_collection, "section_heading", locale, "Våre vinhus"),
        root_label: ContentfulJekyll.label_for(manufacturer_collection, "root_label", locale, "Alle vinhus")
      )

      produsenter_pages = [build_page(site, locale, nil, manufacturers, "the root listing", context)]
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
        build_grouped_pages(site, locale, manufacturers, "country", context, enum_values: (site.data["countries"] || {}).keys)
      )
      link_siblings(produsenter_pages)
      site.pages.concat(produsenter_pages)
    end

    # About page (Om oss): company profile + team members, root page only (no filters).
    def build_about_page(site, locale, person_collection)
      return unless person_collection && person_collection["dir"]

      dir = ContentfulJekyll.dir_for(person_collection, locale)
      about_menu_label = ContentfulJekyll.label_for(person_collection, "menu_label", locale, "Om oss")
      site.config["about_dir"] = dir if locale.primary?
      site.config["about_menu_label"] = about_menu_label if locale.primary?

      people = site.data[locale.data_key_for(person_collection["name"])] || []
      company_profile_people = people.select { |p| p["company_profile"] }
      about_entry = company_profile_people.first
      team_members = people.reject { |p| p["company_profile"] }

      if about_entry.nil?
        Jekyll.logger.warn LOG_TAG, "About (Om oss) page: no person entry with companyProfile=true found. The About page's intro text will be blank."
      elsif company_profile_people.size > 1
        entry_ids = company_profile_people.map { |p| p["id"] }.join(", ")
        Jekyll.logger.warn LOG_TAG, "About (Om oss) page: #{company_profile_people.size} person entries have companyProfile=true (entries: #{entry_ids}) -- only the first is used as the intro, and all of them are excluded from the team list."
      end

      context = ListingContext.new(
        dir: dir,
        item_type: "person",
        products_by_manufacturer: {},
        section_heading: ContentfulJekyll.label_for(person_collection, "section_heading", locale, "Om oss"),
        root_label: about_menu_label
      )

      about_page = build_page(site, locale, nil, team_members, "the root listing", context)
      about_page.data["title"] = about_menu_label
      about_page.data["about_entry"] = about_entry
      site.pages << about_page
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
    def build_grouped_pages(site, locale, items, field, context, enum_values: nil)
      grouped = items.group_by { |item| item_field(item, field) }
      grouped.delete(nil)

      if enum_values
        unmatched_values = grouped.keys - enum_values
        unmatched_values.each do |value|
          entry_ids = grouped[value].map { |item| item_field(item, "id") }.join(", ")
          Jekyll.logger.warn LOG_TAG, "#{grouped[value].size} #{context.item_type}(s) have #{field} \"#{value}\", which isn't in the configured enum_values list -- no filter page will be built for it (entries: #{entry_ids})"
        end
      end

      (enum_values || grouped.keys).map do |value|
        build_page(site, locale, value, grouped[value] || [], "the #{field} filter", context)
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
    # item_type (on `context`): "product", "manufacturer", or "person" --
    # _layouts/listing.html needs to know which card to render `items`
    # with, since a Page and a manufacturer/person Hash aren't otherwise
    # distinguishable there.
    #
    # products_by_manufacturer (on `context`): only meaningful for
    # item_type "manufacturer" -- see the class comment. Harmless ({})
    # for a product/person listing page, which never reads it.
    def build_page(site, locale, value, items, label, context)
      slug = Jekyll::Utils.slugify(value, mode: "latin") if value
      page_dir = locale.path_for(context.dir, slug)
      page = Jekyll::PageWithoutAFile.new(site, site.source, page_dir, "index.html")

      if @built_dirs.key?(page.url)
        Jekyll.logger.warn LOG_TAG, "#{label} listing page \"#{page.url}\" collides with #{@built_dirs[page.url]} -- only the last one written will survive in the build output"
      end
      @built_dirs[page.url] = label

      page.content = ""
      page.data["layout"] = "listing"
      page.data["title"] = value || context.dir.capitalize
      page.data["description"] = description_for(context.item_type, value, label)
      page.data["items"] = items
      page.data["item_type"] = context.item_type
      page.data["products_by_manufacturer"] = context.products_by_manufacturer
      page.data["section_heading"] = context.section_heading if context.section_heading
      page.data["root_nav_label"] = context.root_label if value.nil? && context.root_label
      # Matches EntriesGenerator's own convention: only set (to a real
      # value) for a non-primary locale, so a primary-locale listing page
      # falls back to site.lang for <html lang> exactly like today.
      page.data["locale"] = locale.code unless locale.primary?

      page
    end

    # Plan-Issues.md #33 ("Manufacturer/Om oss/Hjem get sensible
    # page-specific defaults"): page.content is "" on every listing page
    # (see #build_page above), so without an explicit page.description,
    # _includes/seo.html's generic fallback would fall through to the
    # rendered card list instead -- a meaningless run-on of product/
    # manufacturer card text truncated at 160 characters, not a sentence.
    #
    # Hardcoded Norwegian, unlike dir_for/home_label_for (contentful_locales.rb),
    # which support a Hash-keyed-by-locale-code override for exactly this
    # kind of "content that needs translating beyond what the prefix
    # covers" (CLAUDE.md's Locales section) -- there's no second locale
    # to translate for yet (_config.yml's contentful_locales is still
    # just [nb-NO]), so this follows the same "reserved, not built"
    # precedent as the header/footer's language-switcher spot. Give this
    # the same locale-aware treatment once a second locale actually
    # exists, or every non-primary-locale listing page will silently
    # keep this Norwegian text instead of erroring.
    def description_for(item_type, value, label)
      case item_type
      when "product"
        value ? "#{value} i North of Wine sitt vinutvalg." : "Hele vinutvalget til North of Wine, vinimportør i Trondheim."
      when "manufacturer"
        value ? "Vinprodusenter fra #{value} i North of Wine sitt utvalg." : "Vinprodusentene bak North of Wine sitt vinutvalg."
      when "person"
        "Om North of Wine: selskap, lagmedlemmer og verdier."
      else
        # Not reachable today -- build_page is only ever called with
        # "product"/"manufacturer"/"person" (see #generate above). Warn loudly
        # rather than silently returning nil: a nil page.data["description"]
        # would resurrect the exact garbled-fallback bug this method
        # exists to prevent, with nothing in the build log to explain why.
        Jekyll.logger.warn LOG_TAG, "description_for has no description template for item_type \"#{item_type}\" (#{label}) -- this page's meta description will fall back to its own rendered content instead"
        nil
      end
    end

  end
end
