require "active_support/log_subscriber"

module Dotenv
  # Logs instrumented events
  #
  # Usage:
  #   require "active_support/notifications"
  #   require "dotenv/log_subscriber"
  #   Dotenv.instrumenter = ActiveSupport::Notifications
  #
  class LogSubscriber < ActiveSupport::LogSubscriber
    attach_to :dotenv

    def logger
      Dotenv::Rails.logger
    end

    def load(event)
      env = event.payload[:env]

      info "Loaded #{color_filename(env.filename)}"
    end

    def update(event)
      diff = event.payload[:diff]
      changed = diff.env.keys.map { |key| color_var(key) }
      debug "Set #{changed.to_sentence}" if diff.any?
    end

    def save(event)
      info "Saved a snapshot of #{color_env_constant}"
    end

    def restore(event)
      diff = event.payload[:diff]

      removed = diff.removed.keys.map { |key| color(key, :RED) }
      restored = (diff.changed.keys + diff.added.keys).map { |key| color_var(key) }

      if removed.any? || restored.any?
        info "Restored snapshot of #{color_env_constant}"
        debug "Unset #{removed.to_sentence}" if removed.any?
        debug "Restored #{restored.to_sentence}" if restored.any?
      end
    end

    private

    def color_filename(filename)
      color(Pathname.new(filename).relative_path_from(Dotenv::Rails.root.to_s).to_s, :YELLOW)
    end

    def color_var(name)
      color(name, :CYAN)
    end

    def color_env_constant
      color("ENV", :GREEN)
    end
  end
end
