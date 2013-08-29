require 'jsonpath'
require 'cgi'

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
      output.gsub(/\n/i, "\n    ").tap { |a| p a }
    else
      output
    end
  end

  def self.recursively_symbolize_keys(object)
    case object
      when Hash
        object.inject({}) {|memo, (k, v)| memo[String === k ? k.to_sym : k] = recursively_symbolize_keys(v); memo }
      when Array
        object.map { |item| recursively_symbolize_keys item }
      else
        object
    end
  end

  def self.interpolate_jsonpaths(value, data)
    value.gsub(/<[^>]+>/).each { |jsonpath|
      Utils.values_at(data, jsonpath[1..-2]).first.to_s
    }
  end

  def self.recursively_interpolate_jsonpaths(struct, data)
    case struct
      when Hash
        struct.inject({}) {|memo, (key, value)| memo[key] = recursively_interpolate_jsonpaths(value, data); memo }
      when Array
        struct.map {|elem| recursively_interpolate_jsonpaths(elem, data) }
      when String
        interpolate_jsonpaths(struct, data)
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

    result = JsonPath.new(path, :allow_eval => false).on(data.is_a?(String) ? data : data.to_json)
    if escape
      result.map {|r| CGI::escape r }
    else
      result
    end
  end
end