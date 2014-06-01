require 'delegate'
require 'net/imap'
require 'mail'

module Agents
  class ImapFolderAgent < Agent
    cannot_receive_events!

    default_schedule "every_30m"

    description <<-MD

      The ImapFolderAgent checks an IMAP server in specified folders
      and creates Events based on new unread mails.

      Specify an IMAP server to connect with `host`, and set `ssl` to
      true if the server supports IMAP over SSL.  Specify `port` if
      you need to connect to a port other than standard (143 or 993
      depending on the `ssl` value).

      Specify login credentials in `username` and `password`.

      List the names of folders to check in `folders`.

      To narrow mails by conditions, build a `conditions` hash with
      the following keys:

      - "subject"
      - "body"

          Specify a regular expression to match against the decoded
          subject/body of each mail.

          Use the `(?i)` directive for case-insensitive search.  For
          example, a pattern `(?i)alert` will match "alert", "Alert"
          or "ALERT".  You can also make only a part of a pattern to
          work case-insensitively: `Re: (?i:alert)` will match either
          "Re: Alert" or "Re: alert", but not "RE: alert".

          When a mail has multiple non-attachment text parts, they are
          prioritized according to the `mime_types` option (which see
          below) and the first part that matches a "body" pattern, if
          specified, will be chosen as the "body" value in a created
          event.

          Named captues will appear in the "matches" hash in a created
          event.

      - "from", "to", "cc"

          Specify a shell glob pattern string that is matched against
          mail addresses extracted from the corresponding header
          values of each mail.

          Patterns match addresses in case insensitive manner.

          Multiple pattern strings can be specified in an array, in
          which case a mail is selected if any of the patterns
          matches. (i.e. patterns are OR'd)

      - "mime_types"

          Specify an array of MIME types to tell which non-attachment
          part of a mail among its text/* parts should be used as mail
          body.  The default value is `['text/plain', 'text/enriched',
          'text/html']`.

      - "has_attachment"

          Setting this to true or false means only mails that does or does
          not have an attachment are selected.

          If this key is unspecified or set to null, it is ignored.

      Set `mark_as_read` to true to mark found mails as read.

      Each agent instance memorizes a list of unread mails that are
      found in the last run, so even if you change a set of conditions
      so that it matches mails that are missed previously, they will
      not show up as new events.  Also, in order to avoid duplicated
      notification it keeps a list of Message-Id's of 100 most recent
      mails, so if multiple mails of the same Message-Id are found,
      you will only see one event out of them.
    MD

    event_description <<-MD
      Events look like this:

          {
            "folder": "INBOX",
            "subject": "...",
            "from": "Nanashi <nanashi.gombeh@example.jp>",
            "to": ["Jane <jane.doe@example.com>"],
            "cc": [],
            "date": "2014-05-10T03:47:20+0900",
            "mime_type": "text/plain",
            "body": "Hello,\n\n...",
            "matches": {
            }
          }
    MD

    IDCACHE_SIZE = 100

    FNM_FLAGS = [:FNM_CASEFOLD, :FNM_EXTGLOB].inject(0) { |flags, sym|
      if File.const_defined?(sym)
        flags | File.const_get(sym)
      else
        flags
      end
    }

    def working?
      event_created_within?(options['expected_update_period_in_days']) && !recent_error_logs?
    end

    def default_options
      {
        'expected_update_period_in_days' => "1",
        'host' => 'imap.gmail.com',
        'ssl' => true,
        'username' => 'your.account',
        'password' => 'your.password',
        'folders' => %w[INBOX],
        'conditions' => {}
      }
    end

    def validate_options
      %w[host username password].each { |key|
        String === options[key] or
          errors.add(:base, '%s is required and must be a string' % key)
      }

      if options['port'].present?
        errors.add(:base, "port must be a positive integer") unless is_positive_integer?(options['port'])
      end

      %w[ssl mark_as_read].each { |key|
        if options[key].present?
          case options[key]
          when true, false
          else
            errors.add(:base, '%s must be a boolean value' % key)
          end
        end
      }

      case mime_types = options['mime_types']
      when nil
      when Array
        mime_types.all? { |mime_type|
          String === mime_type && mime_type.start_with?('text/')
        } or errors.add(:base, 'mime_types may only contain strings that match "text/*".')
        if mime_types.empty?
          errors.add(:base, 'mime_types should not be empty')
        end
      else
        errors.add(:base, 'mime_types must be an array')
      end

      case folders = options['folders']
      when nil
      when Array
        folders.all? { |folder|
          String === folder
        } or errors.add(:base, 'folders may only contain strings')
        if folders.empty?
          errors.add(:base, 'folders should not be empty')
        end
      else
        errors.add(:base, 'folders must be an array')
      end

      case conditions = options['conditions']
      when nil
      when Hash
        conditions.each { |key, value|
          value.present? or next
          case key
          when 'subject', 'body'
            case value
            when String
              begin
                Regexp.new(value)
              rescue
                errors.add(:base, 'conditions.%s contains an invalid regexp' % key)
              end
            else
              errors.add(:base, 'conditions.%s contains a non-string object' % key)
            end
          when 'from', 'to', 'cc'
            Array(value).each { |pattern|
              case pattern
              when String
                begin
                  glob_match?(pattern, '')
                rescue
                  errors.add(:base, 'conditions.%s contains an invalid glob pattern' % key)
                end
              else
                errors.add(:base, 'conditions.%s contains a non-string object' % key)
              end
            }
          when 'has_attachment'
            case value
            when true, false
            else
              errors.add(:base, 'conditions.%s must be a boolean value or null' % key)
            end
          end
        }
      else
        errors.add(:base, 'conditions must be a hash')
      end

      if options['expected_update_period_in_days'].present?
        errors.add(:base, "Invalid expected_update_period_in_days format") unless is_positive_integer?(options['expected_update_period_in_days'])
      end
    end

    def check
      # 'seen' keeps a hash of { uidvalidity => uids, ... } which
      # lists unread mails in watched folders.
      seen = memory['seen'] || {}
      new_seen = Hash.new { |hash, key|
        hash[key] = []
      }

      # 'notified' keeps an array of message-ids of {IDCACHE_SIZE}
      # most recent notified mails.
      notified = memory['notified'] || []

      each_unread_mail { |mail|
        new_seen[mail.uidvalidity] << mail.uid

        next if (uids = seen[mail.uidvalidity]) && uids.include?(mail.uid)

        body_parts = mail.body_parts(mime_types)
        matched_part = nil
        matches = {}

        options['conditions'].all? { |key, value|
          case key
          when 'subject'
            value.present? or next true
            re = Regexp.new(value)
            if m = re.match(mail.subject)
              m.names.each { |name|
                matches[name] = m[name]
              }
              true
            else
              false
            end
          when 'body'
            value.present? or next true
            re = Regexp.new(value)
            matched_part = body_parts.find { |part|
               if m = re.match(part.decoded)
                 m.names.each { |name|
                   matches[name] = m[name]
                 }
                 true
               else
                 false
               end
            }
          when 'from', 'to', 'cc'
            value.present? or next true
            mail.header[key].addresses.any? { |address|
              Array(value).any? { |pattern|
                glob_match?(pattern, address)
              }
            }
          when 'has_attachment'
            value == mail.has_attachment?
          else
            log 'Unknown condition key ignored: %s' % key
            true
          end
        } or next

        unless notified.include?(mail.message_id)
          matched_part ||= body_parts.first

          if matched_part
            mime_type = matched_part.mime_type
            body = matched_part.decoded
          else
            mime_type = 'text/plain'
            body = ''
          end

          create_event :payload => {
            'folder' => mail.folder,
            'subject' => mail.subject,
            'from' => mail.from_addrs.first,
            'to' => mail.to_addrs,
            'cc' => mail.cc_addrs,
            'date' => (mail.date.iso8601 rescue nil),
            'mime_type' => mime_type,
            'body' => body,
            'matches' => matches,
            'has_attachment' => mail.has_attachment?,
          }

          notified << mail.message_id if mail.message_id
        end

        if options['mark_as_read']
          log 'Marking as read'
          mail.mark_as_read
        end
      }

      notified.slice!(0...-IDCACHE_SIZE) if notified.size > IDCACHE_SIZE

      memory['seen'] = new_seen
      memory['notified'] = notified
      save!
    end

    def each_unread_mail
      host, port, ssl, username = options.values_at(:host, :port, :ssl, :username)

      log "Connecting to #{host}#{':%d' % port if port}#{' via SSL' if ssl}"
      Client.open(host, Integer(port), ssl) { |imap|
        log "Logging in as #{username}"
        imap.login(username, options[:password])

        options['folders'].each { |folder|
          log "Selecting the folder: %s" % folder

          imap.select(folder)

          unseen = imap.search('UNSEEN')

          if unseen.empty?
            log "No unread mails"
            next
          end

          imap.fetch_mails(unseen).each { |mail|
            yield mail
          }
        }
      }
    ensure
      log 'Connection closed'
    end

    def mime_types
      options['mime_types'] || %w[text/plain text/enriched text/html]
    end

    private

    def is_positive_integer?(value)
      Integer(value) >= 0
    rescue
      false
    end

    def glob_match?(pattern, value)
      File.fnmatch?(pattern, value, FNM_FLAGS)
    end

    class Client < ::Net::IMAP
      class << self
        def open(host, port, ssl)
          imap = new(host, port, ssl)
          yield imap
        ensure
          imap.disconnect unless imap.nil?
        end
      end

      def select(folder)
        ret = super(@folder = folder)
        @uidvalidity = responses['UIDVALIDITY'].last
        ret
      end

      def fetch_mails(set)
        fetch(set, %w[UID RFC822.HEADER]).map { |data|
          Message.new(self, data, folder: @folder, uidvalidity: @uidvalidity)
        }
      end
    end

    class Message < SimpleDelegator
      DEFAULT_BODY_MIME_TYPES = %w[text/plain text/enriched text/html]

      attr_reader :uid, :folder, :uidvalidity

      def initialize(client, fetch_data, props = {})
        @client = client
        props.each { |key, value|
          instance_variable_set(:"@#{key}", value)
        }
        attr = fetch_data.attr
        @uid = attr['UID']
        super(Mail.read_from_string(attr['RFC822.HEADER']))
      end

      def has_attachment?
        @has_attachment ||=
          begin
            data = @client.uid_fetch(@uid, 'BODYSTRUCTURE').first
            struct_has_attachment?(data.attr['BODYSTRUCTURE'])
          end
      end

      def fetch
        @parsed ||=
          begin
            data = @client.uid_fetch(@uid, 'BODY.PEEK[]').first
            Mail.read_from_string(data.attr['BODY[]'])
          end
      end

      def body_parts(mime_types = DEFAULT_BODY_MIME_TYPES)
        mail = fetch
        if mail.multipart?
          mail.body.set_sort_order(mime_types)
          mail.body.sort_parts!
          mail.all_parts
        else
          [mail]
        end.reject { |part|
          part.multipart? || part.attachment? || !part.text? ||
            !mime_types.include?(part.mime_type)
        }
      end

      def mark_as_read
        @client.uid_store(@uid, '+FLAGS', [:Seen])
      end

      private

      def struct_has_attachment?(struct)
        struct.multipart? && (
          struct.subtype == 'MIXED' ||
          struct.parts.any? { |part|
            struct_has_attachment?(part)
          }
        )
      end
    end
  end
end
