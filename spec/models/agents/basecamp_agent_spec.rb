require 'spec_helper'
require 'models/concerns/oauthable'

describe Agents::BasecampAgent do
  it_behaves_like Oauthable

  before(:each) do
    stub_request(:get, /json$/).to_return(:body => File.read(Rails.root.join("spec/data_fixtures/basecamp.json")), :status => 200, :headers => {"Content-Type" => "text/json"})
    stub_request(:get, /02:00$/).to_return(:body => File.read(Rails.root.join("spec/data_fixtures/basecamp.json")), :status => 200, :headers => {"Content-Type" => "text/json"})
    @valid_params = { :project_id => 6789 }

    @checker = Agents::BasecampAgent.new(:name => "somename", :options => @valid_params)
    @checker.service = services(:generic)
    @checker.user = users(:jane)
    @checker.save!
  end

  describe "validating" do
    before do
      @checker.should be_valid
    end

    it "should require the basecamp project_id" do
      @checker.options['project_id'] = nil
      @checker.should_not be_valid
    end

  end

  describe "helpers" do
    it "should generate a correct request options hash" do
      @checker.send(:request_options).should == {:headers => {"User-Agent" => "Huginn (https://github.com/cantino/huginn)", "Authorization" => 'Bearer "1234token"'}}
    end

    it "should generate the currect request url" do
      @checker.send(:request_url).should == "https://basecamp.com/12345/api/v1/projects/6789/events.json"
    end


    it "should not provide the since attribute on first run" do
      @checker.send(:query_parameters).should == {}
    end

    it "should provide the since attribute after the first run" do
      time = (Time.now-1.minute).iso8601
      @checker.memory[:last_event] = time
      @checker.save
      @checker.reload.send(:query_parameters).should == {:query => {:since => time}}
    end
  end
  describe "#check" do
    it "should not emit events on its first run" do
      expect { @checker.check }.to change { Event.count }.by(0)
      expect(@checker.memory[:last_event]).to eq '2014-04-17T10:25:31.000+02:00'
    end
    it "should check that initial run creates an event" do
      @checker.memory[:last_event] = '2014-04-17T10:25:31.000+02:00'
      expect { @checker.check }.to change { Event.count }.by(1)
    end
  end

  describe "#working?" do
    it "it is working when at least one event was emited" do
      @checker.should_not be_working
      @checker.memory[:last_event] = '2014-04-17T10:25:31.000+02:00'
      @checker.check
      @checker.reload.should be_working
    end
  end
end
