module Agents
  class MavenlinkPostAgent < Agent
    cannot_receive_events!

    default_schedule 'every_2m'

    description <<-MD
      Emits newly created Mavenlink posts as events.
    MD

    event_description <<-MD
      Events look like this:

          {
              "created_at" => "2014-04-04T00:55:44-07:00",
                      "id" => "38806565",
                 "message" => "This functionality should be supported by Flowplayer configuration",
                "story_id" => "42722025",
            "workspace_id" => "4905485"
          }
    MD

    def default_options
      { 'workspace_id' => '' }
    end

    def working?
      !!(last_error_log_at.nil? || (last_event_at && last_event_at >= last_error_log_at))
    end

    def check
      log 'Checking new posts on Mavenlink'
      last_imported_post_id = most_recent_event.try(:payload).try(:[], 'id')

      each_post do |post|
        return if post.id == last_imported_post_id

        log "Importing Post##{post.id}"
        create_event :payload => post.slice(:id, :message, :created_at, :workspace_id, :story_id)
      end
    end

    private

    # Collects posts iterating through every single page
    # @yield
    def each_post(&block)
      posts_request.each_page { |posts| posts.each(&block) }
    end

    def posts_request
      Mavenlink::Post.filter(workspace_id: options['workspace_id']).order(:id, :desc)
    end
  end
end
