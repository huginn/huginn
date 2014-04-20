require 'spec_helper'

describe Agents::ShellCommandAgent do
  before do
    @valid_path = Dir.pwd

    @valid_params = {
        :path  => @valid_path,
        :command  => "pwd",
        :expected_update_period_in_days => "1",
      }

    @checker = Agents::ShellCommandAgent.new(:name => "somename", :options => @valid_params)
    @checker.user = users(:jane)
    @checker.save!

    @event = Event.new
    @event.agent = agents(:jane_weather_agent)
    @event.payload = {
      :command => "ls"
    }
    @event.save!

    stub(Agents::ShellCommandAgent).should_run? { true }
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

    it "should validate path" do
      @checker.options[:path] = '/'
      @checker.should be_valid
    end
  end

  describe "#working?" do
    it "generating events as scheduled" do
      stub(@checker).run_command(@valid_path, 'pwd') { ["fake pwd output", "", 0] }

      @checker.should_not be_working
      @checker.check
      @checker.reload.should be_working
      three_days_from_now = 3.days.from_now
      stub(Time).now { three_days_from_now }
      @checker.should_not be_working
    end
  end

  describe "#check" do
    before do
      stub(@checker).run_command(@valid_path, 'pwd') { ["fake pwd output", "", 0] }
    end

    it "should create an event when checking" do
      expect { @checker.check }.to change { Event.count }.by(1)
      Event.last.payload[:path].should == @valid_path
      Event.last.payload[:command].should == 'pwd'
      Event.last.payload[:output].should == "fake pwd output"
    end

    it "does not run when should_run? is false" do
      stub(Agents::ShellCommandAgent).should_run? { false }
      expect { @checker.check }.not_to change { Event.count }
    end
  end

  describe "#receive" do
    before do
      stub(@checker).run_command(@valid_path, @event.payload[:command]) { ["fake ls output", "", 0] }
    end

    it "creates events" do
      @checker.receive([@event])
      Event.last.payload[:path].should == @valid_path
      Event.last.payload[:command].should == @event.payload[:command]
      Event.last.payload[:output].should == "fake ls output"
    end

    it "does not run when should_run? is false" do
      stub(Agents::ShellCommandAgent).should_run? { false }

      expect {
        @checker.receive([@event])
      }.not_to change { Event.count }
    end
  end
end
