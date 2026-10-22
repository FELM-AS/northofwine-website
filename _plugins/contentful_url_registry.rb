require_relative "contentful_locales"

module ContentfulJekyll
  # Tracks which URLs a generator has built, and flags two pages landing
  # on the same URL: only the last one written would survive, silently
  # hiding the other. Fatal in production, so it can't deploy; a warning
  # elsewhere, so one bad Contentful value doesn't block local builds.
  # Names both sides, unlike Jekyll's own "destination shared by multiple
  # files" warning. Seeded with the site's existing pages, so a collision
  # with a static page (e.g. index.html) or an earlier generator's page is
  # caught as well.
  class UrlRegistry
    def initialize(pages)
      @labels = pages.to_h { |page| [page.url, self.class.label_for(page)] }
    end

    # A generated entry page by its entry, anything else by its file.
    def self.label_for(page)
      data = page.data
      return "entry #{data["id"]} \"#{data["title"]}\" (content_type: #{data["content_type"]})" if data["id"]

      "the page #{page.relative_path}"
    end

    def register(url, label)
      if (existing = @labels[url])
        message = "#{label} and #{existing} both produce \"#{url}\" -- change the slug or filter value behind one of them in Contentful so each page gets its own URL"
        raise Jekyll::Errors::FatalException, "#{LOG_TAG} #{message}" if Jekyll.env == "production"

        Jekyll.logger.warn LOG_TAG, "#{message} (only the last one written survives)"
      end
      @labels[url] = label
    end
  end
end
