require 'socket'
require 'thread'
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
      @feed_mutex.synchronize { @latest_feed = rss }
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
      @logger.debug { "[http] Request: #{method} #{path}" }

      consume_headers(client)

      if method == 'GET' && serveable_path?(path)
        body = safe_feed_body
        respond_ok(client, body)
        @logger.debug { "[http] 200 #{path} bytes=#{body&.bytesize || 0}" }
      else
        respond_not_found(client)
        @logger.debug { "[http] 404 #{path}" }
      end
    rescue => e
      @logger.warn { "[http] Handler error: #{e.class}: #{e.message}" }
    ensure
      client.close rescue nil
    end

    def consume_headers(client)
      while (line = client.gets)
        break if line == "\r\n"
      end
    end

    def serveable_path?(path)
      ['/', '/feed', '/rss'].include?(path)
    end

    def safe_feed_body
      @feed_mutex.synchronize { @latest_feed } || initializing_feed
    end

    def initializing_feed
      <<~EMPTY
        <?xml version="1.0" encoding="UTF-8"?>
        <rss version="2.0">
          <channel>
            <title>Yesterland What’s New (Unofficial)</title>
            <link>#{DEFAULT_SOURCE_URL}</link>
            <description>Feed is initializing, try again shortly.</description>
          </channel>
        </rss>
      EMPTY
    end

    def respond_ok(client, body)
      client.print "HTTP/1.1 200 OK\r\n"
      client.print "Content-Type: application/rss+xml; charset=utf-8\r\n"
      client.print "Content-Length: #{body.bytesize}\r\n"
      client.print "Connection: close\r\n"
      client.print "\r\n"
      client.print body
    end

    def respond_not_found(client)
      body = "Not found"
      client.print "HTTP/1.1 404 Not Found\r\n"
      client.print "Content-Type: text/plain; charset=utf-8\r\n"
      client.print "Content-Length: #{body.bytesize}\r\n"
      client.print "Connection: close\r\n"
      client.print "\r\n"
      client.print body
    end
  end
end
