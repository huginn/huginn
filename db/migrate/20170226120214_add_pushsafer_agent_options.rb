class UpdatePushsaferAgentOptions < ActiveRecord::Migration
  DEFAULT_OPTIONS = {
    'm' => '{{ m | default: text }}',
    'd' => '{{ d }}',
    't' => '{{ t | default: subject }}',
    'u' => '{{ u }}',
    'ut' => '{{ ut }}',
    's' => '{{ s }}',
    'i' => '{{ i }}',
    'v' => '{{ v }}',
    'l' => '{{ l }}',
  }

  def up
    Agents::PushsaferAgent.find_each do |agent|
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
    Agents::PushsaferAgent.transaction do
      Agents::PushsaferAgent.find_each do |agent|
        options = agent.options
        DEFAULT_OPTIONS.each_pair do |key, default|
          current = options[key]

          options[key] =
            if current == default
              ''
            else
              current[/\A#{Regexp.quote(prefix_for(key))}(.*)#{Regexp.quote(suffix_for(key))}\z/, 1]
            end or raise ActiveRecord::IrreversibleMigration, "Cannot revert migration once Pushsafer agents are configured"
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
