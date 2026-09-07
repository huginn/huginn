require 'rails_helper'

describe Agents::TwitterStreamAgent do
  let(:existing_agent) {
    Agents::TwitterStreamAgent.new(name: 'Twitter Counts', options: { 'filters' => ['huginn'], 'generate' => 'counts' }).tap { |agent|
      agent.user = users(:bob)
      agent.save!(validate: false)
    }
  }

  it 'cannot be created' do
    agent = Agents::TwitterStreamAgent.new(name: 'Twitter Counts', options: {})
    agent.user = users(:bob)
    expect(agent).not_to be_valid
    expect(agent.errors[:base]).to include(/no longer functional/)
  end

  it 'keeps existing agents loadable and editable' do
    expect(existing_agent.reload).to be_valid
    expect(existing_agent.update(disabled: true)).to be_truthy
  end

  it 'is never working' do
    expect(existing_agent).not_to be_working
  end

  it 'is not scheduled and does not run in the background' do
    expect(Agents::TwitterStreamAgent).to be_cannot_be_scheduled
    expect(Agents::TwitterStreamAgent).not_to include(LongRunnable)
  end
end
