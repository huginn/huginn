require 'rails_helper'

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

    it "should try do create a device_id" do
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

  describe '#validate_api_key' do
    it "should return true when working" do
      mock(@checker).devices
      expect(@checker.validate_api_key).to be_truthy
    end

    it "should return true when working" do
      mock(@checker).devices { raise Agents::PushbulletAgent::Unauthorized }
      expect(@checker.validate_api_key).to be_falsy
    end
  end

  describe '#complete_device_id' do
    it "should return an array" do
      mock(@checker).devices { [{'iden' => '12345', 'nickname' => 'huginn'}] }
      expect(@checker.complete_device_id).to eq([{:text=>"All Devices", :id=>"__ALL__"}, {:text=>"huginn", :id=>"12345"}])
    end
  end

  describe "#receive" do
    it "send a note" do
      stub_request(:post, "https://api.pushbullet.com/v2/pushes").
        with(basic_auth: [@checker.options[:api_key], ''],
             body: "device_iden=124&type=note&title=hello%20from%20huginn&body=One%20two%20test").
        to_return(status: 200, body: "{}", headers: {})
      dont_allow(@checker).error
      @checker.receive([@event])
    end

    it "should log resquests which return an error" do
      stub_request(:post, "https://api.pushbullet.com/v2/pushes").
        with(basic_auth: [@checker.options[:api_key], ''],
             body: "device_iden=124&type=note&title=hello%20from%20huginn&body=One%20two%20test").
        to_return(status: 200, body: '{"error": {"message": "error"}}', headers: {})
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

  describe '#devices' do
    it "should return an array of devices" do
      stub_request(:get, "https://api.pushbullet.com/v2/devices").
        with(basic_auth: [@checker.options[:api_key], '']).
        to_return(status: 200,
                  body: '{"devices": [{"pushable": false}, {"nickname": "test", "iden": "iden", "pushable": true}]}',
                  headers: {})
      expect(@checker.send(:devices)).to eq([{"nickname"=>"test", "iden"=>"iden", "pushable"=>true}])
    end

    it "should return an empty array on error" do
      stub(@checker).request { raise Agents::PushbulletAgent::Unauthorized }
      expect(@checker.send(:devices)).to eq([])
    end
  end

  describe '#create_device' do
    it "should create a new device and assign it to the options" do
      stub_request(:post, "https://api.pushbullet.com/v2/devices").
        with(basic_auth: [@checker.options[:api_key], ''],
             body: "nickname=Huginn&type=stream").
        to_return(status: 200,
                  body: '{"iden": "udm0Tdjz5A7bL4NM"}',
                  headers: {})
      @checker.options['device_id'] = nil
      @checker.send(:create_device)
      expect(@checker.options[:device_id]).to eq('udm0Tdjz5A7bL4NM')
    end
  end
end
