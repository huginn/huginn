class AgentsExporter
  attr_accessor :options

  def initialize(options)
    self.options = options
  end

  # Filename should have no commas or special characters to support Content-Disposition on older browsers.
  def filename
    ((options[:name] || '').downcase.gsub(/[^a-z0-9_-]/, '-').gsub(/-+/, '-').gsub(/^-|-$/, '').presence || 'exported-agents') + ".json"
  end

  def as_json(opts = {})
    {
      schema_version: 1,
      name: options[:name].presence || 'No name provided',
      description: options[:description].presence || 'No description provided',
      source_url: options[:source_url],
      guid: options[:guid],
      tag_fg_color: options[:tag_fg_color],
      tag_bg_color: options[:tag_bg_color],
      icon: options[:icon],
      exported_at: Time.now.utc.iso8601,
      agents: agents.map { |agent| agent_as_json(agent) },
      links: links,
      control_links: control_links
    }
  end

  def agents
    options[:agents].sort_by{|agent| agent.guid}.to_a
  end

  def links
    agent_ids = agents.map(&:id)

    contained_links = agents.map.with_index do |agent, index|
      agent.links_as_source.where(receiver_id: agent_ids).map do |link|
        { source: index, receiver: agent_ids.index(link.receiver_id) }
      end
    end

    contained_links.flatten.compact
  end

  def control_links
    agent_ids = agents.map(&:id)

    contained_controller_links = agents.map.with_index do |agent, index|
      agent.control_links_as_controller.where(control_target_id: agent_ids).map do |control_link|
        { controller: index, control_target: agent_ids.index(control_link.control_target_id) }
      end
    end

    contained_controller_links.flatten.compact
  end

  def agent_as_json(agent)
    {
      :type => agent.type,
      :name => agent.name,
      :disabled => agent.disabled,
      :guid => agent.guid,
      :options => agent.options
    }.tap do |options|
      options[:schedule] = agent.schedule if agent.can_be_scheduled?
      options[:keep_events_for] = agent.keep_events_for if agent.can_create_events?
      options[:propagate_immediately] = agent.propagate_immediately if agent.can_receive_events?
    end
  end
end
