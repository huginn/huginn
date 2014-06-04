require 'spec_helper'
require 'mqtt'
require './spec/support/fake_mqtt_server'

require 'pry'

describe Agents::MqttAgent do
	before :each do
    # stub_request(:get, /parse/).to_return(:body => File.read(Rails.root.join("spec/data_fixtures/adioso_parse.json")), :status => 200, :headers => {"Content-Type" => "text/json"})
    # stub_request(:get, /fares/).to_return(:body => File.read(Rails.root.join("spec/data_fixtures/adioso_fare.json")),  :status => 200, :headers => {"Content-Type" => "text/json"})
    @error_log = StringIO.new
    @server = MQTT::FakeServer.new(1234, '127.0.0.1')
    @server.just_one = true
    @server.logger = Logger.new(@error_log)
    @server.logger.level = Logger::DEBUG
    @server.start

		@valid_params = {
      'uri' => "mqtt://#{@server.address}:#{@server.port}",
      'topic' => '/#',
      'max_read_time' => 1,
      'expected_update_period_in_days' => "2"
    }

		@checker = Agents::MqttAgent.new(
      :name => "somename", 
      :options => @valid_params, 
      :schedule => "midnight",
    )
		@checker.user = users(:jane)
		@checker.save!
	end

  after :each do
    @server.stop
  end

	describe "#check" do
		it "should check that initial run creates an event" do
      expect { @checker.check }.to change { Event.count }.by(2)
		end
	end

	describe "#working?" do
		it "checks if its generating events as scheduled" do
			@checker.should_not be_working
			@checker.check
			@checker.reload.should be_working
			three_days_from_now = 3.days.from_now
			stub(Time).now { three_days_from_now }
			@checker.should_not be_working
		end
	end
end
