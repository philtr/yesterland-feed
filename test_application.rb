require 'minitest/autorun'
require 'rexml/document'
require_relative './application'

class ApplicationTest < Minitest::Test
  def fixture_html
    @fixture_html ||= File.read(File.expand_path('test/fixtures/whatsnew.html', __dir__))
  end

  def test_decodes_curly_apostrophe
    input = "Frontierland&rsquo;s Rainbow"
    assert_equal "Frontierland’s Rainbow", decode_html_entities(input)
  end

  def test_feed_includes_decoded_title_not_entity
    html = <<~HTML
      <dl>
        <dt>January 4, 2013</dt>
        <dd><a href="example.html">Conestoga Wagons at Frontierland&rsquo;s Rainbow Desert</a></dd>
      </dl>
    HTML

    entries = parse_entries(html, SOURCE_URL)
    rss = build_rss(entries, SOURCE_URL)

    assert_includes rss, "Conestoga Wagons at Frontierland’s Rainbow Desert"
    refute_includes rss, "&amp;rsquo;"
  end

  def test_builds_rss_from_fixture_with_limit_and_valid_xml
    called_url = nil
    fetcher = ->(url) { called_url = url; fixture_html }

    rss = fetch_and_build_feed(
      source_url: 'https://example.com/whatsnew.html',
      fetcher: fetcher,
      feed_limit: 10
    )

    assert_equal 'https://example.com/whatsnew.html', called_url
    assert_equal 10, rss.scan('<item>').count
    assert_includes rss, '70 Things that Closed in 70 Years: Year-by-Year at Disneyland'
    assert_includes rss, 'Goodyear PeopleMover'
    refute_includes rss, 'Francis’ Ladybug Boogie at Flik’s Fun Fair'

    doc = REXML::Document.new(rss)
    title = REXML::XPath.first(doc, '/rss/channel/title').text
    assert_equal 'Yesterland What’s New (Unofficial)', title
  end
end
