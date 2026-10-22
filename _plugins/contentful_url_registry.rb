require_relative "contentful_locales"

module ContentfulJekyll
  # Tracks which URLs a generator has built, and fails the build when two
  # pages land on the same URL: only the last one written would survive,
  # silently hiding the other. The error names both sides, unlike
  # Jekyll's own "destination shared by multiple files" warning. Seeded
  # with the site's existing pages, so a collision with a static page
  # (e.g. index.html) or an earlier generator's page is caught as well.
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
        raise Jekyll::Errors::FatalException, "#{LOG_TAG} #{label} and #{existing} both produce \"#{url}\" -- change a slug so each page gets its own URL"
      end
      @labels[url] = label
    end
  end
end
