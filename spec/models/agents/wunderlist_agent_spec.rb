require 'rails_helper'
require 'models/concerns/oauthable'

describe Agents::WunderlistAgent do
  it_behaves_like Oauthable

  before(:each) do

    @valid_params = {
                      'list_id' => '12345',
                      'title' => '{{title}}: {{url}}',
                    }

    @checker = Agents::WunderlistAgent.new(:name => "somename", :options => @valid_params)
    @checker.user = users(:jane)
    @checker.service = services(:generic)
    @checker.save!

    @event = Event.new
    @event.agent = agents(:bob_weather_agent)
    @event.payload = { title: 'hello', url: 'www.example.com'}
    @event.save!
  end

  describe "validating" do
    before do
      expect(@checker).to be_valid
    end

    it "should require the title" do
      @checker.options['title'] = nil
      expect(@checker).not_to be_valid
    end

    it "should require the list_id" do
      @checker.options['list_id'] = nil
      expect(@checker).not_to be_valid
    end
  end

  it "should generate the request_options" do
    expect(@checker.send(:request_options)).to eq({:headers=>{"Content-Type"=>"application/json", "User-Agent"=>"Huginn (https://github.com/cantino/huginn)", "X-Access-Token"=>"1234token", "X-Client-ID"=>"wunderoauthkey"}})
  end

  describe "#complete_list_id" do
    it "should return a array of hashes" do
      stub_request(:get, 'https://a.wunderlist.com/api/v1/lists').to_return(
        :body => JSON.dump([{title: 'test', id: 12345}]),
        :headers => {"Content-Type" => "text/json"}
      )
      expect(@checker.complete_list_id).to eq([{:text=>"test (12345)", :id=>12345}])
    end
  end

  describe "#receive" do
    it "send a message to the hipchat" do
      stub_request(:post, 'https://a.wunderlist.com/api/v1/tasks')
      @checker.receive([@event])
      expect(WebMock).to have_requested(:post, "https://a.wunderlist.com/api/v1/tasks")
    end
  end

  describe "#working?" do
    it "should be working with no entry in the error log" do
      expect(@checker).to be_working
    end

    it "should not be working with a recent entry in the error log" do
      @checker.error("test")
      @checker.reload
      @checker.last_event_at = Time.now
      expect(@checker).to_not be_working
    end
  end
end
