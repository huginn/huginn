require 'rails_helper'

describe DelayedJobWorker do
  before do
    @djw = DelayedJobWorker.new
  end

  it "should run" do
    expect_any_instance_of(Delayed::Worker).to receive(:start)
    @djw.run
  end

  it "should stop" do
    expect_any_instance_of(Delayed::Worker).to receive(:start)
    @djw.run
    expect_any_instance_of(Delayed::Worker).to receive(:stop)
    @djw.stop
  end

  context "#setup_worker" do
    it "should return an array with an instance of itself" do
      workers = DelayedJobWorker.setup_worker
      expect(workers).to be_a(Array)
      expect(workers.first).to be_a(DelayedJobWorker)
      expect(workers.first.id).to eq('DelayedJobWorker')
    end
  end
end
