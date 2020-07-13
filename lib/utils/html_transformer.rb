module Utils
  module HtmlTransformer
    SINGLE = 1
    MULTIPLE = 2
    COMMA_SEPARATED = 3
    SRCSET = 4

    URI_ATTRIBUTES = {
      'a' => { 'href' => SINGLE },
      'applet' => { 'archive' => COMMA_SEPARATED, 'codebase' => SINGLE },
      'area' => { 'href' => SINGLE },
      'audio' => { 'src' => SINGLE },
      'base' => { 'href' => SINGLE },
      'blockquote' => { 'cite' => SINGLE },
      'body' => { 'background' => SINGLE },
      'button' => { 'formaction' => SINGLE },
      'command' => { 'icon' => SINGLE },
      'del' => { 'cite' => SINGLE },
      'embed' => { 'src' => SINGLE },
      'form' => { 'action' => SINGLE },
      'frame' => { 'longdesc' => SINGLE, 'src' => SINGLE },
      'head' => { 'profile' => SINGLE },
      'html' => { 'manifest' => SINGLE },
      'iframe' => { 'longdesc' => SINGLE, 'src' => SINGLE },
      'img' => { 'longdesc' => SINGLE, 'src' => SINGLE, 'srcset' => SRCSET, 'usemap' => SINGLE },
      'input' => { 'formaction' => SINGLE, 'src' => SINGLE, 'usemap' => SINGLE },
      'ins' => { 'cite' => SINGLE },
      'link' => { 'href' => SINGLE },
      'object' => { 'archive' => MULTIPLE, 'classid' => SINGLE, 'codebase' => SINGLE, 'data' => SINGLE, 'usemap' => SINGLE },
      'q' => { 'cite' => SINGLE },
      'script' => { 'src' => SINGLE },
      'source' => { 'src' => SINGLE, 'srcset' => SRCSET },
      'video' => { 'poster' => SINGLE, 'src' => SINGLE },
    }

    URI_ELEMENTS_XPATH = '//*[%s]' % URI_ATTRIBUTES.keys.map { |name| "name()='#{name}'" }.join(' or ')

    module_function

    def transform(html, &block)
      block or raise ArgumentError, 'block must be given'

      case html
      when /\A\s*(?:<\?xml[\s?]|<!DOCTYPE\s)/i
        doc = Nokogiri.parse(html)
        yield doc
        doc.to_s
      when /\A\s*<(html|head|body)[\s>]/i
        # Libxml2 automatically adds DOCTYPE and <html>, so we need to
        # skip them.
        element_name = $1
        doc = Nokogiri::HTML::Document.parse(html)
        yield doc
        doc.at_xpath("//#{element_name}").xpath('self::node() | following-sibling::node()').to_s
      else
        doc = Nokogiri::HTML::Document.parse("<html><body>#{html}")
        yield doc
        doc.xpath("/html/body/node()").to_s
      end
    end

    def replace_uris(html, &block)
      block or raise ArgumentError, 'block must be given'

      transform(html) { |doc|
        doc.xpath(URI_ELEMENTS_XPATH).each { |element|
          uri_attrs = URI_ATTRIBUTES[element.name] or next
          uri_attrs.each { |name, format|
            attr = element.attribute(name) or next
            case format
            when SINGLE
              attr.value = block.call(attr.value.strip)
            when MULTIPLE
              attr.value = attr.value.gsub(/(\S+)/) { block.call($1) }
            when COMMA_SEPARATED, SRCSET
              attr.value = attr.value.gsub(/((?:\A|,)\s*)(\S+)/) { $1 + block.call($2) }
            end
          }
        }
      }
    end
  end
end
