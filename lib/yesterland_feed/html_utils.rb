require "cgi"
require "time"

module YesterlandFeed
  module HtmlUtils
    EXTRA_ENTITY_MAP = {
      "&rsquo;" => "’",
      "&lsquo;" => "‘",
      "&rdquo;" => "”",
      "&ldquo;" => "“",
      "&hellip;" => "…",
      "&mdash;" => "—",
      "&ndash;" => "–",
      "&nbsp;" => " "
    }.freeze

    EXTRA_ENTITY_REGEX = Regexp.union(EXTRA_ENTITY_MAP.keys)

    module_function

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
        .gsub("&", "&amp;")
        .gsub("<", "&lt;")
        .gsub(">", "&gt;")
        .gsub('"', "&quot;")
        .gsub("'", "&apos;")
    end
  end
end
