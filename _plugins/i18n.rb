require_relative "contentful_locales"

module ContentfulJekyll
  # UI text lookup: _data/i18n/<locale code>.yml, a nested dictionary
  # read by dotted key ("menu.open"). Shared by the `t` Liquid filter
  # (contentful_filters.rb) and contentful_listing_pages.rb, so templates
  # and generated pages read copy from the same place.
  module I18n
    # `locale_code` nil means the primary locale: the first
    # contentful_locales entry, else site.lang.
    def self.translate(site, locale_code, key, vars = {})
      code = locale_code || primary_code(site)
      text = lookup(site, code, key)
      raise "i18n: missing key #{key.inspect} in _data/i18n/#{code}.yml" if text.nil?

      # "%{name}" placeholders, filled from `vars` (String or Symbol keys).
      text.gsub(/%\{(\w+)\}/) do
        name = Regexp.last_match(1)
        vars.fetch(name) { vars.fetch(name.to_sym) { raise "i18n: #{key.inspect} needs a #{name.inspect} value" } }.to_s
      end
    end

    # The raw String at `key`, or nil if there's none (for optional keys).
    def self.lookup(site, locale_code, key)
      code = locale_code || primary_code(site)
      dictionary = site.data.dig("i18n", code) || raise("i18n: no _data/i18n/#{code}.yml for locale #{code.inspect}")
      text = dictionary.dig(*key.split("."))
      text.is_a?(String) ? text : nil
    end

    def self.primary_code(site)
      first = Array(site.config["contentful_locales"]).first
      first ? ContentfulJekyll.locale_code_and_prefix(first).first : site.config["lang"]
    end
  end
end
