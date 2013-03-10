require 'utils'

class Hash
  def recursively_symbolize_keys
    Utils.recursively_symbolize_keys self
  end
end
