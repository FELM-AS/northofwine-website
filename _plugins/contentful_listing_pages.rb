require "set"
require "jekyll"

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
  # Content is placeholder-minimal for now (see _layouts/listing.html) --
  # the real Product/Manufacturer-card rendering lands once those
  # components exist.
  class ListingPagesGenerator < Jekyll::Generator
    safe true
    priority :low

    LOG_TAG = "Contentful:"

    def generate(site)
      @built_dirs = Set.new(site.pages.map(&:url))

      product_collection = find_collection(site.config["contentful_collections"], "product")
      manufacturer_collection = find_collection(site.config["contentful_data_collections"], "manufacturer")

      if product_collection
        product_pages = site.pages.select do |page|
          page.url.start_with?("/#{product_collection["dir"]}/") && page.data["product_type_name"]
        end

        site.pages << build_page(site, product_collection["dir"], nil, product_pages)
        build_filter_pages(site, product_collection["dir"], product_pages, "product_type_name")
        build_filter_pages(site, product_collection["dir"], product_pages, "web_product_type_name")
      end

      return unless manufacturer_collection && manufacturer_collection["dir"]

      manufacturers = site.data["manufacturers"] || []
      site.pages << build_page(site, manufacturer_collection["dir"], nil, manufacturers)
      build_filter_pages(site, manufacturer_collection["dir"], manufacturers, "country")
    end

    private

    def find_collection(collections, content_type)
      (collections || []).find { |collection| collection["content_type"] == content_type }
    end

    # One page per distinct value of `field` among `items` (the root "all
    # items" page is built separately -- see #generate -- since a
    # collection can have more than one grouping field, but only one root).
    def build_filter_pages(site, dir, items, field)
      grouped = items.group_by { |item| item_field(item, field) }
      grouped.delete(nil)

      grouped.each do |value, matching_items|
        site.pages << build_page(site, dir, value, matching_items)
      end
    end

    # A Jekyll::Page's fields live in #data (String keys); a manufacturer
    # from site.data.manufacturers is already a plain String-keyed Hash
    # (EntrySerializer#serialize_entry) -- same key, different container.
    def item_field(item, field)
      item.respond_to?(:data) ? item.data[field] : item[field]
    end

    # value: nil for the "all items" root page, else the filter value
    # (e.g. "Rødvin"). Transliterated ASCII slug (mode: "latin"), not the
    # plain default mode contentful_entries_generator.rb uses for
    # editor-curated `slug` fields -- these come straight from raw field
    # values (country, productTypeName) that do contain Norwegian
    # characters, and there's no reason to keep them in URLs here.
    def build_page(site, dir, value, items)
      page_dir = [dir, (Jekyll::Utils.slugify(value, mode: "latin") if value)].compact.join("/")
      page = Jekyll::PageWithoutAFile.new(site, site.source, page_dir, "index.html")

      unless @built_dirs.add?(page.url)
        Jekyll.logger.warn LOG_TAG, "listing page \"#{page.url}\" collides with an existing page -- only the last one written will survive in the build output"
      end

      page.content = ""
      page.data["layout"] = "listing"
      page.data["title"] = value || dir.capitalize
      page.data["filter_value"] = value
      page.data["items"] = items

      page
    end
  end
end
