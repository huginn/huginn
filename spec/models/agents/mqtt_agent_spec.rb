require 'spec_helper'
require 'mqtt'
require './spec/support/fake_mqtt_server'

describe Agents::MqttAgent do

  before :each do
    @error_log = StringIO.new

    @server = MQTT::FakeServer.new(41234, '127.0.0.1')
    @server.just_one = true
    @server.logger = Logger.new(@error_log)
    @server.logger.level = Logger::DEBUG
    @server.start

    @valid_params = {
      'uri' => "mqtt://#{@server.address}:#{@server.port}",
      'topic' => '/#',
      'max_read_time' => '1',
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
