require_relative "html_utils"

module YesterlandFeed
  class RssBuilder
    def initialize(time_provider: -> { Time.now.utc }, escaper: HtmlUtils)
      @time_provider = time_provider
      @escaper = escaper
    end

    def build(entries, source_url)
      now = @time_provider.call

      items_xml = entries.map do |entry|
        pub = entry.pub_date || now
        title = @escaper.escape_xml(entry.title)
        description = @escaper.escape_xml("#{entry.title} (#{entry.date_str})")

        <<~ITEM
          <item>
            <title>#{title}</title>
            <link>#{@escaper.escape_xml(entry.link)}</link>
            <guid isPermaLink="true">#{@escaper.escape_xml(entry.link)}</guid>
            <pubDate>#{pub.rfc2822}</pubDate>
            <description>#{description}</description>
          </item>
        ITEM
      end.join

      <<~RSS
        <?xml version="1.0" encoding="UTF-8"?>
        <rss version="2.0">
          <channel>
            <title>Yesterland</title>
            <link>#{source_url}</link>
            <description>Unofficial RSS feed generated from Yesterland “What’s New” page.</description>
            <lastBuildDate>#{now.rfc2822}</lastBuildDate>
            #{items_xml}
          </channel>
        </rss>
      RSS
    end
  end
end
