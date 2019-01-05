require 'rails_helper'

describe Agents::AttributeDifferenceAgent do
  def create_event(value=nil)
    event = Event.new
    event.agent = agents(:jane_weather_agent)
    event.payload = {
      rate: value
    }
    event.save!

    event
  end

  before do
    @valid_params = {
      path: 'rate',
      output: 'rate_diff',
      method: 'integer_difference',
      expected_update_period_in_days: '1'
    }

    @checker = Agents::AttributeDifferenceAgent.new(name: 'somename', options: @valid_params)
    @checker.user = users(:jane)
    @checker.save!
  end

  describe 'validation' do
    before do
      expect(@checker).to be_valid
    end

    it 'should validate presence of output' do
      @checker.options[:output] = nil
      expect(@checker).not_to be_valid
    end

    it 'should validate presence of path' do
      @checker.options[:path] = nil
      expect(@checker).not_to be_valid
    end

    it 'should validate presence of method' do
      @checker.options[:method] = nil
      expect(@checker).not_to be_valid
    end

    it 'should validate presence of expected_update_period_in_days' do
      @checker.options[:expected_update_period_in_days] = nil
      expect(@checker).not_to be_valid
    end
  end

  describe '#working?' do
    before :each do
      # Need to create an event otherwise event_created_within? returns nil
      event = create_event
      @checker.receive([event])
    end

    it 'is when event created within :expected_update_period_in_days' do
      @checker.options[:expected_update_period_in_days] = 2
      expect(@checker).to be_working
    end

    it 'isnt when event created outside :expected_update_period_in_days' do
      @checker.options[:expected_update_period_in_days] = 2

      travel 49.hours do
        expect(@checker).not_to be_working
      end
    end
  end

  describe '#receive' do
    before :each do
      @event = create_event('5.5')
    end

    it 'creates events when memory is empty' do
      expect {
        @checker.receive([@event])
      }.to change(Event, :count).by(1)
      expect(Event.last.payload[:rate_diff]).to eq(0)
    end

    it 'creates event with extra attribute for integer_difference' do
      @checker.receive([@event])
      event = create_event('6.5')

      expect {
        @checker.receive([event])
      }.to change(Event, :count).by(1)
      expect(Event.last.payload[:rate_diff]).to eq(1)
    end

    it 'creates event with extra attribute for decimal_difference' do
      @checker.options[:method] = 'decimal_difference'
      @checker.receive([@event])
      event = create_event('6.4')

      expect {
        @checker.receive([event])
      }.to change(Event, :count).by(1)
      expect(Event.last.payload[:rate_diff]).to eq(0.9)
    end

    it 'creates event with extra attribute for percentage_change' do
      @checker.options[:method] = 'percentage_change'
      @checker.receive([@event])
      event = create_event('9')

      expect {
        @checker.receive([event])
      }.to change(Event, :count).by(1)
      expect(Event.last.payload[:rate_diff]).to eq(63.636)
    end

    it 'creates event with extra attribute for percentage_change with the correct rounding' do
      @checker.options[:method] = 'percentage_change'
      @checker.options[:decimal_precision] = 5
      @checker.receive([@event])
      event = create_event('9')

      expect {
        @checker.receive([event])
      }.to change(Event, :count).by(1)
      expect(Event.last.payload[:rate_diff]).to eq(63.63636)
    end
  end
end
