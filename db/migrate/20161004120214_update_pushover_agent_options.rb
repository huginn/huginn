class UpdatePushoverAgentOptions < ActiveRecord::Migration[4.2]
  DEFAULT_OPTIONS = {
    'message' => '{{ message | default: text }}',
    'device' => '{{ device }}',
    'title' => '{{ title | default: subject }}',
    'url' => '{{ url }}',
    'url_title' => '{{ url_title }}',
    'priority' => '{{ priority }}',
    'timestamp' => '{{ timestamp }}',
    'sound' => '{{ sound }}',
    'retry' => '{{ retry }}',
    'expire' => '{{ expire }}',
  }

  def up
    Agents::PushoverAgent.find_each do |agent|
      options = agent.options
      DEFAULT_OPTIONS.each_pair do |key, default|
        current = options[key]

        options[key] =
          if current.blank?
            default
          else
            "#{prefix_for(key)}#{current}#{suffix_for(key)}"
          end
      end
      agent.save!(validate: false)
    end
  end

  def down
    Agents::PushoverAgent.transaction do
      Agents::PushoverAgent.find_each do |agent|
        options = agent.options
        DEFAULT_OPTIONS.each_pair do |key, default|
          current = options[key]

          options[key] =
            if current == default
              ''
            else
              current[/\A#{Regexp.quote(prefix_for(key))}(.*)#{Regexp.quote(suffix_for(key))}\z/, 1]
            end or raise ActiveRecord::IrreversibleMigration, "Cannot revert migration once Pushover agents are configured"
        end
        agent.save!(validate: false)
      end
    end
  end

  def prefix_for(key)
    "{% capture _default_ %}"
  end

  def suffix_for(key)
    "{% endcapture %}" << DEFAULT_OPTIONS[key].sub(/(?=\}\}\z)/, '| default: _default_ ')
  end
end
