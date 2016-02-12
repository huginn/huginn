module Agents
  class DropboxFileUrlAgent < Agent
    include DropboxConcern

    cannot_be_scheduled!
    no_bulk_receive!

    description <<-MD
      The Dropbox File Url Agent is used to work with Dropbox. It takes a file path (or multiple file paths) and emits events with [temporary links](https://www.dropbox.com/developers/core/docs#media).

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

    MD

    event_description <<-MD
      The event payload will contain the following fields:

          {
            "url": "https://dl.dropboxusercontent.com/1/view/abcdefghijk/example",
            "expires": "Fri, 16 Sep 2011 01:01:25 +0000"
          }
    MD

    def working?
      !recent_error_logs?
    end

    def receive(events)
      events.map { |e| e.payload['paths'].split(',').map(&:strip) }
        .flatten.each { |path| create_event payload: url_for(path) }
    end

    private

    def url_for(path)
      dropbox.find(path).direct_url
    end

  end

end
