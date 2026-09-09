class ToolExecutionJob < ActiveJob::Base
  queue_as :default

  # DEPRECATED: This job is no longer enqueued. Tool execution logging
  # is now done inline in the orchestrator and controller.
  #
  # The class is kept so that any previously-serialized jobs in
  # DelayedJob can still be deserialized and run without error.
  def perform(tool_name, params_json, result_json, user_id, was_error = false)
    # No-op — old jobs just complete silently.
  end
end
