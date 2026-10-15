require "cgi"
require_relative "i18n"

module ContentfulJekyll
  # Small Liquid filters shared across templates, so a convention only
  # needs to change in one place.
  module TemplateFilters
    # UI text from _data/i18n/<locale>.yml in the current page's locale
    # (see i18n.rb): {{ "menu.open" | t }}, or with placeholders,
    # {{ "product.see" | t: title: product.title }}. The result isn't
    # escaped -- escape it where a placeholder carries editor content.
    def t(key, vars = {})
      page = @context.registers[:page]
      I18n.translate(@context.registers[:site], page && page["locale"], key, vars)
    end

    # "/<dir>/" for a site.config dir set by contentful_listing_pages.rb
    # (site.product_dir, site.manufacturer_dir, site.about_dir). Raises on
    # a nil/blank dir rather than silently building a broken "//" link.
    def dir_href(dir)
      raise "dir_href: no dir given -- a site.config value like site.product_dir/site.manufacturer_dir is nil or blank. Is the corresponding collection's `dir` set in _config.yml?" if dir.to_s.empty?

      "/#{dir}/"
    end

    # Norwegian numeric convention (Plan.md's Formatting section): comma
    # decimal separator instead of a period.
    #
    # `decimals`, when given, formats to that many fixed decimal places
    # first (e.g. `550 | nb_number: 2` -> "550,00"). Without it, the
    # value's own precision is kept and only the separator changes
    # (e.g. "13.5" -> "13,5"). nil/blank passes through untouched.
    def nb_number(value, decimals = nil)
      return value if value.nil? || value.to_s.empty?

      formatted = decimals ? format("%.#{decimals}f", value.to_f) : value.to_s
      formatted.sub(".", ",")
    end

    # Manufacturer `country` -> language code (_data/countries.yml), for
    # the `lang` attribute on product/manufacturer names (Plan.md's
    # Formatting/Hyphenation sections). nil if unknown.
    def country_lang(country)
      @context.registers[:site].data.dig("countries", country)
    end

    # For _includes/seo.html's meta-description fallback, between
    # `strip_html` and the final `| escape`: strip_html leaves entities
    # like `&quot;` (e.g. from an embedded entry's escaped title in Rich
    # Text) as literal text, which `escape` would double-escape into
    # `&amp;quot;`. Also turns a decoded `&nbsp;` into a plain space, since
    # normalize_whitespace's `\s` doesn't match U+00A0.
    def unescape_html(value)
      CGI.unescapeHTML(value.to_s).tr(" ", " ")
    end

    # A manufacturer `link` without its protocol, for display. Matches the
    # ftp/http/https protocols that field's Contentful validation allows,
    # case-insensitively (Liquid's `remove` is case-sensitive).
    def strip_protocol(value)
      value.to_s.sub(/\A(ftp|https?):\/\//i, "")
    end
  end
end

Liquid::Template.register_filter(ContentfulJekyll::TemplateFilters)
