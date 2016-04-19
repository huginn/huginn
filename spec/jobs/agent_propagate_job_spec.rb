require 'rails_helper'

describe AgentPropagateJob do
  it "calls Agent.receive! when run" do
    mock(Agent).receive!
    AgentPropagateJob.new.perform
  end

  context "#can_enqueue?" do
    it "is truthy when no propagation job is queued" do
      expect(AgentPropagateJob.can_enqueue?).to be_truthy
    end

    it "is falsy when a progation job is queued" do
      Delayed::Job.create!(queue: 'propagation')
      expect(AgentPropagateJob.can_enqueue?).to be_falsy
    end

    it "is truthy when a enqueued progation job failed" do
      Delayed::Job.create!(queue: 'propagation', failed_at: Time.now - 1.minute)
      expect(AgentPropagateJob.can_enqueue?).to be_truthy
    end
  end
end
