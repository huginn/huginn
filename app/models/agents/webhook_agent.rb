module Agents
  class WebhookAgent < Agent
    cannot_be_scheduled!
    cannot_receive_events!

    description  do
        <<-MD
        Use this Agent to create events by receiving webhooks from any source.

        In order to create events with this agent, make a POST request to:
        ```
           https://#{ENV['DOMAIN']}/users/#{user.id}/web_requests/#{id || '<id>'}/:secret
        ``` where `:secret` is specified in your options.

        Options:

          * `secret` - A token that the host will provide for authentication.
          * `expected_receive_period_in_days` - How often you expect to receive
            events this way. Used to determine if the agent is working.
          * `payload_path` - JSONPath of the attribute in the POST body to be
            used as the Event payload.  If `payload_path` points to an array,
            Events will be created for each element.
          * `filedownload_action` - Need to set true when webhook agent is used for file download. Default value is false.
          * `form_name` - It's sub option of filedownload_action. received form name in http request from client side.
          * `folder_name` - It's sub option of filedownload_action. download path when action_type is file download.
      MD
    end

    event_description do
      <<-MD
        The event payload is based on the value of the `payload_path` option,
        which is set to `#{interpolated['payload_path']}`.
      MD
    end

    def default_options
      { "secret" => "supersecretstring",
        "expected_receive_period_in_days" => 1,
        "payload_path" => "some_key",
        "filedownload_action" => "false",
        "form_name" => "webhookform",
        "folder_name" =>"public"}
    end

    def file_download_action(params)
      if params[interpolated['form_name']] != nil
        uploadflag = params[interpolated['form_name']].is_a?(String)
        filename = uploadflag  ? params[interpolated['form_name']] : params[interpolated['form_name']].original_filename

        orgFilename = filename.split('.').first
        extension = filename.split('.').last

        if interpolated['folder_name'].present?
          dir = Rails.root.join(interpolated['folder_name'])
          Dir.mkdir(dir) unless File.exists?(dir)
          tmp_file = "#{Rails.root}/#{interpolated['folder_name']}/#{filename}"
        else
          tmp_file = "#{Rails.root}/public/#{filename}"
        end

        fileid = 0
        while File.exists?(tmp_file) do
          if interpolated['folder_name'].present?
            tmp_file = "#{Rails.root}/#{interpolated['folder_name']}/#{orgFilename}#{fileid}.#{extension}"
          else
            tmp_file = "#{Rails.root}/public/#{orgFilename}#{fileid}.#{extension}"
          end
          fileid += 1
        end

        File.open(tmp_file, 'wb') do |f|
          if uploadflag
            f.write  request.body.read
          else
            f.write params[interpolated['form_name']].read
          end
        end

        senddata = {
            :fileName => filename,
            :path => tmp_file
        }
      else
        senddata = {
            :fileName => "No file",
            :path => ""
        }
      end

      create_event(:payload => senddata)
    end

    def receive_web_request(params, method, format)
      secret = params.delete('secret')
      return ["Please use POST requests only", 401] unless method == "post"
      return ["Not Authorized", 401] unless secret == interpolated['secret']

      if interpolated['filedownload_action'].present? && interpolated['filedownload_action'] == "true"
        file_download_action(params)
      else
        [payload_for(params)].flatten.each do |payload|
          create_event(payload: payload)
        end
      end

      ['Event Created', 201]
    end

    def working?
      event_created_within?(interpolated['expected_receive_period_in_days']) && !recent_error_logs?
    end

    def validate_options
      unless options['secret'].present?
        errors.add(:base, "Must specify a secret for 'Authenticating' requests")
      end
    end

    def payload_for(params)
      Utils.value_at(params, interpolated['payload_path']) || {}
    end
  end
end
