require 'net/imap'
require 'date'
require 'cgi'

module Agents
  class ImapAgent < Agent
    cannot_receive_events!

    description <<-MD
      The IMAP Agent creates an event for grabbing e-mail matching a combination of `subject`, `from`, or `to` in the given `mailbox`.

      Messages are returned between the current time and `memory["last_run"]` time.  If this is the first run, or `memory["last_run"]` is unset, `memory["last_run"]` will be 1 day back.

      The `subject`, `from`, and `to` parameters can be matched on exact strings or strings within the messages corresponding fields.

      A credential must be setup in huginn and referenced by name in the `imap_credref` field if authentication is required.

      For GMail `no_ssl` must be false and `port` must be 993 for IMAPS.  You must also make sure your GMail account is configured to allow IMAP.
    MD

    event_description <<-MD
      Events look like this:

          {
            "status": {
                "code": "SUCCESS",
                "message": ""
            },
            "messages": [{
                "uid": "3745",
                "from": "svc@somedomain.com",
                "to": "it@somedomain.com",
                "date": "Fri, 25 Dec 2015 14:55:14 -0700",
                "subject": "The subject of the message",
                "body": "...full text of matched message...",
                "time_diff": 86401,
                "mailbox": "Inbox"
            },
            ...
            ]
          }
    MD

    default_schedule "every_5m"

    def working?
      event_created_within?(2) && !recent_error_logs?
    end

    def match_setup?
        (
         (options['subject'].present? && options['subject'] != "") ||
         (options['from'].present? && options['from'] != "") ||
         (options['to'].present? && options['to'] != "")
        )
    end

    def imap_setup?
      options['imap_server'].present? && options['imap_server'] != "imap-server" &&
      options['imap_credref'].present? && options['imap_credref'] != "imap-credref"
    end

    def default_options
      {
        'subject'      => '',
        'from'         => '',
        'to'           => '',
        'imap_server'  => 'imap-server',
        'imap_port'    => '993',
        'imap_credref' => 'imap-credref',
        'mailbox'      => 'Inbox',
        'no_ssl'       => false,
      }
    end

    def imap_server
      options["imap_server"].presence
    end

    def imap_credref
      options["imap_credref"].presence
    end

    def imap_credentials
	if imap_credref.present?
            {
             'imap_user' => options['imap_credref'],
             'imap_pass' => credential(options['imap_credref'])
            }
        end
    end

    def time_diff
      (options["time_diff"].presence || "86401").to_i
    end

    def imap_port
      (options["imap_port"].presence || "993").to_i
    end

    def no_ssl 
      (options["no_ssl"].presence || false)
    end

    def subject
      options["subject"].presence
    end

    def from
      options["from"].presence
    end

    def to
      options["to"].presence
    end

    def mailbox
      (options["mailbox"].presence || "Inbox")
    end

    def validate_options
      errors.add(:base, "IMAP setup is required") unless imap_setup?
      errors.add(:base, "IMAP port is required") unless imap_port.present?
      errors.add(:base, "IMAP port must be set to valid integer in 143-65536 range") unless imap_port.between?(143, 65536)
      errors.add(:base, "Match validation is required") unless match_setup?
    end

    def imap
      if imap_setup?
        imap_result = { "messages" => [] }
        imap_opts = {:ssl => !options['no_ssl'], :port => options['imap_port']}
        imap1 = Net::IMAP.new(options['imap_server'], imap_opts)
        begin
            imap1.login(imap_credentials['imap_user'], imap_credentials['imap_pass'])
            imap1.select(options['mailbox'])

            today = Time.now
            searcharr = []
            if memory.has_key?("last_run")
	        last_run = Time.strptime(memory["last_run"], '%Y-%m-%d %H:%M:%S %z')
            else
                last_run = today - time_diff
            end
            # I will add the ability to get only UNSEEN messages and mark 
            # the returned ones as SEEN
            if (today - last_run) < time_diff # Assume same day
                searcharr = ["ON", today.strftime('%d-%b-%Y')]
            else
                searcharr = ["BEFORE", today.strftime('%d-%b-%Y'), "SINCE", last_run.strftime('%d-%b-%Y')]
            end
            # log "Searching from #{today.strftime('%d-%b-%Y')} to #{last_run.strftime('%d-%b-%Y')}"
            searcharr.concat ["SUBJECT", options['subject']] if options['subject'] != ""
            searcharr.concat ["FROM", options['from']] if options['from'] != ""
            searcharr.concat ["TO", options['to']] if options['to'] != ""
       
            # searching = searcharr.join(" ") 
            # log "Searching #{searching}"
            imap1.search(searcharr).each do |message_id|
                envelope = imap1.fetch(message_id, "ENVELOPE")[0].attr["ENVELOPE"]
                # Only put in messages that arrived since last run because BEFORE/SINCE is only a day filter
                # timestamp = Time.strptime(envelope.date, '%a, %d %b %Y %H:%M:%S %z')
                timestamp = Time.parse(envelope.date)
                if timestamp >= last_run
                    # flags = imap1.fetch(message_id, "FLAGS")[0].attr["FLAGS"]
                    text = imap1.fetch(message_id, 'BODY[TEXT]')[0].attr['BODY[TEXT]']
                    from1 = envelope.from[0]
                    to1 = envelope.to[0]
                    imap_result['messages'].push({
                        "uid"        => message_id,
                        "from"       => from1.mailbox + "@" + from1.host,
                        "to"         => to1.mailbox + "@" + to1.host,
                        "date"       => envelope.date,
                        "subject"    => envelope.subject,
                        "body"       => text
                    })
                end
            end
            imap_result["status"] = {"code" => "SUCCESS", "message" => ""}
            memory["last_run"] = Time.now
        # NoResponseError and ByResponseError happen often when imap'ing
        rescue Net::IMAP::NoResponseError => e
            imap_result["status"] = {"code" => "NO", "message" => "Error No Response"}
        rescue Net::IMAP::ByeResponseError => e
            imap_result["status"] = {"code" => "BYE", "message" => "Error Good-bye Response"}
        rescue => e
            imap_result["status"] = {"code" => "BAD", "message" => "Unknown Error: " + e.message}
        end
        imap1.logout
        imap1.disconnect
        return imap_result
      end
    end

    def model()
      return imap
    end

    def check
      if imap_setup?
        create_event :payload => model().merge('time_diff' => time_diff,
                                               'mailbox'   => mailbox
                                              )
      end
    end
  end
end
