require 'net/ftp'
require 'uri'
require 'time'

module Agents
  class FtpsiteAgent < Agent
    cannot_receive_events!

    default_schedule "every_12h"

    description <<-MD
      The FtpsiteAgent checks a FTP site and creates Events based on newly uploaded files in a directory.

      Specify a `url` that represents a directory of an FTP site to watch, and a list of `patterns` to match against file names.

      Login credentials can be included in `url` if authentication is required.

      Only files with a last modification time later than the `after` value, if specifed, are notified.
    MD

    event_description <<-MD
      Events look like this:

          {
            "url": "ftp://example.org/pub/releases/foo-1.2.tar.gz",
            "filename": "foo-1.2.tar.gz",
            "timestamp": "2014-04-10T22:50:00Z"
          }
    MD

    def working?
      event_created_within?(options['expected_update_period_in_days']) && !recent_error_logs?
    end

    def default_options
      {
          'expected_update_period_in_days' => "1",
          'url' => "ftp://example.org/pub/releases/",
          'patterns' => [
            'foo-*.tar.gz',
          ],
          'after' => Time.now.iso8601,
      }
    end

    def validate_options
      # Check for required fields
      begin
        url = options['url']
        String === url or raise
        uri = URI(url)
        URI::FTP === uri or raise
        errors.add(:base, "url must end with a slash") unless uri.path.end_with?('/')
      rescue
        errors.add(:base, "url must be a valid FTP URL")
      end

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
      saving_entries do |found|
        each_entry { |filename, mtime|
          found[filename, mtime]
        }
      end
    end

    def each_entry
      patterns = options['patterns']

      after =
        if str = options['after']
          Time.parse(str)
        else
          Time.at(0)
        end

      open_ftp(base_uri) do |ftp|
        log "Listing the directory"
        # Do not use a block style call because we need to call other
        # commands during iteration.
        list = ftp.list('-a')

        month2year = {}

        list.each do |line|
          mon, day, smtn, rest = line.split(' ', 9)[5..-1]

          # Remove symlink target part if any
          filename = rest[/\A(.+?)(?:\s+->\s|\z)/, 1]

          patterns.any? { |pattern|
            File.fnmatch?(pattern, filename)
          } or next

          case smtn
          when /:/
            if year = month2year[mon]
              mtime = Time.parse("#{mon} #{day} #{year} #{smtn} GMT")
            else
              log "Getting mtime of #{filename}"
              mtime = ftp.mtime(filename)
              month2year[mon] = mtime.year
            end
          else
            # Do not bother calling MDTM for old files.  Losing the
            # time part only makes a timestamp go backwards, meaning
            # that it will trigger no new event.
            mtime = Time.parse("#{mon} #{day} #{smtn} GMT")
          end

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

      path = uri.path.chomp('/')
      log "Changing directory to #{path}"
      ftp.chdir(path)

      yield ftp
    ensure
      log "Closing the connection"
      ftp.close
    end

    def base_uri
      @base_uri ||= URI(options['url'])
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
        create_event :payload => {
          'url' => (base_uri + filename).to_s,
          'filename' => filename,
          'timestamp' => found_entries[filename],
        }
      }

      memory['known_entries'] = found_entries
      save!
    end

    private

    def is_positive_integer?(value)
      Integer(value) >= 0
    rescue
      false
    end
  end
end
