# encoding: utf-8 
require "json"

module Agents
  class MqttAgent < Agent
    gem_dependency_check { defined?(MQTT) }

    description <<-MD
      The MQTT Agent allows both publication and subscription to an MQTT topic.

      #{'## Include `mqtt` in your Gemfile to use this Agent!' if dependencies_missing?}

      MQTT is a generic transport protocol for machine to machine communication.

      You can do things like:

       * Publish to [RabbitMQ](http://www.rabbitmq.com/mqtt.html)
       * Run [OwnTracks, a location tracking tool](http://owntracks.org/) for iOS and Android
       * Subscribe to your home automation setup like [Ninjablocks](http://forums.ninjablocks.com/index.php?p=/discussion/661/today-i-learned-about-mqtt/p1) or [TheThingSystem](http://thethingsystem.com/dev/supported-things.html)

      Simply choose a topic (think email subject line) to publish/listen to, and configure your service.

      It's easy to setup your own [broker](http://jpmens.net/2013/09/01/installing-mosquitto-on-a-raspberry-pi/) or connect to a [cloud service](http://www.cloudmqtt.com)

      Hints:
      Many services run mqtts (mqtt over SSL) often with a custom certificate.

      You'll want to download their cert and install it locally, specifying the ```certificate_path``` configuration.


      Example configuration:

      <pre><code>{
        'uri' => 'mqtts://user:pass@locahost:8883'
        'ssl' => :TLSv1,
        'ca_file' => './ca.pem',
        'cert_file' => './client.crt',
        'key_file' => './client.key',
        'topic' => 'huginn'
      }
      </code></pre>

      Subscribe to CloCkWeRX's TheThingSystem instance (thethingsystem.com), where
      temperature and other events are being published.

      <pre><code>{
        'uri' => 'mqtt://kcqlmkgx:sVNoccqwvXxE@m10.cloudmqtt.com:13858',
        'topic' => 'the_thing_system/demo'
      }
      </code></pre>

      Subscribe to all topics
      <pre><code>{
        'uri' => 'mqtt://kcqlmkgx:sVNoccqwvXxE@m10.cloudmqtt.com:13858',
        'topic' => '/#'
      }
      </code></pre>

      Find out more detail on [subscription wildcards](http://www.eclipse.org/paho/files/mqttdoc/Cclient/wildcard.html)
    MD

    event_description <<-MD
      Events are simply nested MQTT payloads. For example, an MQTT payload for Owntracks

      <pre><code>{
        "topic": "owntracks/kcqlmkgx/Dan",
        "message": {"_type": "location", "lat": "-34.8493644", "lon": "138.5218119", "tst": "1401771049", "acc": "50.0", "batt": "31", "desc": "Home", "event": "enter"},
        "time": 1401771051
      }</code></pre>
    MD

    def validate_options
      unless options['uri'].present? &&
             options['topic'].present?
        errors.add(:base, "topic and uri are required")
      end
    end

    def working?
      event_created_within?(interpolated['expected_update_period_in_days']) && !recent_error_logs?
    end

    def default_options
      {
        'uri' => 'mqtts://user:pass@locahost:8883',
        'ssl' => :TLSv1,
        'ca_file'  => './ca.pem',
        'cert_file' => './client.crt',
        'key_file' => './client.key',
        'topic' => 'huginn',
        'max_read_time' => '10',
        'expected_update_period_in_days' => '2'
      }
    end

    def mqtt_client
      @client ||= MQTT::Client.new(interpolated['uri'])

      if interpolated['ssl']
        @client.ssl = interpolated['ssl'].to_sym
        @client.ca_file = interpolated['ca_file']
        @client.cert_file = interpolated['cert_file']
        @client.key_file = interpolated['key_file']
      end

      @client
    end

    def receive(incoming_events)
      mqtt_client.connect do |c|
        incoming_events.each do |event|
          c.publish(interpolated(event)['topic'], event.payload['message'])
        end
      end
    end


    def check
      last_message = memory['last_message']

      mqtt_client.connect do |c|
        begin
          Timeout.timeout((interpolated['max_read_time'].presence || 15).to_i) {
            c.get_packet(interpolated['topic']) do |packet|
              topic, payload = message = [packet.topic, packet.payload]

              # Ignore a message if it is previously received
              next if (packet.retain || packet.duplicate) && message == last_message

              last_message = message

              # A lot of services generate JSON, so try that.
              begin
                payload = JSON.parse(payload)
              rescue
              end

              create_event payload: {
                'topic' => topic,
                'message' => payload,
                'time' => Time.now.to_i
              }
            end
          }
        rescue Timeout::Error
        end
      end

      # Remember the last original (non-retain, non-duplicate) message
      self.memory['last_message'] = last_message
      save!
    end

  end
end
