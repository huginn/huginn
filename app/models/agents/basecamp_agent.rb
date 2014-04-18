module Agents
  class BasecampAgent < Agent
    cannot_receive_events!

    description <<-MD
      The BasecampAgent checks a Basecamp project for new Events

      It is required that you enter your Basecamp credentials (`username` and `password`).

      You also need to provide your Basecamp `user_id` and the `project_id` of the project you want to monitor.
      If you have your Basecamp project opened in your browser you can find the user_id and project_id as follows:

      `https://basecamp.com/`
      user_id
      `/projects/`
      project_id
      `-explore-basecamp`
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
        'username' => '',
        'password' => '',
        'user_id' => '',
        'project_id' => '',
      }
    end

    def validate_options
      errors.add(:base, "you need to specify your basecamp username") unless options['username'].present?
      errors.add(:base, "you need to specify your basecamp password") unless options['password'].present?
      errors.add(:base, "you need to specify your basecamp user id") unless options['user_id'].present?
      errors.add(:base, "you need to specify the basecamp project id of which you want to receive events") unless options['project_id'].present?
    end

    def working?
      (events_count.present? && events_count > 0)
    end

    def check
      reponse = HTTParty.get request_url, request_options.merge(query_parameters)
      memory[:last_run] = Time.now.utc.iso8601
      if last_check_at != nil
        JSON.parse(reponse.body).each do |event|
          create_event :payload => event
        end
      end
      save!
    end

  private
    def request_url
      "https://basecamp.com/#{URI.encode(options[:user_id].to_s)}/api/v1/projects/#{URI.encode(options[:project_id].to_s)}/events.json"
    end

    def request_options
      {:basic_auth => {:username =>options[:username], :password=>options[:password]}, :headers => {"User-Agent" => "Huginn (https://github.com/cantino/huginn)"}}
    end

    def query_parameters
      memory[:last_run].present? ? { :query => {:since => memory[:last_run]} } : {}
    end
  end
end