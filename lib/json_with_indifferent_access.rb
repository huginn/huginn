class JsonWithIndifferentAccess
  def self.load(json)
    hash =
      case json
      when String
        begin
          JSON.parse(json)
        rescue JSON::ParserError
          Rails.logger.error "Unparsable JSON in JsonWithIndifferentAccess: #{json}"
          { 'error' => 'unparsable json detected during de-serialization' }
        end
      else
        json
      end

    ActiveSupport::HashWithIndifferentAccess.new(hash)
  end

  def self.dump(hash)
    JSON.dump(hash)
  end
end
