require "contentful"
require_relative "contentful_client"
require_relative "contentful_locales"
require_relative "contentful_serializer"
require_relative "contentful_url_registry"

module ContentfulJekyll
  # Jekyll::Generator that reads contentful_collections/
  # contentful_data_collections from _config.yml and turns entries into
  # generated pages or site.data. See CLAUDE.md; entry conversion lives in
  # EntrySerializer, locale resolution in contentful_locales.rb.
  class EntriesGenerator < Jekyll::Generator
    safe true
    priority :high

    # CDA hard limits: 1000 entries per request, up to 10 levels of linked
    # entries resolvable via `include`.
    MAX_PAGE_SIZE = 1000
    MAX_INCLUDE_DEPTH = 10

    # Per-collection/locale values shared by every page build_page makes.
    CollectionContext = Struct.new(:collection, :locale, :serializer, :body_field, :dir, :image_field, keyword_init: true)

    def generate(site)
      client = ContentfulClient.build

      if client.nil?
        missing = ContentfulClient.missing_vars.join(", ")
        # A production build without content would deploy an empty catalog.
        raise Jekyll::Errors::FatalException, "#{LOG_TAG} #{missing} not set, refusing to build production without content" if Jekyll.env == "production"

        Jekyll.logger.warn LOG_TAG, "#{missing} not set, skipping content fetch"
        return
      end

      display_fields = fetch_display_fields(client)
      entry_depth = site.config["contentful_entry_depth"] || EntrySerializer::DEFAULT_ENTRY_DEPTH
      # EntrySerializer never flattens deeper than entry_depth, so asking
      # the CDA to resolve more links than that would be wasted JSON.
      @entry_include_depth = [entry_depth, MAX_INCLUDE_DEPTH].min
      @urls = UrlRegistry.new(site.pages)

      collections = site.config["contentful_collections"] || []
      data_collections = site.config["contentful_data_collections"] || []
      body_fields = body_fields_for(collections + data_collections)

      ContentfulJekyll.each_locale(site.config["contentful_locales"]) do |locale|
        # Fresh EntrySerializer per locale, so its memoization cache never
        # mixes translations across locales.
        serializer = EntrySerializer.new(site, display_fields, entry_depth, body_fields)

        collections.each { |collection| fetch_collection(site, client, collection, locale, serializer) }
        data_collections.each { |collection| fetch_data_collection(site, client, collection, locale, serializer) }
      end
    end

    private

    # Maps content_type id -> snake_cased displayField name, so page.title
    # always resolves correctly regardless of the field's real name.
    # Fetched once, not per locale (schemas aren't locale-specific).
    def fetch_display_fields(client)
      fields = {}

      each_page(client.content_types(order: "sys.id", limit: MAX_PAGE_SIZE), client) do |content_type|
        next if content_type.display_field.nil?

        fields[content_type.id] = Contentful::Support.snakify(content_type.display_field)
      end

      fields
    end

    # Maps content_type id -> configured body_field symbol, from page and
    # data collections alike, so EntrySerializer renders that field via
    # #render_body however the entry is reached (page, site.data, or link).
    def body_fields_for(collections)
      collections.each_with_object({}) do |collection, result|
        next unless collection["body_field"]

        result[collection["content_type"]] = collection["body_field"].to_sym
      end
    end

    def entries_query(collection, locale)
      query = {
        content_type: collection["content_type"],
        order: unique_order(collection["order"] || "-sys.updatedAt"),
        include: @entry_include_depth,
        limit: MAX_PAGE_SIZE
      }
      query[:locale] = locale.code if locale.code
      query
    end

    # Pages are fetched with `skip`, so the order must be unique: entries
    # that tie could otherwise swap between requests, fetching one twice
    # and another not at all. sys.id breaks every tie. Keys are stripped,
    # since the CDA rejects a space after a comma.
    def unique_order(order)
      keys = order.split(",").map(&:strip).reject(&:empty?)
      keys << "sys.id" unless keys.any? { |key| key.delete_prefix("-") == "sys.id" }
      keys.join(",")
    end

    def fetch_collection(site, client, collection, locale, serializer)
      context = CollectionContext.new(
        collection: collection,
        locale: locale,
        serializer: serializer,
        body_field: (collection["body_field"] || "body").to_sym,
        dir: ContentfulJekyll.dir_for(collection, locale),
        image_field: collection["image_field"] || "image"
      )

      each_entry(client, entries_query(collection, locale)) do |entry|
        page = build_page(site, entry, context)
        site.pages << page if page
      end
    end

    # Fetches a content type into site.data.<name> instead of generating a
    # page per entry -- for entries with no page of their own (e.g.
    # manufacturers, people).
    def fetch_data_collection(site, client, collection, locale, serializer)
      name = locale.data_key_for(collection["name"])

      if site.data.key?(name)
        Jekyll.logger.warn LOG_TAG, "site.data.#{name} already exists (e.g. from a _data/#{name}.* file) and will be overwritten by the '#{collection["content_type"]}' data collection"
      end

      entries = []

      each_entry(client, entries_query(collection, locale)) do |entry|
        entries << serializer.serialize_root(entry)
      end

      site.data[name] = entries
    end

    def each_entry(client, query)
      each_page(client.entries(query), client) { |entry| yield entry }
    end

    # Pages through a Contentful::Array result via #next_page, which
    # reuses the original query.
    def each_page(first_page, client)
      page = first_page

      loop do
        page.each { |item| yield item }
        break if page.skip.to_i + page.items.size >= page.total.to_i

        page = page.next_page(client)
        break unless page
      end
    end

    # Returns nil (skipping the entry, with a warning) if the entry has no
    # usable slug -- otherwise its page would land on the bare collection
    # dir (e.g. "/utvalg/") and collide with that section's listing page.
    def build_page(site, entry, context)
      slug = sanitized_slug(entry)

      if slug.empty?
        Jekyll.logger.warn LOG_TAG, "entry #{entry.sys[:id]} (content_type: #{context.collection["content_type"]}) has no slug -- skipping, no page built for it"
        return nil
      end

      page = Jekyll::PageWithoutAFile.new(site, site.source, context.locale.path_for(context.dir, slug), "index.html")
      page.content = context.serializer.render_body(entry.fields[context.body_field])
      page.data["layout"] = context.collection["layout"]
      page.data["locale"] = context.locale.page_code
      page.data.merge!(context.serializer.serialize_root(entry, skip: [context.body_field]))
      # The sanitized slug the URL was built from, not the raw field.
      page.data["slug"] = slug
      # Generic alias for the social preview image (see _includes/seo.html),
      # since content types name that field differently.
      page.data["social_image"] = page.data[context.image_field]
      # The meta description (_includes/seo.html): the body alone, not the
      # layout around it. Unless the content type has its own description.
      page.data["description"] ||= page.content unless page.content.strip.empty?
      @urls.register(page.url, UrlRegistry.label_for(page))

      page
    end

    # The entry's slug run through Jekyll's own slugify (same normalization
    # as post permalinks); "" if it has none.
    def sanitized_slug(entry)
      raw_slug = entry.fields[:slug].to_s
      slug = Jekyll::Utils.slugify(raw_slug)

      if slug != raw_slug && !raw_slug.empty?
        Jekyll.logger.warn LOG_TAG, "slug \"#{raw_slug}\" (entry #{entry.sys[:id]}) isn't URL-safe, using \"#{slug}\" instead"
      end

      slug
    end
  end
end
