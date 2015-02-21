require 'spec_helper'

describe Agents::PushbulletAgent do
  before(:each) do
    @valid_params = {
                      'api_key'   => 'token',
                      'device_id' => '124',
                      'body'      => '{{body}}',
                      'url'       => 'url',
                      'name'      => 'name',
                      'address'   => 'address',
                      'title'     => 'hello from huginn',
                      'type'      => 'note'
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
      expect(@checker).to be_valid
    end

    it "should require the api_key" do
      @checker.options['api_key'] = nil
      expect(@checker).not_to be_valid
    end

    it "should require the device_id" do
      @checker.options['device_id'] = nil
      expect(@checker).not_to be_valid
    end

    it "should require fields based on the type" do
      @checker.options['type'] = 'address'
      @checker.options['address'] = nil
      expect(@checker).not_to be_valid
    end
  end

  describe "helpers" do
    before(:each) do
      @base_options = {
        body: { device_iden: @checker.options[:device_id] },
        basic_auth: { username: @checker.options[:api_key], :password=>'' }
      }
    end
    context "#query_options" do
      it "should work for a note" do
        options = @base_options.deep_merge({
          body: {title: 'hello from huginn', body: 'One two test', type: 'note'}
        })
        expect(@checker.send(:query_options, @event)).to eq(options)
      end

      it "should work for a link" do
        @checker.options['type'] = 'link'
        options = @base_options.deep_merge({
          body: {title: 'hello from huginn', body: 'One two test', type: 'link', url: 'url'}
        })
        expect(@checker.send(:query_options, @event)).to eq(options)
      end

      it "should work for an address" do
        @checker.options['type'] = 'address'
        options = @base_options.deep_merge({
          body: {name: 'name', address: 'address', type: 'address'}
        })
        expect(@checker.send(:query_options, @event)).to eq(options)
      end
    end
  end

  describe "#receive" do
    it "send a note" do
      stub_request(:post, "https://token:@api.pushbullet.com/v2/pushes").
        with(:body => "device_iden=124&type=note&title=hello%20from%20huginn&body=One%20two%20test").
        to_return(:status => 200, :body => "ok", :headers => {})
      dont_allow(@checker).error
      @checker.receive([@event])
    end

    it "should log resquests which return an error" do
      stub_request(:post, "https://token:@api.pushbullet.com/v2/pushes").
        with(:body => "device_iden=124&type=note&title=hello%20from%20huginn&body=One%20two%20test").
        to_return(:status => 200, :body => "error", :headers => {})
      mock(@checker).error("error")
      @checker.receive([@event])
    end
  end

  describe "#working?" do
    it "should not be working until the first event was received" do
      expect(@checker).not_to be_working
      @checker.last_receive_at = Time.now
      expect(@checker).to be_working
    end
  end
end
