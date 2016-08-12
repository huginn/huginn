require 'rails_helper'

describe Agents::TrelloNotificationAgent do
  before(:each) do
    @valid_params = {
      'public_key' => 'Public key',
      'member_token' => 'Member token',
      'board_name' => 'Name of board',
      'username' => 'johndoe',
      'max_age' => '0',
      'expected_update_period_in_days' => '1',
    }

    @trello_agent = Agents::TrelloNotificationAgent.new(name: 'Trello', options: @valid_params)
    @trello_agent.user = users(:jane)
    @trello_agent.save!
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

    it 'should be valid without a board_name' do
      @trello_agent.options['board_name'] = nil
      expect(@trello_agent).to be_valid
    end

    it 'should be valid without a username' do
      @trello_agent.options['username'] = nil
      expect(@trello_agent).to be_valid
    end

    it 'should be valid without a max_age' do
      @trello_agent.options['max_age'] = nil
      expect(@trello_agent).to be_valid
    end
  end

  describe "#check" do
  end

  describe "#working?" do
  end
end
