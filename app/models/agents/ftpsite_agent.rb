require 'uri'
require 'time'

module Agents
  class FtpsiteAgent < Agent
    include FileHandling
    default_schedule "every_12h"

    gem_dependency_check { defined?(Net::FTP) && defined?(Net::FTP::List) }

    emits_file_pointer!

    description do
      <<-MD
        The Ftp Site Agent checks an FTP site and creates Events based on newly uploaded files in a directory. When receiving events it creates files on the configured FTP server.

        #{'## Include `net-ftp-list` in your Gemfile to use this Agent!' if dependencies_missing?}

        `mode` must be present and either `read` or `write`, in `read` mode the agent checks the FTP site for changed files, with `write` it writes received events to a file on the server.

        ### Universal options

        Specify a `url` that represents a directory of an FTP site to watch, and a list of `patterns` to match against file names.

        Login credentials can be included in `url` if authentication is required: `ftp://username:password@ftp.example.com/path`. Liquid formatting is supported as well: `ftp://{% credential ftp_credentials %}@ftp.example.com/`

        Optionally specify the encoding of the files you want to read/write in `force_encoding`, by default UTF-8 is used.

        ### Reading

        Only files with a last modification time later than the `after` value, if specifed, are emitted as event.

        ### Writing

        Specify the filename to use in `filename`, Liquid interpolation is possible to change the name per event.

        Use [Liquid](https://github.com/huginn/huginn/wiki/Formatting-Events-using-Liquid) templating in `data` to specify which part of the received event should be written.

        #{emitting_file_handling_agent_description}
      MD
    end

    event_description <<-MD
      Events look like this:

          {
            "url": "ftp://example.org/pub/releases/foo-1.2.tar.gz",
            "filename": "foo-1.2.tar.gz",
            "timestamp": "2014-04-10T22:50:00Z"
          }
    MD

    def working?
      if interpolated['mode'] == 'read'
        event_created_within?(interpolated['expected_update_period_in_days']) && !recent_error_logs?
      else
        received_event_without_error?
      end
    end

    def default_options
      {
        'mode' => 'read',
        'expected_update_period_in_days' => "1",
        'url' => "ftp://example.org/pub/releases/",
        'patterns' => [
          'foo-*.tar.gz',
        ],
        'after' => Time.now.iso8601,
        'force_encoding' => '',
        'filename' => '',
        'data' => '{{ data }}'
      }
    end

    def validate_options
      # Check for required fields
      begin
        if !options['url'].include?('{{')
          url = interpolated['url']
          String === url or raise
          uri = URI(url)
          URI::FTP === uri or raise
          errors.add(:base, "url must end with a slash") if uri.path.present? && !uri.path.end_with?('/')
        end
      rescue
        errors.add(:base, "url must be a valid FTP URL")
      end

      options['mode'] = 'read' if options['mode'].blank? && new_record?
      if options['mode'].blank? || !['read', 'write'].include?(options['mode'])
        errors.add(:base, "The 'mode' option is required and must be set to 'read' or 'write'")
      end

      case interpolated['mode']
      when 'read'
        patterns = options['patterns']
        case patterns
        when Array
          if patterns.empty?
            errors.add(:base, "patterns must not be empty")
          end
        when nil, ''
          errors.add(:base, "patterns must be specified")
        else
          errors.add(:base, "patterns must be an array")
        end
      when 'write'
        if options['filename'].blank?
          errors.add(:base, "filename must be specified in 'write' mode")
        end
        if options['data'].blank?
          errors.add(:base, "data must be specified in 'write' mode")
        end
      end

      # Check for optional fields
      if (timestamp = options['timestamp']).present?
        begin
          Time.parse(timestamp)
        rescue
          errors.add(:base, "timestamp cannot be parsed as time")
        end
      end

      if options['expected_update_period_in_days'].present?
        errors.add(:base, "Invalid expected_update_period_in_days format") unless is_positive_integer?(options['expected_update_period_in_days'])
      end
    end

    def check
      return if interpolated['mode'] != 'read'
      saving_entries do |found|
        each_entry { |filename, mtime|
          found[filename, mtime]
        }
      end
    end

    def receive(incoming_events)
      return if interpolated['mode'] != 'write'
      incoming_events.each do |event|
        mo = interpolated(event)
        mo['data'].encode!(interpolated['force_encoding'], invalid: :replace, undef: :replace) if interpolated['force_encoding'].present?
        open_ftp(base_uri) do |ftp|
          ftp.storbinary("STOR #{mo['filename']}", StringIO.new(mo['data']), Net::FTP::DEFAULT_BLOCKSIZE)
        end
      end
    end

    def each_entry
      patterns = interpolated['patterns']

      after =
        if str = interpolated['after']
          Time.parse(str)
        else
          Time.at(0)
        end

      open_ftp(base_uri) do |ftp|
        log "Listing the directory"
        # Do not use a block style call because we need to call other
        # commands during iteration.
        list = ftp.list('-a')

        list.each do |line|
          entry = Net::FTP::List.parse line
          filename = entry.basename
          mtime = Time.parse(entry.mtime.to_s).utc
          
          patterns.any? { |pattern|
            File.fnmatch?(pattern, filename)
          } or next

          after < mtime or next

          yield filename, mtime
        end
      end
    end

    def open_ftp(uri)
      ftp = Net::FTP.new

      log "Connecting to #{uri.host}#{':%d' % uri.port if uri.port != uri.default_port}"
      ftp.connect(uri.host, uri.port)

      user =
        if str = uri.user
          URI.decode(str)
        else
          'anonymous'
        end
      password =
        if str = uri.password
          URI.decode(str)
        else
          'anonymous@'
        end
      log "Logging in as #{user}"
      ftp.login(user, password)

      ftp.passive = true

      if (path = uri.path.chomp('/')).present?
        log "Changing directory to #{path}"
        ftp.chdir(path)
      end

      yield ftp
    ensure
      log "Closing the connection"
      ftp.close
    end

    def base_uri
      @base_uri ||= URI(interpolated['url'])
    end

    def saving_entries
      known_entries = memory['known_entries'] || {}
      found_entries = {}
      new_files = []

      yield proc { |filename, mtime|
        found_entries[filename] = misotime = mtime.utc.iso8601
        unless (prev = known_entries[filename]) && misotime <= prev
          new_files << filename
        end
      }

      new_files.sort_by { |filename|
        found_entries[filename]
      }.each { |filename|
        create_event payload: get_file_pointer(filename).merge({
          'url' => (base_uri + uri_path_escape(filename)).to_s,
          'filename' => filename,
          'timestamp' => found_entries[filename],
        })
      }

      memory['known_entries'] = found_entries
      save!
    end

    def get_io(file)
      data = StringIO.new
      open_ftp(base_uri) do |ftp|
        ftp.getbinaryfile(file, nil) do |chunk|
          data.write chunk.force_encoding(options['force_encoding'].presence || 'UTF-8')
        end
      end
      data.rewind
      data
    end

    private

    def uri_path_escape(string)
      str = string.b
      str.gsub!(/([^A-Za-z0-9\-._~!$&()*+,=@]+)/) { |m|
        '%' + m.unpack('H2' * m.bytesize).join('%').upcase
      }
      str.force_encoding(Encoding::US_ASCII)
    end
  end
end
