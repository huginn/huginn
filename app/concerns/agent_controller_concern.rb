module AgentControllerConcern
  extend ActiveSupport::Concern

  included do
    validate :validate_control_action
  end

  def default_options
    {
      'action' => 'run',
    }
  end

  def control_action
    options['action'].presence || 'run'
  end

  def validate_control_action
    case control_action
    when 'run'
      control_targets.each { |target|
        if target.cannot_be_scheduled?
          errors.add(:base, "#{target.name} cannot be scheduled")
        end
      }
    when 'enable', 'disable'
    else
      errors.add(:base, 'invalid action')
    end
  end

  def control!
    control_targets.active.each { |target|
      begin
        case control_action
        when 'run'
          log "Agent run queued for '#{target.name}'"
          Agent.async_check(target.id)
        when 'enable'
          log "Enabling the Agent '#{target.name}'"
          target.update!(disable: false) if target.disabled?
        when 'disable'
          log "Disabling the Agent '#{target.name}'"
          target.update!(disable: true) unless target.disabled?
        end
      rescue => e
        error "Failed to #{control_action} '#{target.name}': #{e.message}"
      end
    }
  end
end
