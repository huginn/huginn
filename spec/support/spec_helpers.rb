module SpecHelpers
  def build_events(options = {})
    options[:values].map.with_index do |tuple, index|
      event = Event.new
      event.agent = agents(:bob_weather_agent)
      event.payload = (options[:pattern] || {}).dup.merge((options[:keys].zip(tuple)).inject({}) { |memo, (key, value)| memo[key] = value; memo })
      event.created_at = (100 - index).hours.ago
      event.updated_at = (100 - index).hours.ago
      event
    end
  end
end