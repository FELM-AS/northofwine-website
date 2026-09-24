# Small Liquid filters shared across templates, so a convention only
# needs to change in one place instead of being repeated at every call
# site:
#
# `dir_href`: "/<dir>/" -- the URL-prefixing convention for
# site.product_dir/site.manufacturer_dir (site.config values resolved once
# by _plugins/contentful_listing_pages.rb), previously repeated as its
# own `prepend: "/" | append: "/"` pair at every call site (breadcrumb.html,
# menu.html, filter.html, product.html, 404.html).
#
# A nil/blank `dir` (e.g. contentful_data_collections' manufacturer entry
# missing its optional `dir`, so site.manufacturer_dir is never set) would
# otherwise silently build "//" -- a broken link with no build warning,
# since every call site trusts this filter rather than guarding itself.
# Raising here, the one shared place, catches it loudly instead.
#
# `country_lang`: see its own comment below.
# `nb_number`: see its own comment below.
# `unescape_html`: see its own comment below.
require "cgi"

module ContentfulJekyll
  module TemplateFilters
    def dir_href(dir)
      raise "dir_href: no dir given -- a site.config value like site.product_dir/site.manufacturer_dir is nil or blank. Is the corresponding collection's `dir` set in _config.yml?" if dir.to_s.empty?

      "/#{dir}/"
    end

    # Norwegian numeric convention (Plan.md's Formatting section): comma
    # decimal separator instead of a period. Used on salesPrice,
    # alcoholContent, volume, and the 1-12 sensory scale values -- one
    # filter instead of each template re-implementing the same `.to_s.sub`.
    #
    # `decimals`, when given, formats to that many fixed decimal places
    # first (e.g. `550 | nb_number: 2` -> "550,00", for a price that
    # should always show cents even when the Contentful value is a whole
    # number). Without it, the value's own precision is kept as-is and
    # only the separator changes (e.g. alcoholContent "13.5" -> "13,5",
    # while a whole-number field like volume or the sensory Symbol
    # fields -- which never contain a "." to begin with -- pass through
    # unchanged).
    #
    # nil/blank passes through untouched, so `{% if page.field %}` guards
    # at call sites don't need to also special-case this filter.
    def nb_number(value, decimals = nil)
      return value if value.nil? || value.to_s.empty?

      formatted = decimals ? format("%.#{decimals}f", value.to_f) : value.to_s
      formatted.sub(".", ",")
    end

    # Manufacturer/product `country` (a fixed enum, see _data/countries.yml)
    # -> language code, for the `lang` attribute on product/manufacturer
    # names (planning/Plan.md's Formatting/Hyphenation sections). One
    # filter here instead of product-card.html and manufacturer-card.html
    # each indexing site.data.countries independently, so both stay in
    # sync with a single lookup.
    def country_lang(country)
      @context.registers[:site].data["countries"][country]
    end

    # _includes/seo.html's meta-description fallback runs `strip_html` on
    # a page's already-*rendered* `content` -- `strip_html` removes tags
    # but leaves HTML entities like `&quot;`/`&amp;` as literal text,
    # which then get escaped a *second* time when interpolated into the
    # meta tag (`&quot;` -> `&amp;quot;`). Live today via a product's own
    # Rich Text body: an embedded entry renders as
    # `CGI.escapeHTML(title)` (contentful_rich_text.rb), so a product
    # whose Rich Text embeds another entry with a `&`/`"` in its title
    # hits this exact double-escape. (Listing pages -- the case this was
    # first written against -- no longer can: contentful_listing_pages.rb
    # now always sets an explicit page.description, so `default: content`
    # never reaches their card markup. Kept general rather than
    # listing-page-specific, since this is still a real, live path.)
    # Unescaping once here, between `strip_html` and the final `| escape`,
    # undoes exactly that one extra round of escaping.
    #
    # This filter also runs before seo.html's `normalize_whitespace`,
    # so a decoded `&nbsp;` (-> a literal U+00A0 non-breaking space)
    # needs handling here too: Ruby's `\s` (what normalize_whitespace
    # matches on) doesn't treat U+00A0 as whitespace, so left as-is it
    # would survive as a visually-blank but non-collapsing character --
    # e.g. a copy-pasted "word&nbsp;&nbsp;word" would decode to two
    # non-breaking spaces that normalize_whitespace can't collapse to
    # one, unlike two literal spaces. Converted to a plain space here
    # instead, so normalize_whitespace still sees only ordinary
    # whitespace.
    def unescape_html(value)
      CGI.unescapeHTML(value.to_s).tr(" ", " ")
    end
  end
end

Liquid::Template.register_filter(ContentfulJekyll::TemplateFilters)
