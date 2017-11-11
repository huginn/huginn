module Agents
  class DropboxFileUrlAgent < Agent
    include DropboxConcern

    cannot_be_scheduled!
    no_bulk_receive!
    can_dry_run!

    description <<-MD
      The _DropboxFileUrlAgent_ is used to work with Dropbox. It takes a file path (or multiple files paths) and emits events with either [temporary links](https://www.dropbox.com/developers/core/docs#media) or [permanent links](https://www.dropbox.com/developers/core/docs#shares).

      #{'## Include the `dropbox-api` and `omniauth-dropbox` gems in your `Gemfile` and set `DROPBOX_OAUTH_KEY` and `DROPBOX_OAUTH_SECRET` in your environment to use Dropbox Agents.' if dependencies_missing?}

      The incoming event payload needs to have a `paths` key, with a comma-separated list of files you want the URL for. For example:

          {
            "paths": "first/path, second/path"
          }

      __TIP__: You can use the _Event Formatting Agent_ to format events before they come in. Here's an example configuration for formatting an event coming out of a _Dropbox Watch Agent_:

          {
            "instructions": {
              "paths": "{{ added | map: 'path' | join: ',' }}"
            },
            "matchers": [],
            "mode": "clean"
          }

      An example of usage would be to watch a specific Dropbox directory (with the _DropboxWatchAgent_) and get the URLs for the added or updated files. You could then, for example, send emails with those links.

      Set `link_type` to `'temporary'` if you want temporary links, or to `'permanent'` for permanent ones.

    MD

    event_description do
      "Events will looks like this:\n\n    %s" % if options['link_type'] == 'permanent'
        Utils.pretty_print({
          url: "https://www.dropbox.com/s/abcde3/example?dl=1",
          :".tag" => "file",
          id: "id:abcde3",
          name: "hi",
          path_lower: "/huginn/hi",
          link_permissions:          {
            resolved_visibility: {:".tag"=>"public"},
            requested_visibility: {:".tag"=>"public"},
            can_revoke: true
          },
          client_modified: "2017-10-14T18:38:39Z",
          server_modified: "2017-10-14T18:38:45Z",
          rev: "31db0615354b",
          size: 0
        })
      else
        Utils.pretty_print({
          url: "https://dl.dropboxusercontent.com/apitl/1/somelongurl",
          metadata: {
            name: "hi",
            path_lower: "/huginn/hi",
            path_display: "/huginn/hi",
            id: "id:abcde3",
            client_modified: "2017-10-14T18:38:39Z",
            server_modified: "2017-10-14T18:38:45Z",
            rev: "31db0615354b",
            size: 0,
            content_hash: "e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855"
          }
        })
      end
    end

    def default_options
      {
        'link_type' => 'temporary'
      }
    end

    def working?
      !recent_error_logs?
    end

    def receive(events)
      events.flat_map { |e| e.payload['paths'].split(',').map(&:strip) }
        .each do |path|
          create_event payload: (options['link_type'] == 'permanent' ? permanent_url_for(path) : temporary_url_for(path))
        end
    end

    private

    def temporary_url_for(path)
      dropbox.find(path).direct_url.response.tap do |response|
        response['url'] = response.delete('link')
      end
    end

    def permanent_url_for(path)
      dropbox.find(path).share_url.response.tap do |response|
        response['url'].gsub!('?dl=0','?dl=1')
      end
    end

  end

end
