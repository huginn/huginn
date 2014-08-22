module AgentControllerConcern
  extend ActiveSupport::Concern

  def default_options
    {
      'action' => 'run',
    }
  end

  def control_action
    options['action'] || 'run'
  end

  def control_targets!
    targets.active.each { |target|
      begin
        case control_action
        when 'run'
          log "Agent run queued for '#{target.name}'"
          Agent.async_check(target.id)
        end
      rescue => e
        log "Failed to #{control_action} '#{target.name}': #{e.message}"
      end
    }
  end
end
