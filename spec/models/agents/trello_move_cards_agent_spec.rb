require 'rails_helper'

describe Agents::TrelloMoveCardsAgent do
  before(:each) do
    @valid_params = {
      'public_key' => 'Public key',
      'member_token' => 'Member token',
      'board_name' => 'Test',
      'start_list_name' => 'Start List',
      'end_list_name' => 'End List'
    }

    @trello_agent = Agents::TrelloMoveCardsAgent.new(name: 'Trello', options: @valid_params)
    @trello_agent.user = users(:jane)
    @trello_agent.save!

    @event = Event.new
    @event.agent = agents(:bob_weather_agent)
    @event.payload = {run: 'true'} #any event will work
    @event.save!
  end

  describe "validating move all cards in list" do
    before do
      expect(@trello_agent).to be_valid
    end

    it 'should require a member_token' do
      @trello_agent.options['member_token'] = nil
      expect(@trello_agent).not_to be_valid
    end

    it 'should require a public_key' do
      @trello_agent.options['public_key'] = nil
      expect(@trello_agent).not_to be_valid
    end

    it 'should require an end_list_name' do
      @trello_agent.options['end_list_name'] = nil
      expect(@trello_agent).not_to be_valid
    end

    it 'should require a start_list_name' do
      @trello_agent.options['start_list_name'] = nil
      expect(@trello_agent).not_to be_valid
    end

    it 'should not require a board_name' do
      @trello_agent.options['board_name'] = nil
      expect(@trello_agent).to be_valid
    end

    it 'should not require a card_name' do
      expect(@trello_agent).to be_valid
    end
  end

  describe 'validating move a specific card' do
    before :each do
      @trello_agent.options['card_name'] = 'Card Name';
      @trello_agent.options['start_list_name'] = nil;
    end

    before do
      expect(@trello_agent).to be_valid
    end

    it 'should require a card_name' do
      @trello_agent.options['card_name'] = nil
      expect(@trello_agent).not_to be_valid
    end

    it 'should not require a start_list_name' do
      expect(@trello_agent).to be_valid
    end
  end

  describe "#working?" do
    it "should call received_event_without_error?" do
      mock(@trello_agent).received_event_without_error?
      @trello_agent.working?
    end
  end
end
