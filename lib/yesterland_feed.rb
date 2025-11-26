require "logger"
require "time"
require_relative "yesterland_feed/html_utils"
require_relative "yesterland_feed/entry_parser"
require_relative "yesterland_feed/rss_builder"
require_relative "yesterland_feed/html_fetcher"
require_relative "yesterland_feed/feed_service"
require_relative "yesterland_feed/server"

module YesterlandFeed
  DEFAULT_SOURCE_URL = "https://www.yesterland.com/whatsnew.html"
  DEFAULT_HOST = ENV.fetch("HOST", "0.0.0.0")
  DEFAULT_PORT = ENV.fetch("PORT", "4567").to_i
  DEFAULT_FETCH_INTERVAL = 24 * 60 * 60
  DEFAULT_FEED_LIMIT = ENV.fetch("FEED_LIMIT", "75").to_i
  DEFAULT_LOG_LEVEL = ENV.fetch("LOG_LEVEL", "info").to_s.downcase

  LOGGER = Logger.new($stderr)
  LOGGER.level = case DEFAULT_LOG_LEVEL
  when "debug" then Logger::DEBUG
  when "warn" then Logger::WARN
  when "error" then Logger::ERROR
  else Logger::INFO
  end
  LOGGER.progname = "YesterlandFeed"
  LOGGER.formatter = proc do |severity, datetime, progname, msg|
    "#{datetime.utc.iso8601} #{progname} #{severity}: #{msg}\n"
  end

  def self.logger
    LOGGER
  end
end
