require "jekyll"
require_relative "contentful_locales"
require_relative "contentful_url_registry"
require_relative "i18n"

module ContentfulJekyll
  # Second generator, running after EntriesGenerator (priority :low): the
  # listing pages for Utvalg (products, filtered by productTypeName and
  # webProductTypeName), Produsenter (manufacturers, filtered by country)
  # and Om oss (people). A section's root "all items" page is built the
  # same way as its filter pages, so each section has one URL mechanism.
  # Deliberately these hardcoded sections, not a generic grouping framework.
  #
  # Cross-references are computed here once per build, so no template has
  # to rediscover them by scanning site.pages:
  # - site.config["<section>_dir"] (product, manufacturer, about): the
  #   primary locale's resolved dir, for the nav. The nav isn't
  #   locale-aware yet, so it links to the primary locale's pages.
  # - page.siblings on every Utvalg/Produsenter listing page: the section's
  #   listing pages, for navigation/filter.html.
  # - page.breadcrumb on every product page: see #link_breadcrumbs.
  # - page.products_by_manufacturer on Produsenter pages: manufacturer id
  #   -> that manufacturer's product pages, for manufacturer-card.html.
  #
  # Listing copy (titles, headings, meta descriptions) comes from the
  # locale's UI dictionary, under sections.<content_type> in
  # _data/i18n/<locale>.yml (see i18n.rb).
  class ListingPagesGenerator < Jekyll::Generator
    safe true
    priority :low

    # Per-section values shared by every page #build_page makes for it.
    ListingContext = Struct.new(:collection, :locale, :dir, :item_type, keyword_init: true)

    def generate(site)
      @urls = UrlRegistry.new(site.pages)

      product_collection = find_collection(site.config["contentful_collections"], "product")
      manufacturer_collection = find_collection(site.config["contentful_data_collections"], "manufacturer")
      person_collection = find_collection(site.config["contentful_data_collections"], "person")

      # Each pass only sees its own locale's product pages and site.data,
      # so no listing page mixes items across locales.
      ContentfulJekyll.each_locale(site.config["contentful_locales"]) do |locale|
        products_by_manufacturer = build_product_listing(site, locale, product_collection)
        build_manufacturer_listing(site, locale, manufacturer_collection, products_by_manufacturer)
        build_about_page(site, locale, person_collection)
      end
    end

    private

    # Utvalg: root + productTypeName/webProductTypeName filter pages, which
    # share one flat URL namespace (/utvalg/rodvin/, /utvalg/tokaj/).
    # Returns manufacturer id -> that manufacturer's product pages.
    def build_product_listing(site, locale, collection)
      return {} unless collection

      context = section_context(site, locale, collection, "product", "product")
      products = nb_sort(
        site.pages.select do |page|
          page.data["content_type"] == collection["content_type"] && page.data["locale"] == locale.page_code
        end,
        "title"
      )

      root = build_page(site, nil, products, "the product root listing", context)
      filter_pages = build_grouped_pages(site, products, "product_type_name", context) +
                     build_grouped_pages(site, products, "web_product_type_name", context)
      link_breadcrumbs(root, filter_pages)
      add_section(site, [root, *filter_pages])

      products.group_by { |page| page.data.dig("manufacturer", "id") }
    end

    # Produsenter: root + country filter pages.
    def build_manufacturer_listing(site, locale, collection, products_by_manufacturer)
      return unless collection && collection["dir"]

      context = section_context(site, locale, collection, "manufacturer", "manufacturer")
      manufacturers = nb_sort(site.data[locale.data_key_for(collection["name"])] || [], "title")

      pages = [
        build_page(site, nil, manufacturers, "the manufacturer root listing", context),
        *build_grouped_pages(site, manufacturers, "country", context)
      ]
      pages.each { |page| page.data["products_by_manufacturer"] = products_by_manufacturer }
      warn_missing_country_langs(site, manufacturers)
      add_section(site, pages)
    end

    # Om oss: the companyProfile person's text as the intro, every other
    # person as a team member. One page, no filters (so no siblings).
    def build_about_page(site, locale, collection)
      return unless collection && collection["dir"]

      context = section_context(site, locale, collection, "about", "person")
      people = nb_sort(site.data[locale.data_key_for(collection["name"])] || [], "title")
      profiles, team_members = people.partition { |person| person["company_profile"] }

      if profiles.empty?
        Jekyll.logger.warn LOG_TAG, "About (Om oss) page: no person entry with companyProfile=true found. The About page will have no intro."
      elsif profiles.size > 1
        Jekyll.logger.warn LOG_TAG, "About (Om oss) page: #{profiles.size} person entries have companyProfile=true (entries: #{profiles.map { |p| p["id"] }.join(", ")}) -- only the first is used as the intro, and all of them are excluded from the team list."
      end

      page = build_page(site, nil, team_members, "the about page", context)
      page.data["about_entry"] = profiles.first
      page.data["updated_at"] = latest_update([*team_members, *profiles])
      site.pages << page
    end

    # Resolves the section's dir for this locale and, for the primary
    # locale, exposes it to the nav templates.
    def section_context(site, locale, collection, nav_key, item_type)
      context = ListingContext.new(
        collection: collection,
        locale: locale,
        dir: ContentfulJekyll.dir_for(collection, locale),
        item_type: item_type
      )

      site.config["#{nav_key}_dir"] = context.dir if locale.primary?

      context
    end

    def find_collection(collections, content_type)
      (collections || []).find { |collection| collection["content_type"] == content_type }
    end

    # Every page in a section gets the full list (itself included) as
    # page.data["siblings"], for navigation/filter.html.
    def add_section(site, pages)
      pages.each { |page| page.data["siblings"] = pages }
      site.pages.concat(pages)
    end

    # Each product page gets page.data["breadcrumb"]: the root listing,
    # then the filter pages it appears on in build order (productTypeName,
    # then webProductTypeName), for navigation/breadcrumb.html and
    # structured-data.html.
    def link_breadcrumbs(root, filter_pages)
      root.data["items"].each { |product| product.data["breadcrumb"] = [root] }
      filter_pages.each do |filter_page|
        filter_page.data["items"].each { |product| product.data["breadcrumb"] << filter_page }
      end
    end

    # One page per distinct value of `field` among `items`, in Norwegian
    # alphabetical order -- only values actually present get a page, so a
    # filter never links to an empty one.
    def build_grouped_pages(site, items, field, context)
      grouped = items.group_by { |item| item_field(item, field) }
      grouped.delete(nil)

      grouped.keys.sort_by { |value| nb_sort_key(value) }.map do |value|
        build_page(site, value, grouped[value], "the #{field} filter", context)
      end
    end

    # Norwegian alphabetical order by `field`. Contentful's own `order`
    # (_config.yml) can't do this: the CDA has no collation parameter and
    # folds accents to their base letter, so "Åge Aleksandersen" sorts as
    # "Age..." instead of after Z. Its order is still the tiebreaker here
    # (`index`), since sort_by isn't stable.
    def nb_sort(items, field)
      items.each_with_index.sort_by { |item, index| [nb_sort_key(item_field(item, field)), index] }.map(&:first)
    end

    # Æ/Ø/Å go after Z, in that order (ä/ö too, as in Norwegian
    # dictionaries); every other accented letter sorts as its base letter
    # (é -> e, ü -> u), and case is ignored.
    NB_LAST_LETTERS = { "æ" => "{", "ä" => "{", "ø" => "|", "ö" => "|", "å" => "}" }.freeze

    def nb_sort_key(value)
      value.to_s.downcase
        .gsub(/[æäøöå]/, NB_LAST_LETTERS)
        .unicode_normalize(:nfd).gsub(/\p{Mn}/, "")
    end

    # _data/countries.yml is a manually-maintained country -> language
    # lookup. A country missing from it makes names from those
    # manufacturers lose their `lang` attribute -- warn so it gets added.
    def warn_missing_country_langs(site, manufacturers)
      langs = site.data["countries"] || {}
      manufacturers.group_by { |m| item_field(m, "country") }.each do |country, group|
        next if country.nil? || langs.key?(country)

        entry_ids = group.map { |m| item_field(m, "id") }.join(", ")
        Jekyll.logger.warn LOG_TAG, "country \"#{country}\" has no language code in _data/countries.yml -- names from these manufacturers get no lang attribute (entries: #{entry_ids})"
      end
    end

    # Reads `field` off a product Page (#data) or a site.data Hash alike.
    # Blank counts as absent: a value becomes a URL segment, and a blank
    # one would slugify to "" and collide with the section's root page.
    def item_field(item, field)
      value = (item.respond_to?(:data) ? item.data[field] : item[field]).to_s.strip
      value.empty? ? nil : value
    end

    # value: nil for the root "all items" page, else the filter value
    # (e.g. "Rødvin"), transliterated to an ASCII slug (mode: "latin").
    # label: what's building this page, named in a URL collision warning.
    def build_page(site, value, items, label, context)
      slug = Jekyll::Utils.slugify(value, mode: "latin") if value
      page = Jekyll::PageWithoutAFile.new(site, site.source, context.locale.path_for(context.dir, slug), "index.html")
      @urls.register(page.url, label)

      menu_label = section_text(site, context, "menu_label")
      page.content = ""
      page.data["layout"] = "listing"
      page.data["title"] = value || menu_label
      # Explicit, since the generic fallback in _includes/seo.html would
      # otherwise truncate the rendered card markup into a meta description.
      page.data["description"] = value ? section_text(site, context, "filter_description", "value" => value) : section_text(site, context, "root_description")
      page.data["items"] = items
      page.data["updated_at"] = latest_update(items)
      page.data["item_type"] = context.item_type
      page.data["section_heading"] = section_text(site, context, "section_heading")
      page.data["root_nav_label"] = root_label(site, context) || menu_label unless value
      page.data["locale"] = context.locale.page_code

      page
    end

    # The newest Contentful update among `items`, for the sitemap's
    # <lastmod>; nil if none has one.
    def latest_update(items)
      items.filter_map { |item| item.respond_to?(:data) ? item.data["updated_at"] : item["updated_at"] }.max
    end

    def section_text(site, context, key, vars = {})
      I18n.translate(site, context.locale.code, "sections.#{context.collection["content_type"]}.#{key}", vars)
    end

    # Optional, unlike the other section keys: nil if the dictionary has none.
    def root_label(site, context)
      I18n.lookup(site, context.locale.code, "sections.#{context.collection["content_type"]}.root_label")
    end
  end
end
