require 'rails_helper'

describe Agents::ChangeDetectorAgent do
  def create_event(output=nil)
    event = Event.new
    event.agent = agents(:jane_weather_agent)
    event.payload = {
      :command => 'some-command',
      :output => output
    }
    event.save!

    event
  end

  before do
    @valid_params = {
        :property  => "{{output}}",
        :expected_update_period_in_days => "1",
      }

    @checker = Agents::ChangeDetectorAgent.new(:name => "somename", :options => @valid_params)
    @checker.user = users(:jane)
    @checker.save!
  end

  describe "validation" do
    before do
      expect(@checker).to be_valid
    end

    it "should validate presence of property" do
      @checker.options[:property] = nil
      expect(@checker).not_to be_valid
    end

    it "should validate presence of property" do
      @checker.options[:expected_update_period_in_days] = nil
      expect(@checker).not_to be_valid
    end
  end

  describe "#working?" do
    before :each do
      # Need to create an event otherwise event_created_within? returns nil
      event = create_event
      @checker.receive([event])
    end

    it "is when event created within :expected_update_period_in_days" do
      @checker.options[:expected_update_period_in_days] = 2
      expect(@checker).to be_working
    end

    it "isnt when event created outside :expected_update_period_in_days" do
      @checker.options[:expected_update_period_in_days] = 2

      travel 49.hours do
        expect(@checker).not_to be_working
      end
    end
  end

  describe "#receive" do
    before :each do
      @event = create_event("2014-07-01")
    end

    it "creates events when memory is empty" do
      @event.payload[:output] = "2014-07-01"
      expect {
        @checker.receive([@event])
      }.to change(Event, :count).by(1)
      expect(Event.last.payload[:command]).to eq(@event.payload[:command])
      expect(Event.last.payload[:output]).to eq(@event.payload[:output])
    end

    it "creates events when new event changed" do
      @event.payload[:output] = "2014-07-01"
      @checker.receive([@event])

      event = create_event("2014-08-01")

      expect {
        @checker.receive([event])
      }.to change(Event, :count).by(1)
    end

    it "does not create event when no change" do
      @event.payload[:output] = "2014-07-01"
      @checker.receive([@event])

      expect {
        @checker.receive([@event])
      }.to change(Event, :count).by(0)
    end
  end

  describe "#receive using last_property to track lowest value" do
    before :each do
      @event = create_event("100")
    end

    before do
      # Evaluate the output as number and detect a new lowest value
      @checker.options['property'] = '{% assign drop = last_property | minus: output %}{% if last_property == blank or drop > 0 %}{{ output | default: last_property }}{% else %}{{ last_property }}{% endif %}'
    end

    it "creates events when the value drops" do
      @checker.receive([@event])

      event = create_event("90")
      expect {
        @checker.receive([event])
      }.to change(Event, :count).by(1)
      expect(@checker.memory['last_property']).to eq "90"
    end

    it "does not create event when the value does not change" do
      @checker.receive([@event])

      event = create_event("100")
      expect {
        @checker.receive([event])
      }.not_to change(Event, :count)
      expect(@checker.memory['last_property']).to eq "100"
    end

    it "does not create event when the value rises" do
      @checker.receive([@event])

      event = create_event("110")
      expect {
        @checker.receive([event])
      }.not_to change(Event, :count)
      expect(@checker.memory['last_property']).to eq "100"
    end

    it "does not create event when the value is blank" do
      @checker.receive([@event])

      event = create_event("")
      expect {
        @checker.receive([event])
      }.not_to change(Event, :count)
      expect(@checker.memory['last_property']).to eq "100"
    end

    it "creates events when memory is empty" do
      expect {
        @checker.receive([@event])
      }.to change(Event, :count).by(1)
      expect(@checker.memory['last_property']).to eq "100"
    end
  end
end
