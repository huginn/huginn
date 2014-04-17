require 'spec_helper'

describe Agents::CommandAgent do

  before do
    @valid_path = Dir.pwd
    @valid_params = {
        :path  => @valid_path,
        :command  => "pwd",
        :expected_update_period_in_days => "1",
      }

    @checker = Agents::CommandAgent.new(:name => "somename", :options => @valid_params)
    @checker.user = users(:jane)
    @checker.save!

    @event = Event.new
    @event.agent = agents(:jane_weather_agent)
    @event.payload = {
      :command => "pwd"
    }
    @event.save!
  end

  describe "validation" do
    before do
      @checker.should be_valid
    end

    it "should validate presence of necessary fields" do
      @checker.options[:command] = nil
      @checker.should_not be_valid
    end

    it "should validate path" do
      @checker.options[:path] = 'notarealpath/itreallyisnt'
      @checker.should_not be_valid
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

  describe "#check" do
    it "should check that initial run creates an event" do
      expect { @checker.check }.to change { Event.count }.by(1)
    end
  end

  describe "#receive" do
    it "checks if creates events" do
      @checker.receive([@event])
      Event.last.payload[:path].should == @valid_path
    end
    it "checks if options are taken from event" do
      @event.payload[:command] = 'notarealcommand'
      @checker.receive([@event])
      Event.last.payload[:command].should == 'notarealcommand'
    end
  end

end