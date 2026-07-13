require 'spec_helper'
require 'pry'

describe Agents::ChangeOverTimeAgent do
  before do
    @valid_params = {
        'name' => "my change over time agent",
        'options' => {
          'expected_receive_period_in_days' => "2",
          'value_path' => "value",
          'time_path' => "time",
        }
    }

    @agent = Agents::ChangeOverTimeAgent.new(@valid_params)
    @agent.user = users(:bob)
    @agent.save!
  end

  describe "#receive" do
    it "generates an event only after the second one is received" do
      events = build_events(:keys => ['value', 'time'],
                            :values => [["1", "2012-10-01 10:00:00"],
                                        ["2", "2012-10-01 10:01:00"],
                                        ["3", "2012-10-01 10:02:00"]])
      @agent.receive [events[0]]
      @agent.events.count.should == 0
      @agent.receive events[1..2]
      @agent.events.count.should == 2
    end

    it "should not generate an event if the time value did not change" do
      events = build_events(:keys => ['value', 'time'],
                            :values => [["1", "2012-10-01 10:00:00"],
                                        ["2", "2012-10-01 10:01:00"],
                                        ["3", "2012-10-01 10:01:00"]])
      @agent.receive events[0..1]
      @agent.events.count.should == 1
      @agent.receive [events[2]]
      @agent.events.count.should == 1
    end

    it "should compute the change over time" do
      events = build_events(:keys => ['value', 'time'],
                            :values => [["1", "2012-10-01 10:00:00"],
                                        ["5", "2012-10-01 10:00:01"],
                                        ["-2.5", "2012-10-01 10:00:02"],
                                        ["0", "2012-10-01 10:00:04"]])
      @agent.receive events
      @agent.events.count.should == 3
      @agent.events.sort_by do |event| event[:payload]['time'] end
          .map do |event| event[:payload]['value'].to_f end
          .should == [4, -7.5, 1.25]
    end

    it "should compute apply the factor" do
      @agent.options['factor'] = "6.0"
      events = build_events(:keys => ['value', 'time'],
                            :values => [["1", "2012-10-01 10:00:00"],
                                        ["5", "2012-10-01 10:00:01"]])
      @agent.receive events
      @agent.events.count.should == 1
      @agent.events[0][:payload]['value'].should == 4 * 6
    end

    it "should compute apply a factor smaller than one" do
      @agent.options['factor'] = ".01"
      events = build_events(:keys => ['value', 'time'],
                            :values => [["1", "2012-10-01 10:00:00"],
                                        ["5", "2012-10-01 10:00:01"]])
      @agent.receive events
      @agent.events.count.should == 1
      @agent.events[0][:payload]['value'].should == 4 * 0.01
    end

    it "should fallback to event creation time if time is missing" do
      @agent.options['time_path'] = ""
      events = build_events(:keys => ['value'],
                            :values => [["1"],
                                        ["5"]])
      events[0].created_at = DateTime.parse('2012-10-01 10:00:00')
      events[1].created_at = DateTime.parse('2012-10-01 10:01:00')
      @agent.receive events
      @agent.events.count.should == 1
      @agent.events[0][:payload]['value'].should == 4 / 60.0
    end

    it "should store the time value correctly" do
      events = build_events(:keys => ['value', 'time'],
                            :values => [["1", "2012-10-01 10:00:00"],
                                        ["5", "2012-10-01 10:01:00"]])
      @agent.receive events
      @agent.events.count.should == 1
      DateTime.parse(@agent.events[0][:payload]['time']).should == DateTime.parse("2012-10-01 10:00:30")
    end

    it "should store the time value correctly if set at end" do
      @agent.options['store_time_at_end'] = 'true'
      events = build_events(:keys => ['value', 'time'],
                            :values => [["1", "2012-10-01 10:00:00"],
                                        ["5", "2012-10-01 10:01:00"]])
      @agent.receive events
      @agent.events.count.should == 1
      DateTime.parse(@agent.events[0][:payload]['time']).should == DateTime.parse("2012-10-01 10:01:00")
    end

    it "should group events" do
      @agent.options['group_by_path'] = 'group'
      events = build_events(:keys => ['value', 'group', 'time'],
                            :values => [["1", 'a', "2012-10-01 10:00:00"],
                                        ["2", 'b', "2012-10-01 10:00:01"],
                                        ["3", 'c', "2012-10-01 10:00:02"],
                                        ["10", 'a', "2012-10-01 10:00:03"],
                                        ["4", 'c', "2012-10-01 10:00:04"]])
      @agent.receive events
      @agent.events.count.should == 2 # one for a and one for c
      emitted_events = @agent.events.sort_by do |event| event[:payload]['group'] end
      emitted_events[0][:payload]['group'].should == 'a'
      emitted_events[0][:payload]['value'].should == 3
      emitted_events[1][:payload]['group'].should == 'c'
      emitted_events[1][:payload]['value'].should == 0.5
    end
  end

  describe "validation" do
    before do
      @agent.should be_valid
    end

    it "should be valid with minimal options" do
      @agent.should be_valid
    end

    it "should validate presence of value path" do
      @agent.options['value_path'] = nil
      @agent.should_not be_valid
    end

    it "should validate presence of expected_receive_period_in_days" do
      @agent.options['expected_receive_period_in_days'] = ""
      @agent.should_not be_valid
    end

    it "should not require time_path" do
      @agent.options['time_path'] = ""
      @agent.should be_valid
    end

    it "should not require factor" do
      @agent.options['factor'] = ""
      @agent.should be_valid
    end

    it "should not require store_time_at_end" do
      @agent.options['store_time_at_end'] = ""
      @agent.should be_valid
    end
  end
end
