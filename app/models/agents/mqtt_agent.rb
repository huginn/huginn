# encoding: utf-8 
require "mqtt"
require "json"

module Agents
  class MqttAgent < Agent
    description <<-MD
      The MQTT agent allows both publication and subscription to an MQTT topic.

      MQTT is a generic transport protocol for machine to machine communication.

      You can do things like:

       * Publish to [RabbitMQ](http://www.rabbitmq.com/mqtt.html)
       * Run [OwnTracks, a location tracking tool](http://owntracks.org/) for iOS and Android
       * Subscribe to your home automation setup like [Ninjablocks](http://forums.ninjablocks.com/index.php?p=/discussion/661/today-i-learned-about-mqtt/p1) or [TheThingSystem](http://thethingsystem.com/dev/supported-things.html)

      Simply choose a topic (think email subject line) to publish/listen to, and configure your service.

      It's easy to setup your own [broker](http://jpmens.net/2013/09/01/installing-mosquitto-on-a-raspberry-pi/) or connect to a [cloud service](www.cloudmqtt.com)

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
      event_created_within?(options['expected_update_period_in_days']) && !recent_error_logs?
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
      @client ||= MQTT::Client.new(options['uri'])

      if options['ssl']
        @client.ssl = options['ssl'].to_sym
        @client.ca_file = options['ca_file']
        @client.cert_file = options['cert_file']
        @client.key_file = options['key_file']
      end

      @client
    end

    def receive(incoming_events)
      mqtt_client.connect do |c|
        incoming_events.each do |event|
          c.publish(options['topic'], payload)
        end

        c.disconnect
      end
    end


    def check
      mqtt_client.connect do |c|

        Timeout::timeout((options['max_read_time'].presence || 15).to_i) {
          c.get(options['topic']) do |topic, message|

            # A lot of services generate JSON. Try that first
            payload = JSON.parse(message) rescue message

            create_event :payload => { 
              'topic' => topic, 
              'message' => payload, 
              'time' => Time.now.to_i 
            }
          end
        } rescue TimeoutError

        c.disconnect   
      end
    end

  end
end