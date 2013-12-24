class JSONWithIndifferentAccess
  def self.load(json)
    ActiveSupport::HashWithIndifferentAccess.new(JSON.load(json || '{}'))
  end

  def self.dump(hash)
    JSON.dump(hash)
  end
end