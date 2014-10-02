require 'spec_helper'

describe JobsHelper do
  let(:job) { Delayed::Job.new }

  describe '#status' do
    it "works for failed jobs" do
      job.failed_at = Time.now
      status(job).should == '<span class="label label-danger">failed</span>'
    end

    it "works for running jobs" do
      job.locked_at = Time.now
      job.locked_by = 'test'
      status(job).should == '<span class="label label-info">running</span>'
    end

    it "works for queued jobs" do
      status(job).should == '<span class="label label-warning">queued</span>'
    end
  end

  describe '#relative_distance_of_time_in_words' do
    it "in the past" do
      relative_distance_of_time_in_words(Time.now-5.minutes).should == '5m ago'
    end

    it "in the future" do
      relative_distance_of_time_in_words(Time.now+5.minutes).should == 'in 5m'
    end
  end
end
