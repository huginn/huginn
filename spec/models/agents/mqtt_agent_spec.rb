require 'rails_helper'
require 'mqtt'
require './spec/support/fake_mqtt_server'

describe Agents::MqttAgent do

  before :each do
    @error_log = StringIO.new

    @server = MQTT::FakeServer.new(41234, '127.0.0.1')
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
    it "should create events in the initial run" do
      expect { @checker.check }.to change { Event.count }.by(2)
    end

    it "should ignore retained messages that are previously received" do
      expect { @checker.check }.to change { Event.count }.by(2)
      expect { @checker.check }.to change { Event.count }.by(1)
      expect { @checker.check }.to change { Event.count }.by(1)
      expect { @checker.check }.to change { Event.count }.by(2)
    end
  end

  describe "#working?" do
    it "checks if its generating events as scheduled" do
      expect(@checker).not_to be_working
      @checker.check
      expect(@checker.reload).to be_working
      three_days_from_now = 3.days.from_now
      stub(Time).now { three_days_from_now }
      expect(@checker).not_to be_working
    end
  end
end
