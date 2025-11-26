require_relative 'entry_parser'
require_relative 'rss_builder'
require_relative 'html_fetcher'

module YesterlandFeed
  class FeedService
    def initialize(
      source_url: DEFAULT_SOURCE_URL,
      feed_limit: DEFAULT_FEED_LIMIT,
      fetcher: HtmlFetcher.new,
      parser: EntryParser.new,
      builder: RssBuilder.new,
      logger: YesterlandFeed.logger
    )
      @source_url = source_url
      @feed_limit = feed_limit
      @fetcher = fetcher
      @parser = parser
      @builder = builder
      @logger = logger
    end

    def fetch_and_build
      @logger.info { "[feed] Fetching #{@source_url} (limit #{@feed_limit})" }
      html = @fetcher.fetch(@source_url)
      entries = @parser.parse(html, @source_url).first(@feed_limit)
      @logger.info { "[feed] Parsed #{entries.size} entries" }
      rss = @builder.build(entries, @source_url)
      @logger.info { "[feed] Built RSS #{rss.bytesize} bytes" }
      rss
    end
  end
end
