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
      :cmd => "ls"
    }
    @event.save!

    stub(Agents::ShellCommandAgent).should_run? { true }
  end

  describe "validation" do
    before do
      expect(@checker).to be_valid
    end

    it "should validate presence of necessary fields" do
      @checker.options[:command] = nil
      expect(@checker).not_to be_valid
    end

    it "should validate path" do
      @checker.options[:path] = 'notarealpath/itreallyisnt'
      expect(@checker).not_to be_valid
    end

    it "should validate path" do
      @checker.options[:path] = '/'
      expect(@checker).to be_valid
    end
  end

  describe "#working?" do
    it "generating events as scheduled" do
      stub(@checker).run_command(@valid_path, 'pwd') { ["fake pwd output", "", 0] }

      expect(@checker).not_to be_working
      @checker.check
      expect(@checker.reload).to be_working
      three_days_from_now = 3.days.from_now
      stub(Time).now { three_days_from_now }
      expect(@checker).not_to be_working
    end
  end

  describe "#check" do
    before do
      stub(@checker).run_command(@valid_path, 'pwd') { ["fake pwd output", "", 0] }
    end

    it "should create an event when checking" do
      expect { @checker.check }.to change { Event.count }.by(1)
      expect(Event.last.payload[:path]).to eq(@valid_path)
      expect(Event.last.payload[:command]).to eq('pwd')
      expect(Event.last.payload[:output]).to eq("fake pwd output")
    end

    it "does not run when should_run? is false" do
      stub(Agents::ShellCommandAgent).should_run? { false }
      expect { @checker.check }.not_to change { Event.count }
    end
  end

  describe "#receive" do
    before do
      stub(@checker).run_command(@valid_path, @event.payload[:cmd]) { ["fake ls output", "", 0] }
    end

    it "creates events" do
      @checker.options[:command] = "{{cmd}}"
      @checker.receive([@event])
      expect(Event.last.payload[:path]).to eq(@valid_path)
      expect(Event.last.payload[:command]).to eq(@event.payload[:cmd])
      expect(Event.last.payload[:output]).to eq("fake ls output")
    end

    it "does not run when should_run? is false" do
      stub(Agents::ShellCommandAgent).should_run? { false }

      expect {
        @checker.receive([@event])
      }.not_to change { Event.count }
    end
  end
end
