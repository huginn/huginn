module Agents
  class WunderlistAgent < Agent
    include FormConfigurable
    include Oauthable
    valid_oauth_providers :wunderlist

    cannot_be_scheduled!
    no_bulk_receive!

    gem_dependency_check { Devise.omniauth_providers.include?(:wunderlist) }

    description <<-MD
      The WunderlistAgent creates new Wunderlist tasks based on the incoming event.

      #{'## Include the `omniauth-wunderlist` gem in your `Gemfile` and set `WUNDERLIST_OAUTH_KEY` and `WUNDERLIST_OAUTH_SECRET` in your environment to use this Agent' if dependencies_missing?}

      To be able to use this Agent you need to authenticate with Wunderlist in the [Services](/services) section first.
    MD

    def default_options
      {
        'list_id' => '',
        'title' => '{{title}}'
      }
    end

    form_configurable :list_id, roles: :completable
    form_configurable :title

    def complete_list_id
      response = request_guard do
        HTTParty.get lists_url, request_options
      end
      response.map { |p| {text: "#{p['title']} (#{p['id']})", id: p['id']}}
    end

    def validate_options
      errors.add(:base, "you need to specify the list you want to add tasks to") unless options['list_id'].present?
      errors.add(:base, "you need to specify the title of the task to create") unless options['title'].present?
    end

    def working?
      !recent_error_logs?
    end

    def receive(incoming_events)
      incoming_events.each do |event|
        mo = interpolated(event)
        title = mo[:title][0..244]
        log("Creating new task '#{title}' on list #{mo[:list_id]}", inbound_event: event)
        request_guard do
          HTTParty.post tasks_url, request_options.merge(body: {title: title, list_id: mo[:list_id].to_i}.to_json)
        end
      end
    end

    private

    def request_guard(&blk)
      response = yield
      error("Error during http request: #{response.body}") if response.code > 400
      response
    end

    def lists_url
      "https://a.wunderlist.com/api/v1/lists"
    end

    def tasks_url
      "https://a.wunderlist.com/api/v1/tasks"
    end

    def request_options
      {:headers => {'Content-Type' => 'application/json',
                    'User-Agent' => 'Huginn (https://github.com/cantino/huginn)',
                    'X-Access-Token' => service.token,
                    'X-Client-ID' => ENV["WUNDERLIST_OAUTH_KEY"] }}
    end
  end
end
