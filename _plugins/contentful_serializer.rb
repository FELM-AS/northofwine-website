require "contentful"
require "digest"
require "kramdown"
require "kramdown-parser-gfm"
require_relative "contentful_rich_text"

module Kramdown
  module Parser
    # GFM for editor text: raw HTML ("<b>", "<!-- -->") and {::...}
    # extensions render as literal text, while Markdown that uses "<"/">"
    # (autolinks, blockquotes) still works. The parsed tree keeps only
    # link/image attributes with safe URLs, so {: ...}/{#id} syntax can't
    # add event handlers, ids or classes.
    class NoHtmlGFM < GFM
      ATTRIBUTES = %w[href src alt title].freeze
      URL_SCHEMES = %w[http https mailto tel].freeze

      def initialize(source, options)
        super
        @block_parsers -= [:block_extensions]
        @span_parsers -= [:span_extensions]
      end

      def parse
        super
        sanitize(@root)
        @footnotes.each_value { |footnote| sanitize(footnote[:content]) }
        @root.options[:abbrev_attr].each_value { |attr| sanitize_attr(attr) }
      end

      protected

      # Kept registered rather than removed: the table parser calls
      # :span_html by name.
      def parse_block_html
        false
      end

      def parse_span_html
        add_text(@src.getch)
      end

      private

      def sanitize(el)
        sanitize_attr(el.attr)
        # Footnote ids are "fn:<name>"; prefixed per text so two
        # descriptions on one page don't share them.
        el.options[:name] = "#{footnote_prefix}-#{el.options[:name]}" if el.type == :footnote
        el.children.each { |child| sanitize(child) }
      end

      def sanitize_attr(attr)
        attr.select! { |name, value| ATTRIBUTES.include?(name) && (!%w[href src].include?(name) || safe_url?(value)) }
      end

      # Browsers ignore control characters and whitespace in a URL's scheme.
      def safe_url?(url)
        scheme = url.gsub(/[\x00-\x20]/, "")[/\A([a-z][a-z0-9+.-]*):/i, 1]
        scheme.nil? || URL_SCHEMES.include?(scheme.downcase)
      end

      def footnote_prefix
        @footnote_prefix ||= Digest::SHA1.hexdigest(source)[0, 8]
      end
    end
  end
end

