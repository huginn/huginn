class JSONWithIndifferentAccess
  def self.load(json)
    ActiveSupport::HashWithIndifferentAccess.new(JSON.parse(json || '{}'))
  end

  def self.dump(hash)
    JSON.dump(hash)
  end
end