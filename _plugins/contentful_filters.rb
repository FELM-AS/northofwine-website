# Small Liquid filters shared across templates, so a convention only
# needs to change in one place instead of being repeated at every call
# site:
#
# `dir_href`: "/<dir>/" -- the URL-prefixing convention for
# site.utvalg_dir/site.produsenter_dir (site.config values resolved once
# by _plugins/contentful_listing_pages.rb), previously repeated as its
# own `prepend: "/" | append: "/"` pair at every call site (breadcrumb.html,
# menu.html, filter-nav.html, product.html, 404.html).
#
# A nil/blank `dir` (e.g. contentful_data_collections' manufacturer entry
# missing its optional `dir`, so site.produsenter_dir is never set) would
# otherwise silently build "//" -- a broken link with no build warning,
# since every call site trusts this filter rather than guarding itself.
# Raising here, the one shared place, catches it loudly instead.
#
# `country_lang`: see its own comment below.
module ContentfulJekyll
  module TemplateFilters
    def dir_href(dir)
      raise "dir_href: no dir given -- a site.config value like site.utvalg_dir/site.produsenter_dir is nil or blank. Is the corresponding collection's `dir` set in _config.yml?" if dir.to_s.empty?

      "/#{dir}/"
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
  end
end

Liquid::Template.register_filter(ContentfulJekyll::TemplateFilters)
