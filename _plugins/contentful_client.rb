begin
  require "dotenv/load"
rescue LoadError
  nil
end

require "contentful"

module ContentfulClient
  def self.preview?
    ENV["CONTENTFUL_PREVIEW"] == "true"
  end

  # Which env var holds the access token for the current mode.
  def self.token_var
    preview? ? "CONTENTFUL_PREVIEW_ACCESS_TOKEN" : "CONTENTFUL_ACCESS_TOKEN"
  end

  # nil if credentials are missing -- an empty value (e.g. a blank
  # `CONTENTFUL_SPACE_ID=` line in .env) counts as missing too.
  def self.build
    return nil unless missing_vars.empty?

    Contentful::Client.new(
      space: env("CONTENTFUL_SPACE_ID"),
      access_token: env(token_var),
      environment: env("CONTENTFUL_ENVIRONMENT"),
      api_url: preview? ? "preview.contentful.com" : "cdn.contentful.com"
    )
  end

  # The required env vars that are unset or empty. The environment has no
  # default, so a lost secret can't silently build from `master`.
  def self.missing_vars
    ["CONTENTFUL_SPACE_ID", token_var, "CONTENTFUL_ENVIRONMENT"].select { |name| env(name).nil? }
  end

  def self.env(name)
    value = ENV[name].to_s.strip
    value.empty? ? nil : value
  end
end