module ContentfulJekyll
  # Turns a Contentful::Entry into Jekyll-usable data: a flattened field
  # Hash plus rendered body HTML. Pure data transformation, kept separate
  # from EntriesGenerator's build lifecycle (fetching, warnings).
  class EntrySerializer
    # Default recursion depth for flattening linked entries before
    # degrading to a stub. Override via _config.yml's contentful_entry_depth.
    DEFAULT_ENTRY_DEPTH = 2

    # display_fields: content_type id -> snake_cased displayField name
    # (see #flatten_fields). body_fields: content_type id -> body-like
    # field symbol (see EntriesGenerator#body_fields_for), rendered via
    # #render_body instead of plain-stringified like every other field.
    def initialize(site, display_fields, max_entry_depth = DEFAULT_ENTRY_DEPTH, body_fields = {})
      @site = site
      @display_fields = display_fields
      @max_entry_depth = max_entry_depth
      @body_fields = body_fields
      @entry_cache = {}
    end

    # value: a Rich Text document (Hash), a plain/Markdown string, or nil --
    # rendered here, since Jekyll doesn't convert generated index.html pages.
    # A plain string is Markdown without raw HTML (Kramdown::Parser::NoHtmlGFM),
    # so an editor's "<b>" renders literally.
    def render_body(value)
      case value
      when Hash
        rich_text_renderer.render(value)
      when nil
        ""
      else
        markdown_converter.convert(value.to_s.unicode_normalize(:nfc))
      end
    end

    # Flattens entry fields (except `skip`) to a snake_cased Hash. "title"
    # always comes from the content type's displayField, read straight
    # from entry.fields so it's correct even if displayField == skip.
    # This content type's configured body_field (if any) is rendered via
    # #render_body rather than plain-stringified, same as a page's own body.
    def flatten_fields(entry, depth, skip: [])
      content_type = entry.sys[:content_type]&.id
      body_field = @body_fields[content_type]

      data = entry.fields.each_with_object({}) do |(name, value), result|
        next if skip.include?(name)

        result[name.to_s] = name == body_field ? render_body(value) : serialize_field(value, depth)
      end

      display_field = @display_fields[content_type]
      data["title"] = serialize_field(entry.fields[display_field.to_sym], depth) if display_field

      data
    end

    # A fetched (top-level) entry: a generated page's data or one
    # site.data item. Same shape and link depth either way, so templates
    # can treat both alike. Not memoized or frozen -- a page merges it
    # into its own mutable page.data. updated_at feeds the sitemap; set
    # last, so an `updatedAt` field can't replace it.
    def serialize_root(entry, skip: [])
      entry_header(entry).merge(flatten_fields(entry, 0, skip: skip)).merge("updated_at" => entry.sys[:updated_at]&.to_time)
    end

    # Flattens a linked entry like #flatten_fields, so `page.author.title`
    # works directly. Memoized per (entry id, depth), since Contentful's
    # `includes` is already deduplicated. Frozen: the Hash is shared by
    # reference across occurrences and nothing downstream should mutate it.
    def serialize_entry(entry, depth)
      @entry_cache[[entry.sys[:id], depth]] ||= entry_header(entry).merge(flatten_fields(entry, depth + 1)).freeze
    end

    private

    def entry_header(entry)
      { "id" => entry.sys[:id], "content_type" => entry.sys[:content_type]&.id }
    end

    # Recursively converts SDK objects into plain Hashes/Strings Liquid can
    # render (Liquid can't call `.file.url`/`.fields[...]` on raw
    # contentful.rb objects).
    def serialize_field(value, depth = 0)
      case value
      when Contentful::Asset
        serialize_asset(value)
      when Contentful::Entry
        depth >= @max_entry_depth ? reference_stub(value.sys[:id], "Entry") : serialize_entry(value, depth)
      when Contentful::Link
        reference_stub(value.id, value.link_type)
      when Array
        value.map { |item| serialize_field(item, depth) }
      when String
        # Normalized once here for every string field, rather than left
        # to each template (editors do leave stray leading spaces). NFC,
        # so a decomposed "Å" (A + combining ring, as pasted from macOS)
        # sorts, groups and slugifies like the precomposed one.
        value.strip.unicode_normalize(:nfc)
      else
        value
      end
    end

    # Contentful::File only defines methods for keys present in its JSON, so
    # an unprocessed asset (e.g. a draft under CONTENTFUL_PREVIEW) raises on
    # `file.url`. #safe_field guards each read.
    def serialize_asset(asset)
      file = asset.fields[:file]
      url = safe_field(file, :url)
      # `details` is a plain Hash, not a dynamic object -- `["image"]` is
      # just nil for a non-image asset or one still processing.
      image_details = safe_field(file, :details)&.[]("image")

      {
        "url" => url.nil? ? nil : absolute_url(url),
        "content_type" => safe_field(file, :content_type),
        "title" => serialize_field(asset.fields[:title]),
        "description" => serialize_field(asset.fields[:description]),
        "width" => image_details && image_details["width"],
        "height" => image_details && image_details["height"]
      }
    end

    def safe_field(object, method)
      object.respond_to?(method) ? object.public_send(method) : nil
    end

    def reference_stub(id, link_type)
      { "id" => id, "link_type" => link_type }
    end

    # Contentful asset URLs are protocol-relative ("//images.ctfassets.net/...").
    def absolute_url(url)
      url.start_with?("//") ? "https:#{url}" : url
    end

    def rich_text_renderer
      @rich_text_renderer ||= RichTextRenderer::Renderer.new(RICH_TEXT_MAPPINGS.merge(display_fields: @display_fields))
    end

    # Jekyll's own kramdown converter, so the site's Markdown settings apply,
    # with NoHtmlGFM as parser and no heading ids (several descriptions
    # can share a page).
    def markdown_converter
      @markdown_converter ||= begin
        kramdown = (@site.config["kramdown"] || {}).merge("input" => "NoHtmlGFM", "auto_ids" => false)
        Jekyll::Converters::Markdown::KramdownParser.new(@site.config.merge("kramdown" => kramdown))
      end
    end
  end
end
