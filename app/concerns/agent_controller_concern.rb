module AgentControllerConcern
  extend ActiveSupport::Concern

  included do
    validate :validate_control_action
  end

  def default_options
    {
      'action' => 'run'
    }
  end

  def control_action
    interpolated['action']
  end

  def validate_control_action
    case options['action']
    when 'run'
      control_targets.each { |target|
        if target.cannot_be_scheduled?
          errors.add(:base, "#{target.name} cannot be scheduled")
        end
      }
    when 'configure'
      if options['configure_options'].nil? || options['configure_options'].keys.length == 0
        errors.add(:base, "The 'configure_options' options hash must be supplied when using the 'configure' action.")
      end
      if options['configure_options_nested_array_update_mode'].present? && !%w(replace merge).include?(options['configure_options_nested_array_update_mode'])
        errors.add(:base, "The 'configure_options_nested_array_update_mode' must be equal to 'merge' or 'replace' when provided.")
      end
    when 'enable', 'disable'
    when nil
      errors.add(:base, "action must be specified")
    when /\{[%{]/
      # Liquid template
    else
      errors.add(:base, 'invalid action')
    end
  end

  def control!
    control_targets.each { |target|
      begin
        case control_action
        when 'run'
          case
          when target.cannot_be_scheduled?
            error "'#{target.name}' cannot run without an incoming event"
          when target.disabled?
            log "Agent run ignored for disabled Agent '#{target.name}'"
          else
            Agent.async_check(target.id)
            log "Agent run queued for '#{target.name}'"
          end
        when 'enable'
          case
          when target.disabled?
            target.update!(disabled: false)
            log "Agent '#{target.name}' is enabled"
          else
            log "Agent '#{target.name}' is already enabled"
          end
        when 'disable'
          case
          when target.disabled?
            log "Agent '#{target.name}' is alread disabled"
          else
            target.update!(disabled: true)
            log "Agent '#{target.name}' is disabled"
          end
        when 'configure'
          new_options = if interpolated['configure_options_nested_array_update_mode'] == 'replace'
                          target.options.deep_merge(interpolated['configure_options'])
                        else
                          target.options.deep_merge(interpolated['configure_options']) { |key, old, new| !(new.kind_of?(Array) && old.kind_of?(Array)) ? new : (old+new).uniq }
                        end
          target.update! options: new_options
          log "Agent '#{target.name}' is configured with #{interpolated['configure_options'].inspect}"
        when ''
          # Do nothing
        else
          error "Unsupported action '#{control_action}' ignored for '#{target.name}'"
        end
      rescue => e
        error "Failed to #{control_action} '#{target.name}': #{e.message}"
      end
    }
  end
end
