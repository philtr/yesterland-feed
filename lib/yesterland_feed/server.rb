require 'socket'
require 'thread'
require 'digest'
require_relative 'feed_service'

module YesterlandFeed
  class Server
    def initialize(feed_service, host: DEFAULT_HOST, port: DEFAULT_PORT, fetch_interval: DEFAULT_FETCH_INTERVAL, logger: YesterlandFeed.logger)
      @feed_service = feed_service
      @host = host
      @port = port
      @fetch_interval = fetch_interval
      @feed_mutex = Mutex.new
      @latest_feed = nil
      @logger = logger
    end

    def start
      @logger.info { "[server] Starting" }
      refresh_feed!
      start_background_refresh
      listen
    end

    private

    def refresh_feed!
      rss = @feed_service.fetch_and_build
      now = Time.now.utc
      etag = Digest::SHA256.hexdigest(rss)
      @feed_mutex.synchronize do
        @latest_feed = {
          body: rss,
          etag: etag,
          last_modified: now
        }
      end
      @logger.info { "[feed] Updated (#{rss.bytesize} bytes)" }
    rescue => e
      @logger.warn { "[feed] Fetch failed: #{e.class}: #{e.message}" }
    end

    def start_background_refresh
      Thread.new do
        @logger.info { "[feed] Background refresh every #{@fetch_interval}s" }
        loop do
          sleep @fetch_interval
          refresh_feed!
        end
      end
    end

    def listen
      server = TCPServer.new(@host, @port)
      @logger.info { "[http] Listening on #{@host}:#{@port}" }

      trap('INT')  { exit }
      trap('TERM') { exit }

      loop do
        socket = server.accept
        Thread.new(socket) do |client|
          handle_client(client)
        end
      end
    end

    def handle_client(client)
      request_line = client.gets
      method, path, = request_line.to_s.split(' ', 3)
      headers = read_headers(client)
      @logger.debug { "[http] Request: #{method} #{path} headers=#{headers.keys.join(',')}" }

      response = response_for(method, path, headers)
      write_response(client, response)
      @logger.info { "[http] #{response[:status]} #{path} bytes=#{response[:body]&.bytesize || 0}" }
    rescue => e
      @logger.warn { "[http] Handler error: #{e.class}: #{e.message}" }
    ensure
      client.close rescue nil
    end

    def read_headers(client)
      headers = {}
      while (line = client.gets)
        break if line == "\r\n"
        if line =~ /\A([^:]+):\s*(.*)\r?\n\z/
          headers[Regexp.last_match(1).downcase] = Regexp.last_match(2).strip
        end
      end
      headers
    end

    def response_for(method, path, headers)
      return not_found_response unless method == 'GET' && serveable_path?(path)

      feed = safe_feed
      cache_headers = build_cache_headers(feed)

      if fresh?(feed, headers)
        {
          status: 304,
          headers: cache_headers,
          body: ''
        }
      else
        {
          status: 200,
          headers: cache_headers.merge(
            "Content-Type" => "application/rss+xml; charset=utf-8",
            "Content-Length" => feed[:body].bytesize.to_s
          ),
          body: feed[:body]
        }
      end
    end

    def serveable_path?(path)
      ['/', '/feed', '/rss'].include?(path)
    end

    def safe_feed
      @feed_mutex.synchronize { @latest_feed } || initializing_feed
    end

    def initializing_feed
      {
        body: <<~EMPTY,
          <?xml version="1.0" encoding="UTF-8"?>
          <rss version="2.0">
            <channel>
              <title>Yesterland</title>
              <link>#{DEFAULT_SOURCE_URL}</link>
              <description>Feed is initializing, try again shortly.</description>
            </channel>
          </rss>
        EMPTY
        etag: nil,
        last_modified: nil
      }
    end

    def not_found_response
      body = "Not found"
      {
        status: 404,
        headers: {
          "Content-Type" => "text/plain; charset=utf-8",
          "Content-Length" => body.bytesize.to_s,
          "Connection" => "close"
        },
        body: body
      }
    end

    def fresh?(feed, headers)
      inm = headers['if-none-match']
      ims = headers['if-modified-since']

      etag_match = inm && feed[:etag] && inm.strip == feed[:etag]
      time_match = false
      if ims && feed[:last_modified]
        begin
          ims_time = Time.httpdate(ims)
          time_match = ims_time >= feed[:last_modified]
        rescue StandardError
          time_match = false
        end
      end

      etag_match || time_match
    end

    def build_cache_headers(feed)
      headers = {
        "Connection" => "close",
        "Cache-Control" => "public, max-age=#{DEFAULT_FETCH_INTERVAL}"
      }
      headers["ETag"] = feed[:etag] if feed[:etag]
      headers["Last-Modified"] = feed[:last_modified].httpdate if feed[:last_modified]
      headers
    end

    def write_response(client, response)
      status_text = case response[:status]
                    when 200 then "OK"
                    when 304 then "Not Modified"
                    when 404 then "Not Found"
                    else "OK"
                    end

      client.print "HTTP/1.1 #{response[:status]} #{status_text}\r\n"
      response[:headers].each do |k, v|
        client.print "#{k}: #{v}\r\n"
      end
      client.print "\r\n"
      client.print response[:body].to_s
    end
  end
end
