require 'rails_helper'

describe Agents::DeDuplicationAgent do
  def create_event(output=nil)
    event = Event.new
    event.agent = agents(:jane_weather_agent)
    event.payload = {
      :output => output
    }
    event.save!

    event
  end

  before do
    @valid_params = {
      :property  => "{{output}}",
      :lookback => 3,
      :expected_update_period_in_days => "1",
    }

    @checker = Agents::DeDuplicationAgent.new(:name => "somename", :options => @valid_params)
    @checker.user = users(:jane)
    @checker.save!
  end

  describe "validation" do
    before do
      expect(@checker).to be_valid
    end

    it "should validate presence of lookback" do
      @checker.options[:lookback] = nil
      expect(@checker).not_to be_valid
    end

    it "should validate presence of property" do
      @checker.options[:expected_update_period_in_days] = nil
      expect(@checker).not_to be_valid
    end
  end

  describe '#initialize_memory' do
    it 'sets properties to an empty array' do
      expect(@checker.memory['properties']).to eq([])
    end

    it 'does not override an existing value' do
      @checker.memory['properties'] = [1,2,3]
      @checker.save
      @checker.reload
      expect(@checker.memory['properties']).to eq([1,2,3])
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

    it "creates events when new event is unique" do
      @event.payload[:output] = "2014-07-01"
      @checker.receive([@event])

      event = create_event("2014-08-01")

      expect {
        @checker.receive([event])
      }.to change(Event, :count).by(1)
    end

    it "does not create event when event is a duplicate" do
      @event.payload[:output] = "2014-07-01"
      @checker.receive([@event])

      expect {
        @checker.receive([@event])
      }.to change(Event, :count).by(0)
    end

    it "should respect the lookback value" do
      3.times do |i|
        @event.payload[:output] = "2014-07-0#{i}"
        @checker.receive([@event])
      end
      @event.payload[:output] = "2014-07-05"
      expect {
        @checker.receive([@event])
      }.to change(Event, :count).by(1)
      expect(@checker.memory['properties'].length).to eq(3)
      expect(@checker.memory['properties']).to eq(["2014-07-01", "2014-07-02", "2014-07-05"])
    end

    it "should hash the value if its longer then 10 chars" do
      @event.payload[:output] = "01234567890"
      expect {
        @checker.receive([@event])
      }.to change(Event, :count).by(1)
      expect(@checker.memory['properties'].last).to eq('2256157795')
    end

    it "should use the whole event if :property is blank" do
      @checker.options['property'] = ''
      expect {
        @checker.receive([@event])
      }.to change(Event, :count).by(1)
      expect(@checker.memory['properties'].last).to eq('3023526198')
    end

    it "should still work after the memory was cleared" do
      @checker.memory = {}
      @checker.save
      @checker.reload
      expect {
        @checker.receive([@event])
      }.not_to raise_error
    end
  end
end
