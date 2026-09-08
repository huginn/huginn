module MarkdownHelper
  # Rails' safe-list scrubber extended to keep url() values in style
  # attributes, which Loofah rejects outright.  A URI is accepted if it
  # is a data: URI of an image or passes the check Loofah applies to
  # href and src attributes.
  class Scrubber < Rails::HTML::PermitScrubber
    DATA_IMAGE_URI = %r{\Adata:image/[a-z0-9.+-]+[;,]}i

    private

    def scrub_css_attribute(node)
      style = node.attributes['style'] or return

      style.value = Crass.parse_properties(style.value).filter_map { |property|
        scrub_css_property(property) if property[:node] == :property
      }.join
    end

    def scrub_css_property(property)
      urls = []
      value = Crass::Parser.stringify(property[:children].map { |child|
        url = url_of(child) or next child

        urls << url
        { node: :hash, raw: "#url#{urls.size}" }
      })
      value << ' !important' if property[:important]
      css = Loofah::HTML5::Scrub.scrub_css("#{property[:name]}:#{value}")
      return if css.empty? || !urls.all? { |url| allowed_url?(url) }

      css.gsub(/#url(\d+)/) { |match| urls[$1.to_i - 1]&.then { |url| "url(#{url.to_json})" } || match }
    end

    def allowed_url?(url)
      url = url.gsub(Loofah::HTML5::Scrub::CONTROL_CHARACTERS, '')
      if url.match?(/\Adata:/i)
        url.match?(DATA_IMAGE_URI)
      else
        Loofah::HTML5::Scrub.allowed_uri?(url)
      end
    end

    def url_of(child)
      case child
      in { node: :url, value: }
        value
      in { node: :function, name: 'url', value: }
        case value.reject { |token| token[:node] == :whitespace }
        in [{ node: :string, value: }]
          value
        else
          nil
        end
      else
        nil
      end
    end
  end

  ALLOWED_TAGS = (
    Rails::HTML5::SafeListSanitizer.allowed_tags +
    %w[table thead tbody tr th td]
  ).freeze
  ALLOWED_ATTRIBUTES = (
    Rails::HTML5::SafeListSanitizer.allowed_attributes +
    %w[style]
  ).freeze
  SCRUBBER = Scrubber.new(prune: true).tap { |scrubber|
    scrubber.tags = ALLOWED_TAGS
    scrubber.attributes = ALLOWED_ATTRIBUTES
  }

  def markdown(text)
    html = Kramdown::Document.new(text, auto_ids: false).to_html
    Rails::HTML5::SafeListSanitizer.new.sanitize(html, scrubber: SCRUBBER).html_safe
  end
end
