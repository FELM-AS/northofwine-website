# "/<dir>/" -- the URL-prefixing convention for site.utvalg_dir /
# site.produsenter_dir (site.config values resolved once by
# _plugins/contentful_listing_pages.rb), previously repeated as its own
# `prepend: "/" | append: "/"` pair at every call site (breadcrumb.html,
# menu.html, filter-nav.html, product.html, 404.html). One filter here
# instead, so the convention only needs to change in one place.
module ContentfulJekyll
  module DirUrlFilter
    def dir_href(dir)
      "/#{dir}/"
    end
  end
end

Liquid::Template.register_filter(ContentfulJekyll::DirUrlFilter)
