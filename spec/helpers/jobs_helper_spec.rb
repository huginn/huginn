require 'rails_helper'

describe JobsHelper do
  let(:job) { Delayed::Job.new }

  describe '#status' do
    it "works for failed jobs" do
      job.failed_at = Time.now
      expect(status(job)).to eq('<span class="label label-danger">failed</span>')
    end

    it "works for running jobs" do
      job.locked_at = Time.now
      job.locked_by = 'test'
      expect(status(job)).to eq('<span class="label label-info">running</span>')
    end

    it "works for queued jobs" do
      expect(status(job)).to eq('<span class="label label-warning">queued</span>')
    end
  end

  describe '#relative_distance_of_time_in_words' do
    it "in the past" do
      expect(relative_distance_of_time_in_words(Time.now-5.minutes)).to eq('5m ago')
    end

    it "in the future" do
      expect(relative_distance_of_time_in_words(Time.now+5.minutes)).to eq('in 5m')
    end
  end
end
