class PostAgentSetEventHeaderStyle < ActiveRecord::Migration[4.2]
  def up
    Agent.of_type("Agents::PostAgent").each do |post_agent|
      if post_agent.send(:boolify, post_agent.options['emit_events']) &&
         !post_agent.options.key?('event_headers_style')
        post_agent.options['event_headers_style'] = 'raw'
        post_agent.save!
      end
    end
  end
end
