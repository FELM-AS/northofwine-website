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
    space = env("CONTENTFUL_SPACE_ID")
    token = env(token_var)
    return nil if space.nil? || token.nil?

    Contentful::Client.new(
      space: space,
      access_token: token,
      environment: env("CONTENTFUL_ENVIRONMENT") || "master",
      api_url: preview? ? "preview.contentful.com" : "cdn.contentful.com"
    )
  end

  def self.env(name)
    value = ENV[name].to_s.strip
    value.empty? ? nil : value
  end
end
