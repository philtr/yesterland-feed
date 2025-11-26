require_relative './test_helper'

class YesterlandFeedTest < Minitest::Test
  def fixture_html
    @fixture_html ||= File.read(File.expand_path('fixtures/whatsnew.html', __dir__))
  end

  def test_decodes_curly_apostrophe
    input = "Frontierland&rsquo;s Rainbow"
    assert_equal "Frontierland’s Rainbow", YesterlandFeed::HtmlUtils.decode_html_entities(input)
  end

  def test_feed_includes_decoded_title_not_entity
    html = <<~HTML
      <dl>
        <dt>January 4, 2013</dt>
        <dd><a href="example.html">Conestoga Wagons at Frontierland&rsquo;s Rainbow Desert</a></dd>
      </dl>
    HTML

    parser = YesterlandFeed::EntryParser.new
    builder = YesterlandFeed::RssBuilder.new

    entries = parser.parse(html, YesterlandFeed::DEFAULT_SOURCE_URL)
    rss = builder.build(entries, YesterlandFeed::DEFAULT_SOURCE_URL)

    assert_includes rss, "Conestoga Wagons at Frontierland’s Rainbow Desert"
    refute_includes rss, "&amp;rsquo;"
  end

  def test_builds_rss_from_fixture_with_limit_and_valid_xml
    called_url = nil
    fetcher = Class.new do
      attr_reader :called_url

      def initialize(fixture_html)
        @fixture_html = fixture_html
      end

      def fetch(url)
        @called_url = url
        @fixture_html
      end
    end.new(fixture_html)

    service = YesterlandFeed::FeedService.new(
      source_url: 'https://example.com/whatsnew.html',
      feed_limit: 10,
      fetcher: fetcher,
      parser: YesterlandFeed::EntryParser.new,
      builder: YesterlandFeed::RssBuilder.new
    )

    rss = service.fetch_and_build

    assert_equal 'https://example.com/whatsnew.html', fetcher.called_url
    assert_equal 10, rss.scan('<item>').count
    assert_includes rss, '70 Things that Closed in 70 Years: Year-by-Year at Disneyland'
    assert_includes rss, 'Goodyear PeopleMover'
    refute_includes rss, 'Francis’ Ladybug Boogie at Flik’s Fun Fair'

    doc = REXML::Document.new(rss)
    title = REXML::XPath.first(doc, '/rss/channel/title').text
    assert_equal 'Yesterland What’s New (Unofficial)', title
  end

  def test_fetcher_reads_local_file_path
    path = File.expand_path('fixtures/whatsnew.html', __dir__)
    fetcher = YesterlandFeed::HtmlFetcher.new

    html = fetcher.fetch(path)

    assert_includes html, '<dl>'
    assert_includes html, 'What&rsquo;s New at Yesterland?'
  end

  def test_fetcher_reads_file_uri
    path = File.expand_path('fixtures/whatsnew.html', __dir__)
    fetcher = YesterlandFeed::HtmlFetcher.new

    html = fetcher.fetch("file://#{path}")

    assert_includes html, '<dt>'
  end
end
