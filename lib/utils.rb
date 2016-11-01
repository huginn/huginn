require 'jsonpath'
require 'cgi'
require 'addressable/uri'

module Utils
  def self.unindent(s)
    s = s.gsub(/\t/, '  ').chomp
    min = ((s.split("\n").find {|l| l !~ /^\s*$/ })[/^\s+/, 0] || "").length
    if min > 0
      s.gsub(/^#{" " * min}/, "")
    else
      s
    end
  end

  def self.pretty_print(struct, indent = true)
    output = JSON.pretty_generate(struct)
    if indent
      output.gsub(/\n/i, "\n    ")
    else
      output
    end
  end

  def self.normalize_uri(uri)
    begin
      URI(uri)
    rescue URI::Error
      begin
        URI(uri.to_s.gsub(/[^\-_.!~*'()a-zA-Z\d;\/?:@&=+$,\[\]]+/) { |unsafe|
              unsafe.bytes.each_with_object(String.new) { |uc, s|
                s << sprintf('%%%02X', uc)
              }
            }.force_encoding(Encoding::US_ASCII))
      rescue URI::Error => e
        begin
          auri = Addressable::URI.parse(uri.to_s)
        rescue
          # Do not leak Addressable::URI::InvalidURIError which
          # callers might not expect.
          raise e
        else
          # Addressable::URI#normalize! modifies the query and
          # fragment components beyond escaping unsafe characters, so
          # avoid using it.  Otherwise `?a[]=%2F` would be normalized
          # as `?a%5B%5D=/`, for example.
          auri.site = auri.normalized_site
          auri.path = auri.normalized_path
          URI(auri.to_s)
        end
      end
    end
  end

  def self.interpolate_jsonpaths(value, data, options = {})
    if options[:leading_dollarsign_is_jsonpath] && value[0] == '$'
      Utils.values_at(data, value).first.to_s
    else
      value.gsub(/<[^>]+>/).each { |jsonpath|
        Utils.values_at(data, jsonpath[1..-2]).first.to_s
      }
    end
  end

  def self.recursively_interpolate_jsonpaths(struct, data, options = {})
    case struct
      when Hash
        struct.inject({}) {|memo, (key, value)| memo[key] = recursively_interpolate_jsonpaths(value, data, options); memo }
      when Array
        struct.map {|elem| recursively_interpolate_jsonpaths(elem, data, options) }
      when String
        interpolate_jsonpaths(struct, data, options)
      else
        struct
    end
  end

  def self.value_at(data, path)
    values_at(data, path).first
  end

  def self.values_at(data, path)
    if path =~ /\Aescape /
      path.gsub!(/\Aescape /, '')
      escape = true
    else
      escape = false
    end

    result = JsonPath.new(path, :allow_eval => ENV['ALLOW_JSONPATH_EVAL'] == "true").on(data.is_a?(String) ? data : data.to_json)
    if escape
      result.map {|r| CGI::escape r }
    else
      result
    end
  end

  # Output JSON that is ready for inclusion into HTML.  If you simply use to_json on an object, the
  # presence of </script> in the valid JSON can break the page and allow XSS attacks.
  # Optionally, pass `:skip_safe => true` to not call html_safe on the output.
  def self.jsonify(thing, options = {})
    json = thing.to_json.gsub('</', '<\/')
    if !options[:skip_safe]
      json.html_safe
    else
      json
    end
  end

  def self.pretty_jsonify(thing)
    JSON.pretty_generate(thing).gsub('</', '<\/')
  end

  class TupleSorter
    class SortableTuple
      attr_reader :array

      # The <=> method will call orders[n] to determine if the nth element
      # should be compared in descending order.
      def initialize(array, orders = [])
        @array = array
        @orders = orders
      end

      def <=> other
        other = other.array
        @array.each_with_index do |e, i|
          o = other[i]
          case cmp = e <=> o || e.to_s <=> o.to_s
          when 0
            next
          else
            return @orders[i] ? -cmp : cmp
          end
        end
        0
      end
    end

    class << self
      def sort!(array, orders = [])
        array.sort_by! do |e|
          SortableTuple.new(e, orders)
        end
      end
    end
  end

  def self.sort_tuples!(array, orders = [])
    TupleSorter.sort!(array, orders)
  end

  def self.parse_duration(string)
    return nil if string.blank?
    case string.strip
    when /\A(\d+)\.(\w+)\z/
      $1.to_i.send($2.to_s)
    when /\A(\d+)\z/
      $1.to_i
    else
      STDERR.puts "WARNING: Invalid duration format: '#{string.strip}'"
      nil
    end
  end

  def self.if_present(string, method)
    if string.present?
      string.send(method)
    else
      nil
    end
  end

  module HTMLTransformer
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

  def self.rebase_hrefs(html, base_uri)
    base_uri = normalize_uri(base_uri)
    HTMLTransformer.replace_uris(html) { |url|
      base_uri.merge(normalize_uri(url)).to_s
    }
  end
end
