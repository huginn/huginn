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
end