class JSONWithIndifferentAccess
  def self.load(json)
    ActiveSupport::HashWithIndifferentAccess.new(JSON.parse(json || '{}'))
  rescue JSON::ParserError
    Rails.logger.error "Unparsable JSON in JSONWithIndifferentAccess: #{json}"
    { 'error' => 'unparsable json detected during de-serialization' }
  end

  def self.dump(hash)
    JSON.dump(hash)
  end
end