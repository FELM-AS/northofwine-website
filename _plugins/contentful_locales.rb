module ContentfulJekyll
  # Shared Jekyll.logger progname for every contentful_* plugin.
  LOG_TAG = "Contentful:"

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

    # page.data["locale"] for a page built in this locale pass: nil for
    # the primary locale (falls back to site.lang), else the locale code.
    def page_code
      primary? ? nil : code
    end

    # The site.data key for a locale-scoped collection fetched under
    # `base` (e.g. "manufacturers") -- `base` for the primary locale,
    # "<base>_<data_suffix>" for any other. Used by both the writer
    # (EntriesGenerator) and the reader (ListingPagesGenerator).
    def data_key_for(base)
      [base, data_suffix].compact.join("_")
    end

    # Joins `parts` into a URL path prefixed with this locale's url_prefix
    # (none for the primary locale), dropping blank/nil segments.
    def path_for(*parts)
      [url_prefix, *parts].reject { |part| part.to_s.empty? }.join("/")
    end
  end

  # Yields one Locale per contentful_locales entry, first = primary. Unset
  # or empty yields a single Locale.new(nil, nil): no `locale` query param,
  # no prefixes. An entry is a locale code (prefix == code) or a
  # {code:, prefix:} Hash for a different URL/site.data prefix.
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
    # A `prefix:` key with no value parses as nil; treat it as unset.
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

  # A collection's `dir`: one string for every locale, or a Hash keyed by
  # locale code when the path segment itself is translated. Raises if it's
  # missing (use dir: "" for the site root) or lacks the current locale.
  def self.dir_for(collection, locale)
    dir = collection["dir"]

    if dir.nil?
      raise "contentful_collections: \"dir\" is missing (content_type: #{collection["content_type"].inspect}) -- " \
            "use dir: \"\" for the site root, not an omitted/blank key"
    end

    return dir unless dir.is_a?(Hash)

    return dir[locale.code] if dir.key?(locale.code)

    raise "contentful_collections: dir is a per-locale Hash (#{dir.inspect}) but has no entry for " \
          "#{locale.code.inspect} (content_type: #{collection["content_type"]})" \
          "#{" -- is contentful_locales configured?" if locale.code.nil?}"
  end
end
