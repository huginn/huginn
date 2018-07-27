module Agents
  class BasecampAgent < Agent
    include FormConfigurable
    include Oauthable
    include WebRequestConcern
    valid_oauth_providers :'37signals'

    cannot_receive_events!

    description <<-MD
      The Basecamp Agent checks a Basecamp project for new Events

      To be able to use this Agent you need to authenticate with 37signals in the [Services](/services) section first.
    MD

    event_description <<-MD
      Events are the raw JSON provided by the Basecamp API. Should look something like:

          {
            "creator": {
              "fullsize_avatar_url": "https://dge9rmgqjs8m1.cloudfront.net/global/dfsdfsdfdsf/original.gif?r=3",
              "avatar_url": "http://dge9rmgqjs8m1.cloudfront.net/global/dfsdfsdfdsf/avatar.gif?r=3",
              "name": "Dominik Sander",
              "id": 123456
            },
            "attachments": [],
            "raw_excerpt": "test test",
            "excerpt": "test test",
            "id": 6454342343,
            "created_at": "2014-04-17T10:25:31.000+02:00",
            "updated_at": "2014-04-17T10:25:31.000+02:00",
            "summary": "commented on whaat",
            "action": "commented on",
            "target": "whaat",
            "url": "https://basecamp.com/12456/api/v1/projects/76454545-explore-basecamp/messages/76454545-whaat.json",
            "html_url": "https://basecamp.com/12456/projects/76454545-explore-basecamp/messages/76454545-whaat#comment_76454545"
          }
    MD

    default_schedule "every_10m"

    def default_options
      {
        'project_id' => '',
      }
    end

    form_configurable :project_id, roles: :completable

    def complete_project_id
      service.prepare_request
      response = HTTParty.get projects_url, request_options.merge(query_parameters)
      response.map { |p| {text: "#{p['name']} (#{p['id']})", id: p['id']}}
    end

    def validate_options
      errors.add(:base, "you need to specify the basecamp project id of which you want to receive events") unless options['project_id'].present?
    end

    def working?
      (events_count.present? && events_count > 0)
    end

    def check
      service.prepare_request
      response = HTTParty.get events_url, request_options.merge(query_parameters)
      events = JSON.parse(response.body)
      if !memory[:last_event].nil?
        events.each do |event|
          create_event :payload => event
        end
      end
      memory[:last_event] = events.first['created_at'] if events.length > 0
      save!
    end

  private
    def base_url
      "https://basecamp.com/#{URI.encode(service.options[:user_id].to_s)}/api/v1/"
    end

    def events_url
      base_url + "projects/#{URI.encode(interpolated[:project_id].to_s)}/events.json"
    end

    def projects_url
      base_url + "projects.json"
    end

    def request_options
      {headers: {"User-Agent" => user_agent, "Authorization" => "Bearer \"#{service.token}\""}}
    end

    def query_parameters
      memory[:last_event].present? ? { :query => {:since => memory[:last_event]} } : {}
    end
  end
end
