require "rest-client"
require "json"

module Agents
  class PingdomAgent < Agent
    cannot_receive_events!

    description <<-MD
      The Pingdom Agent creates an event for grabbing Pingdom alerts from an account specified by the given `pingdom_credref` field.  This field is a key for the Pingdom password stored under [credentials](/user_credentials).

      An API key set in `pingdom_apikey` is also necessary.  You can generate a key under your Pingdom account by [following instructions found here](https://my.pingdom.com/account/appkeys).

      An event will be created for each check that has changed state since the previous check.  `memory['last_run']` is utilized to keep track of the last Pingdom check.
    MD

    event_description <<-MD
      Events look like this:

          {
              "name": "Build.com",
              "state": "up",
              "lastresponsetime": "796ms"
          }
    MD

    default_schedule "every_1m"

    def working?
      event_created_within?(options['expected_update_period_in_days']) && !recent_error_logs?
    end

    def pingdom_setup?
      options['pingdom_url'].present? && pingdom_credref.present? && options['pingdom_apikey'].present?
    end

    def default_options
      {
        'pingdom_url'     => 'https://api.pingdom.com/api/2.0',
        'pingdom_credref' => '-email-',
        'pingdom_apikey'  => '',
        'expected_update_period_in_days' => '14',
      }
    end

    def pingdom_credref
      (options['pingdom_credref'].presence && (options['pingdom_credref'] != '-email-')) ? options['pingdom_credref'] : nil
    end

    def pingdom_credentials
        if pingdom_credref.present?
            {
             'pingdom_user' => options['pingdom_credref'],
             'pingdom_pass' => credential(options['pingdom_credref'])
            }
        end
    end

    def pingdom_url(path)
      "#{options["pingdom_url"]}/#{path}"
    end

    def validate_options
      errors.add(:base, "Pingdom URL and credential reference are required") unless pingdom_setup?
      errors.add(:base, "You need to specify the expected update period") unless options['expected_update_period_in_days'].present?
    end

    def get(url, options)
        response = RestClient::Request.new(
            :method   => :get,
            :url      => url,
            :user     => pingdom_credentials['pingdom_user'],
            :password => pingdom_credentials['pingdom_pass'],
            :headers  => options).execute

        if response.code == 400
          raise RuntimeError.new("Pingdom error: #{response['errorMessages']}") 
        elsif response.code == 403
          raise RuntimeError.new("Authentication failed: Forbidden (403)")
        elsif response.code != 200
          raise RuntimeError.new("Request failed: #{response}")
        end

        response.body
    end

    def get_checks()
        checks = {}
        if pingdom_setup?
            response = JSON.parse(
                         get(pingdom_url('checks'), {"App-Key" => options['pingdom_apikey'], :content_type => :json}),
                         :symbolize_names => true)
            if response[:checks]
                response[:checks].zip(response[:checks]) { |a,b|
                    checks[a[:name].to_sym] = {
                        :state => (b[:status] == 'up') ? 'up' : 'down',
                        :lastresponsetime => (b[:status] == 'up') ? b[:lastresponsetime] : "DOWN"
                    }
                }
            else
                checks["pingdom"] = {:state => "down", :lastresponsetime => "-"}
            end
        end
        return checks
    end

    def check
        if pingdom_setup?
            if memory.has_key?("last_run")
                last_run = JSON.parse(memory["last_run"])
            else
                last_run = {}
            end
            checks = get_checks()
            # Only create event if the state has changed.
            checks.each do |check, chkinfo|
                checkkey = check.to_s
                if last_run.has_key?(checkkey)
                    if last_run[checkkey]["state"] != chkinfo[:state]
                        log "#{check} transitioning from #{last_run[checkkey]["state"]} to #{chkinfo[:state]}"
                        create_event :payload => chkinfo.merge(:name => check)
                    end
                else
                    log "#{check} initializing to #{chkinfo[:state]}"
                    create_event :payload => chkinfo.merge(:name => check)
                end
            end
            memory["last_run"] = JSON.generate(checks)
        end
    end
  end
end
