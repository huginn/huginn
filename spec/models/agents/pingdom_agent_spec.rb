require 'spec_helper'

describe Agents::PingdomAgent do
  before(:each) do
    stub_request(:get, /api.pingdom.com/).to_return(:body => File.read(Rails.root.join("spec/data_fixtures/pingdom_checks.json")), :status => 200, :headers => {"Content-Type" => "text/json"})

    @valid_params = {
      :pingdom_url   => 'https://api.pingdom.com/api/2.0',
      :pingdom_credref   => 'user@somewhere.com',
      :pingdom_apikey => 'key4you...',
      :expected_update_period_in_days => '14',
    }

    @checker = Agents::PingdomAgent.new(:name => "pingdom-agent", :options => @valid_params)
    @checker.user = users(:jane)
    @checker.save!
  end

  describe "validating" do
    before do
      @checker.should be_valid
    end

    it "should require the pingdom_credref" do
      @checker.options['pingdom_credref'] = nil
      @checker.should_not be_valid
    end

    it "should require the pingdom url" do
      @checker.options['pingdom_url'] = nil
      @checker.should_not be_valid
    end

    it "should require the pingdom apikey" do
      @checker.options['pingdom_apikey'] = nil
      @checker.should_not be_valid
    end

    it "should require the expected_update_period_in_days" do
      @checker.options['expected_update_period_in_days'] = nil
      @checker.should_not be_valid
    end
  end

  describe "helpers" do
    it "should generate a valid credential reference" do
      @checker.send(:pingdom_credref).should == "user@somewhere.com"
    end

    it "should generate a correct request url" do
      @checker.send(:pingdom_url, 'checks').should == "https://api.pingdom.com/api/2.0/checks"
    end
  end

  describe "#check" do
    it "should be able to retrieve issues" do
      reply = File.read(Rails.root.join("spec/data_fixtures/pingdom_checks.json"))
      mock(@checker).get("https://api.pingdom.com/api/2.0/checks", {"App-Key"=>"key4you...", :content_type => :json}).returns(reply)

      expect { @checker.check }.to change { Event.count }.by(23)
    end
  end

  describe '#working?' do
    it 'checks if events have been received within the expected receive period' do
      @checker.should_not be_working # No events received
      @checker.check
      @checker.reload.should be_working # Just received events
      fourteen_days_from_now = 14.days.from_now
      stub(Time).now { fourteen_days_from_now }
      @checker.reload.should_not be_working # More time has passed than the expected receive period without any new events
    end
  end
end
