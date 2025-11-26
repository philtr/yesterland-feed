require 'net/http'
require 'uri'
require 'time'
require 'date'
require 'cgi'
require 'socket'
require 'thread'

$stdout.sync = true

SOURCE_URL     = 'https://www.yesterland.com/whatsnew.html'
HOST           = '0.0.0.0'
PORT           = (ENV['PORT'] || '4567').to_i
FETCH_INTERVAL = 24 * 60 * 60 # 24 hours
FEED_LIMIT     = (ENV['FEED_LIMIT'] || '75').to_i
EXTRA_ENTITY_MAP = {
  '&rsquo;'  => '’',
  '&lsquo;'  => '‘',
  '&rdquo;'  => '”',
  '&ldquo;'  => '“',
  '&hellip;' => '…',
  '&mdash;'  => '—',
  '&ndash;'  => '–',
  '&nbsp;'   => ' '
}.freeze
EXTRA_ENTITY_REGEX = Regexp.union(EXTRA_ENTITY_MAP.keys)

def decode_html_entities(str)
  s = str.to_s.dup
  5.times do
    s = s.gsub(EXTRA_ENTITY_REGEX) { |m| EXTRA_ENTITY_MAP[m] }
    decoded = CGI.unescapeHTML(s)
    break if decoded == s
    s = decoded
  end
  s
end

def escape_xml(str)
  str.to_s
     .gsub('&', '&amp;')
     .gsub('<', '&lt;')
     .gsub('>', '&gt;')
     .gsub('"', '&quot;')
     .gsub("'", '&apos;')
end

def fetch_html(url)
  uri = URI(url)
  Net::HTTP.start(uri.host, uri.port, use_ssl: uri.scheme == 'https') do |http|
    req = Net::HTTP::Get.new(uri)
    res = http.request(req)
    raise "HTTP error #{res.code}" unless res.is_a?(Net::HTTPSuccess)
    res.body
  end
end

def parse_entries(html, source_url)
  entries = []

  # very simple DT/DD extraction – tweak if the page layout changes
  html.scan(%r{<dt>(.*?)</dt>\s*<dd>(.*?)</dd>}mi) do |raw_date, dd_html|
    date_str = decode_html_entities(raw_date.to_s.strip)
                  .gsub(/&nbsp;/i, ' ')
                  .gsub(/\s+/, ' ')

    if dd_html =~ %r{<a\s+[^>]*href="([^"]+)"[^>]*>(.*?)</a>}mi
      href  = Regexp.last_match(1)
      title_raw = Regexp.last_match(2).strip
      title = decode_html_entities(title_raw)
      link  = URI.join(source_url, href).to_s

      pub_time = begin
        Time.parse(date_str).utc
      rescue StandardError
        nil
      end

      entries << {
        title:    title,
        link:     link,
        date_str: date_str,
        pub_date: pub_time
      }
    end
  end

  entries
end

def build_rss(entries, source_url)
  now = Time.now.utc

  items_xml = entries.map do |e|
    pub = e[:pub_date] || now
    title       = escape_xml(e[:title])
    description = escape_xml("#{e[:title]} (#{e[:date_str]})")

    <<~ITEM
      <item>
        <title>#{title}</title>
        <link>#{escape_xml(e[:link])}</link>
        <guid isPermaLink="true">#{escape_xml(e[:link])}</guid>
        <pubDate>#{pub.rfc2822}</pubDate>
        <description>#{description}</description>
      </item>
    ITEM
  end.join

  <<~RSS
    <?xml version="1.0" encoding="UTF-8"?>
    <rss version="2.0">
      <channel>
        <title>Yesterland What’s New (Unofficial)</title>
        <link>#{source_url}</link>
        <description>Unofficial RSS feed generated from Yesterland “What’s New” page.</description>
        <lastBuildDate>#{now.rfc2822}</lastBuildDate>
        #{items_xml}
      </channel>
    </rss>
  RSS
end

def fetch_and_build_feed(source_url: SOURCE_URL, fetcher: method(:fetch_html), feed_limit: FEED_LIMIT)
  html    = fetcher.call(source_url)
  entries = parse_entries(html, source_url).first(feed_limit)
  build_rss(entries, source_url)
end

def update_feed!(feed_mutex, latest_feed_ref)
  rss = fetch_and_build_feed
  feed_mutex.synchronize do
    latest_feed_ref[:feed] = rss
  end
  warn "[feed] Updated (#{rss.bytesize} bytes)"
rescue => e
  warn "[feed] Fetch failed: #{e.class}: #{e.message}"
end

def start_server
  feed_mutex  = Mutex.new
  latest_feed_ref = { feed: nil }

  # initial fetch (blocking)
  update_feed!(feed_mutex, latest_feed_ref)

  # periodic background fetch
  Thread.new do
    loop do
      sleep FETCH_INTERVAL
      update_feed!(feed_mutex, latest_feed_ref)
    end
  end

  server = TCPServer.new(HOST, PORT)
  warn "[http] Listening on #{HOST}:#{PORT}"

  trap('INT')  { exit }
  trap('TERM') { exit }

  loop do
    socket = server.accept
    Thread.new(socket) do |client|
      begin
        request_line = client.gets
        method, path, _ = request_line.to_s.split(' ', 3)

        # consume headers
        while (line = client.gets)
          break if line == "\r\n"
        end

        if method == 'GET' && (path == '/' || path == '/feed' || path == '/rss')
          body = feed_mutex.synchronize { latest_feed_ref[:feed] }

          body ||= <<~EMPTY
            <?xml version="1.0" encoding="UTF-8"?>
            <rss version="2.0">
              <channel>
                <title>Yesterland What’s New (Unofficial)</title>
                <link>#{SOURCE_URL}</link>
                <description>Feed is initializing, try again shortly.</description>
              </channel>
            </rss>
          EMPTY

          client.print "HTTP/1.1 200 OK\r\n"
          client.print "Content-Type: application/rss+xml; charset=utf-8\r\n"
          client.print "Content-Length: #{body.bytesize}\r\n"
          client.print "Connection: close\r\n"
          client.print "\r\n"
          client.print body
        else
          body = "Not found"
          client.print "HTTP/1.1 404 Not Found\r\n"
          client.print "Content-Type: text/plain; charset=utf-8\r\n"
          client.print "Content-Length: #{body.bytesize}\r\n"
          client.print "Connection: close\r\n"
          client.print "\r\n"
          client.print body
        end
      rescue => e
        warn "[http] Handler error: #{e.class}: #{e.message}"
      ensure
        client.close rescue nil
      end
    end
  end
end

start_server if __FILE__ == $PROGRAM_NAME
