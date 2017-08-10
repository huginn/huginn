require 'rails_helper'

describe Agents::GithubNotificationsAgent do
  before do
    @valid_params = {
      name: "somename",
      options: {
        access_token: "{% credential github_access_token %}",
        events: "multiple",
        last_modified: true
      }
    }

    stub_request(:get, /github\.com/).to_return(
      :body => File.read(Rails.root.join("spec/data_fixtures/github_notifications.json")),
      :status => 200,
      :headers => {"Content-Type" => "text/json", "Last-Modified" => 'Thu, 25 Oct 2012 15:16:27 GMT'}
    )

    users(:jane).user_credentials.create! credential_name: 'github_access_token', credential_value: 'something'
    @checker = Agents::GithubNotificationsAgent.new(@valid_params)
    @checker.user = users(:jane)
    @checker.save!

  end

  describe "#check" do
    it "emits a single event with options['events'] = single" do
      @checker.options[:events] = 'single'
      expect {
        @checker.check()
      }.to change { Event.count }.by(1)
    end

    it "emits multiple events with options['events'] = multiple" do
      expect {
        @checker.check()
      }.to change { Event.count }.by(2)
    end

    it "creates an Events with the received data" do
      @checker.check()
      expect(Event.last.payload['url']).to eq "https://api.github.com/notifications/threads/1"
    end
  end

  describe "helpers" do
    it "should generate a correct request options hash on the first run" do
      expect(@checker.send(:request_options)).to eq({
        headers: {"User-Agent" => "Huginn (https://github.com/cantino/huginn)"},
        query: {access_token: users(:jane).user_credentials.last.credential_value}
      })
    end

    it "should generate a correct request options hash on consecutive runs" do
      time = (Time.now-1.minute).iso8601
      @checker.memory[:last_modified] = time
      @checker.save
      expect(@checker.reload.send(:request_options)).to eq({
        headers: {"User-Agent" => "Huginn (https://github.com/cantino/huginn)", "If-Modified-Since" => time},
        query: {access_token: users(:jane).user_credentials.last.credential_value}
      })
    end

    it "should generate a correct request options hash on consecutive runs with last_modified == false" do
      @checker.options['last_modified'] = 'false'
      @checker.memory[:last_modified] = Time.now
      @checker.save
      expect(@checker.reload.send(:request_options)).to eq({
        headers: {"User-Agent" => "Huginn (https://github.com/cantino/huginn)"},
        query: {access_token: users(:jane).user_credentials.last.credential_value}
      })
    end
  end

  describe "validation" do
    before do
      expect(@checker).to be_valid
    end

    it "should validate presence of access_token key" do
      @checker.options[:access_token] = nil
      expect(@checker).not_to be_valid
    end

    it "should validate last_modified is boolean" do
      @checker.options[:last_modified] = 'test'
      expect(@checker).not_to be_valid
    end
  end
end
