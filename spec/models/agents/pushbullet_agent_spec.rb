require 'spec_helper'
require 'models/concerns/json_path_options_overwritable'

describe Agents::PushbulletAgent do
  it_behaves_like JsonPathOptionsOverwritable

  before(:each) do
    @valid_params = {
                      'api_key' => 'token',
                      'device_id' => '124',
                      'body_path' => '$.body',
                      'title' => 'hello from huginn'
                    }

    @checker = Agents::PushbulletAgent.new(:name => "somename", :options => @valid_params)
    @checker.user = users(:jane)
    @checker.save!

    @event = Event.new
    @event.agent = agents(:bob_weather_agent)
    @event.payload = { :body => 'One two test' }
    @event.save!
  end

  describe "validating" do
    before do
      @checker.should be_valid
    end

    it "should require the api_key" do
      @checker.options['api_key'] = nil
      @checker.should_not be_valid
    end

    it "should require the device_id" do
      @checker.options['device_id'] = nil
      @checker.should_not be_valid
    end
  end

  describe "helpers" do
    it "it should return the correct basic_options" do
      @checker.send(:basic_options).should == {:basic_auth => {:username =>@checker.options[:api_key], :password=>''},
                                               :body => {:device_iden => @checker.options[:device_id], :type => 'note'}}
    end


    it "should return the query_options" do
      @checker.send(:query_options, @event).should == @checker.send(:basic_options).deep_merge({
        :body => {:title => 'hello from huginn', :body => 'One two test'}
      })
    end
  end

  describe "#receive" do
    it "send a message to the hipchat" do
      stub_request(:post, "https://token:@api.pushbullet.com/api/pushes").
        with(:body => "device_iden=124&type=note&title=hello%20from%20huginn&body=One%20two%20test").
        to_return(:status => 200, :body => "ok", :headers => {})
      dont_allow(@checker).log
      @checker.receive([@event])
    end

    it "should log resquests which return an error" do
      stub_request(:post, "https://token:@api.pushbullet.com/api/pushes").
        with(:body => "device_iden=124&type=note&title=hello%20from%20huginn&body=One%20two%20test").
        to_return(:status => 200, :body => "error", :headers => {})
      mock(@checker).log("error")
      @checker.receive([@event])
    end
  end

  describe "#working?" do
    it "should not be working until the first event was received" do
      @checker.should_not be_working
      @checker.last_receive_at = Time.now
      @checker.should be_working
    end
  end
end
