require 'jsonpath'
require 'cgi'

module Utils
  # Unindents if the indentation is 2 or more characters.
  def self.unindent(s)
    s.gsub(/^#{s.scan(/^\s+/).select {|i| i.length > 1 }.min_by{|l|l.length}}/, "")
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