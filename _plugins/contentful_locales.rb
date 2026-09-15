module ContentfulJekyll
  # code: locale to query, nil = no `locale` param (space's default).
  # url_prefix: nil for the primary locale, else its URL prefix. code and
  # url_prefix are both nil in different cases (no locales configured vs.
  # the primary locale), so call sites must check #primary?, not either
  # field directly.
  Locale = Struct.new(:code, :url_prefix) do
    def primary?
      url_prefix.nil?
    end

    # site.data key suffix: url_prefix lowercased, "-" -> "_" for valid
    # Liquid dot-notation. Derived, never stored, so it can't desync from
    # url_prefix.
    def data_suffix
      url_prefix&.downcase&.tr("-", "_")
    end

    # The site.data key for a locale-scoped collection fetched under
    # `base` (e.g. "manufacturers") -- `base` for the primary locale,
    # "<base>_<data_suffix>" for any other. Both contentful_entries_
    # generator.rb#fetch_data_collection (which writes this key) and
    # contentful_listing_pages.rb (which reads it back) call this, so the
    # naming convention can't drift between the two -- previously each
    # computed `[base, data_suffix].compact.join("_")` independently.
    def data_key_for(base)
      [base, data_suffix].compact.join("_")
    end

    # Joins `parts` into a URL path prefixed with this locale's own
    # url_prefix (nil, a no-op, for the primary locale) -- the same
    # locale-prefixing convention data_key_for applies to site.data keys,
    # applied to URL paths instead. contentful_entries_generator.rb#
    # build_page and contentful_listing_pages.rb#build_page both call
    # this rather than each joining `[locale.url_prefix, ...]` inline, so
    # the two can't independently drift on how blank/nil path segments
    # get dropped.
    def path_for(*parts)
      [url_prefix, *parts].reject { |part| part.to_s.empty? }.join("/")
    end
  end

  # Yields one Locale per contentful_locales entry, first = primary. A
  # nil/empty config yields a single Locale.new(nil, nil), identical to a
  # build with no locale support (the `.empty?` check matters: an explicit
  # `[]` would otherwise silently iterate zero entries and fetch nothing).
  # A configured single-entry list still sends an explicit `locale:` on
  # every query, unlike the unconfigured case, so it never silently falls
  # back to the space's default locale instead.
  #
  # An entry is a plain locale code (prefix == code) or a {code:, prefix:}
  # Hash for a different URL/site.data prefix -- explicit rather than
  # auto-derived from the code's region subtag, since that has a real
  # collision case (en-US and en-GB can't both shorten to "en").
  def self.each_locale(configured)
    if configured.nil? || configured.empty?
      yield Locale.new(nil, nil)
      return
    end

    configured.each_with_index do |entry, index|
      code, prefix = locale_code_and_prefix(entry)
      yield index.zero? ? Locale.new(code, nil) : Locale.new(code, prefix)
    end
  end

  def self.locale_code_and_prefix(entry)
    return [entry, entry] unless entry.is_a?(Hash)

    code = entry["code"] || raise("contentful_locales: entry is missing \"code\": #{entry.inspect}")
    # `entry.fetch("prefix", code)` only falls back to `code` when the key
    # is absent entirely -- a `prefix:` key present in YAML with no value
    # (as opposed to omitted) parses as an explicit nil, which #fetch
    # would return as-is rather than falling back. Treat that the same as
    # "not set".
    prefix = entry.fetch("prefix", code)
    prefix = code if prefix.nil?

    # YAML parses bare no/yes/on/off as booleans -- catches the
    # `prefix: no` (Norwegian) trap before it silently falls back to `code`.
    if [true, false].include?(prefix)
      raise "contentful_locales: prefix for #{code} parsed as the boolean #{prefix.inspect}, not a string -- " \
            "quote it in _config.yml (e.g. prefix: \"no\")"
    end

    [code, prefix]
  end

  # `dir` is usually one string used for every locale; set it to a Hash
  # keyed by locale code when the path segment itself needs translating
  # (e.g. "produkter" vs "products"), not just prefixing.
  def self.dir_for(collection, locale)
    dir = collection["dir"]
    return dir unless dir.is_a?(Hash)

    return dir[locale.code] if dir.key?(locale.code)

    raise "contentful_collections: dir is a per-locale Hash (#{dir.inspect}) but has no entry for " \
          "#{locale.code.inspect} (content_type: #{collection["content_type"]})" \
          "#{" -- is contentful_locales configured?" if locale.code.nil?}"
  end
end
