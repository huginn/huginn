require 'rails_helper'

describe Agents::WitaiAgent do
  before do
    stub_request(:get, /wit/).to_return(:body => File.read(Rails.root.join('spec/data_fixtures/witai.json')), :status => 200, :headers => {'Content-Type' => 'text/json'})

    @valid_params = {
      :server_access_token => 'x',
      :expected_receive_period_in_days => '2',
      :query => '{{message.content}}'
    }

    @checker = Agents::WitaiAgent.new :name => 'wit.ai agent',
                                      :options => @valid_params

    @checker.user = users :jane
    @checker.save!

    @event = Event.new
    @event.agent = agents :jane_weather_agent
    @event.payload = {:message => {
      :content => 'set the temperature to 22 degrees at 7 PM'
    }}
    @event.save!
  end

  describe '#validation' do
    before do
      expect(@checker).to be_valid
    end

    it 'validates presence of server access token' do
      @checker.options[:server_access_token] = nil
      expect(@checker).not_to be_valid
    end

    it 'validates presence of query' do
      @checker.options[:query] = nil
      expect(@checker).not_to be_valid
    end

    it 'validates presence of expected receive period in days key' do
      @checker.options[:expected_receive_period_in_days] = nil
      expect(@checker).not_to be_valid
    end
  end

  describe '#working' do
    it 'checks if agent is working when event is received withing expected number of days' do
      expect(@checker).not_to be_working
      Agents::WitaiAgent.async_receive @checker.id, [@event.id]
      expect(@checker.reload).to be_working
      two_days_from_now = 2.days.from_now
      stub(Time).now { two_days_from_now }
      expect(@checker.reload).not_to be_working
    end
  end

  describe '#receive' do
    it 'checks that a new event is created after receiving one' do
      expect {
        @checker.receive([@event])
      }.to change { Event.count }.by(1)
    end

    it 'checks the integrity of new event' do
      @checker.receive([@event])
      expect(Event.last.payload[:outcomes][0][:_text]).to eq(@event.payload[:message][:content])
    end
  end
end
