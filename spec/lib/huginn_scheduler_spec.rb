require 'spec_helper'

describe HuginnScheduler do
  before(:each) do
    @scheduler = HuginnScheduler.new
    stub
  end

  it "should stop the scheduler" do
    mock.instance_of(Rufus::Scheduler).stop
    @scheduler.stop
  end

  it "schould register the schedules with the rufus scheduler and run" do
    mock.instance_of(Rufus::Scheduler).join
    @scheduler.run!
  end

  it "should run scheduled agents" do
    mock(Agent).run_schedule('every_1h')
    mock.instance_of(IO).puts('Queuing schedule for every_1h')
    @scheduler.send(:run_schedule, 'every_1h')
  end

  it "should propagate events" do
    mock(Agent).receive!
    stub.instance_of(IO).puts
    @scheduler.send(:propagate!)
  end

  it "schould clean up expired events" do
    mock(Event).cleanup_expired!
    stub.instance_of(IO).puts
    @scheduler.send(:cleanup_expired_events!)
  end

  describe "#hour_to_schedule_name" do
    it "for 0h" do
      @scheduler.send(:hour_to_schedule_name, 0).should == 'midnight'
    end

    it "for the forenoon" do
      @scheduler.send(:hour_to_schedule_name, 6).should == '6am'
    end

    it "for 12h" do
      @scheduler.send(:hour_to_schedule_name, 12).should == 'noon'
    end

    it "for the afternoon" do
      @scheduler.send(:hour_to_schedule_name, 17).should == '5pm'
    end
  end

  describe "cleanup_failed_jobs!" do
    before do
      3.times do |i|
        Delayed::Job.create(failed_at: Time.now - i.minutes)
      end
      @keep = Delayed::Job.order(:failed_at)[1]
    end

    it "work with set FAILED_JOBS_TO_KEEP env variable", focus: true do
      expect { @scheduler.send(:cleanup_failed_jobs!) }.to change(Delayed::Job, :count).by(-1)
      expect { @scheduler.send(:cleanup_failed_jobs!) }.to change(Delayed::Job, :count).by(0)
      @keep.id.should == Delayed::Job.order(:failed_at)[0].id
    end


    it "work without the FAILED_JOBS_TO_KEEP env variable" do
      old = ENV['FAILED_JOBS_TO_KEEP']
      ENV['FAILED_JOBS_TO_KEEP'] = nil
      expect { @scheduler.send(:cleanup_failed_jobs!) }.to change(Delayed::Job, :count).by(0)
      ENV['FAILED_JOBS_TO_KEEP'] = old
    end
  end
end