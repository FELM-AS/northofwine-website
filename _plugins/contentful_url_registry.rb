require_relative "contentful_locales"

module ContentfulJekyll
  # Tracks which URLs a generator has built, so two pages landing on the
  # same URL get a warning naming both sides. Jekyll's own "destination
  # shared by multiple files" warning fires too, but names neither.
  # Seeded with the site's existing pages, so a collision with a static
  # page (e.g. index.html) is caught as well.
  class UrlRegistry
    def initialize(pages)
      @labels = pages.to_h { |page| [page.url, "an existing page"] }
    end

    def register(url, label)
      if (existing = @labels[url])
        Jekyll.logger.warn LOG_TAG, "#{label} produced \"#{url}\", which collides with #{existing} -- only the last one written will survive in the build output"
      end
      @labels[url] = label
    end
  end
end
