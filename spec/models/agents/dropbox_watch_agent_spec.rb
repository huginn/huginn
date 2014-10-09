require 'spec_helper'

describe Agents::DropboxWatchAgent do
  before(:each) do
    @agent = Agents::DropboxWatchAgent.new(
      name: 'save to dropbox',
      options: {
        access_token: '70k3n',
        dir_to_watch: '/my/dropbox/dir',
        expected_update_period_in_days: 2
      }
    )
    @agent.user = users(:bob)
  end

  it 'cannot receive events' do
    expect(@agent.cannot_receive_events?).to eq true
  end

  it 'has agent description' do
    expect(@agent.description).to_not be_nil
  end

  it 'has event description' do
    expect(@agent.event_description).to_not be_nil
  end

  describe '#valid?' do
    before { expect(@agent.valid?).to eq true }

    it 'requires the "access_token"' do
      @agent.options[:access_token] = nil
      expect(@agent.valid?).to eq false
    end

    it 'requires a "dir_to_watch"' do
      @agent.options[:dir_to_watch] = nil
      expect(@agent.valid?).to eq false
    end

    describe 'expected_update_period_in_days' do
      it 'needs to be present' do
        @agent.options[:expected_update_period_in_days] = nil
        expect(@agent.valid?).to eq false
      end

      it 'needs to be a positive integer' do
        @agent.options[:expected_update_period_in_days] = -1
        expect(@agent.valid?).to eq false
      end
    end
  end

end