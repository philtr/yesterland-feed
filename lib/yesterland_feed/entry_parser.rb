require_relative "html_utils"
require "uri"
require "time"

module YesterlandFeed
  Entry = Struct.new(:title, :link, :date_str, :pub_date, keyword_init: true)

  class EntryParser
    def initialize(decoder: HtmlUtils)
      @decoder = decoder
    end

    def parse(html, source_url)
      entries = []

      html.scan(%r{<dt>(.*?)</dt>\s*<dd>(.*?)</dd>}mi) do |raw_date, dd_html|
        date_str = @decoder.decode_html_entities(raw_date.to_s.strip)
          .gsub(/&nbsp;/i, " ")
          .gsub(/\s+/, " ")

        if dd_html =~ %r{<a\s+[^>]*href="([^"]+)"[^>]*>(.*?)</a>}mi
          href = Regexp.last_match(1)
          title_raw = Regexp.last_match(2).strip
          title = @decoder.decode_html_entities(title_raw)
          link = URI.join(source_url, href).to_s

          pub_time = parse_time(date_str)

          entries << Entry.new(
            title: title,
            link: link,
            date_str: date_str,
            pub_date: pub_time
          )
        end
      end

      entries
    end

    private

    def parse_time(date_str)
      Time.parse(date_str).utc
    rescue
      nil
    end
  end
end
