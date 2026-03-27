require 'rails_helper'

describe ToolExecutionJob do
  let(:user) { users(:bob) }

  describe '#perform' do
    it 'is a no-op that completes without error' do
      expect {
        ToolExecutionJob.new.perform(
          'list_agents',
          '{}',
          { 'success' => true }.to_json,
          user.id,
          false
        )
      }.not_to raise_error
    end

    it 'does not raise even when was_error is true' do
      expect {
        ToolExecutionJob.new.perform(
          'list_agents',
          '{}',
          { 'error' => 'Something broke' }.to_json,
          user.id,
          true
        )
      }.not_to raise_error
    end

    it 'does not create any AgentLog entries' do
      expect {
        ToolExecutionJob.new.perform(
          'list_agents',
          '{}',
          { 'success' => true }.to_json,
          user.id,
          false
        )
      }.not_to change { AgentLog.count }
    end
  end
end
