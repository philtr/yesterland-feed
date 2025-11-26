require 'net/http'
require 'openssl'
require 'uri'

module YesterlandFeed
  class HtmlFetcher
    def initialize(http_client: Net::HTTP, verify_mode: nil, logger: YesterlandFeed.logger)
      @http_client = http_client
      @verify_mode = verify_mode
      @logger = logger
    end

    def fetch(url)
      uri = URI(url)
      return fetch_file(uri) if uri.scheme.nil? || uri.scheme == 'file'

      @http_client.start(uri.host, uri.port, use_ssl: uri.scheme == 'https') do |http|
        http.verify_mode = @verify_mode if @verify_mode && http.use_ssl?
        @logger.info { "[http] GET #{uri} (ssl=#{http.use_ssl?}, verify_mode=#{http.verify_mode.inspect})" }
        req = Net::HTTP::Get.new(uri)
        res = http.request(req)
        raise "HTTP error #{res.code}" unless res.is_a?(Net::HTTPSuccess)
        @logger.debug { "[http] Response #{res.code} #{res.message}, #{res.body.bytesize} bytes" }
        res.body
      end
    end

    private

    def fetch_file(uri)
      path = uri.scheme == 'file' ? uri.path : uri.to_s
      @logger.info { "[file] Reading #{path}" }
      File.read(File.expand_path(URI.decode_www_form_component(path)))
    end
  end
end
